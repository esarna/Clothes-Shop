"""
Test Report and Data Profiling Report generator.

Reads exclusively from bl_cl.test_results and bl_cl.profiling_metrics and
produces the tables and charts required by the Test Report and the Data
Profiling Report. Does not implement any new test or metric logic.

Usage:
    python generate_reports.py --db-url postgresql://user:pass@host:5432/db
        [--period-start 2024-01-01] [--period-end 2024-12-31]
        [--output-dir ./report_output]
"""

import argparse
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
from sqlalchemy import create_engine

SEVERITY_ORDER = ["Critical", "Major", "Minor", "Trivial"]
LAYER_ORDER = ["SOURCE", "SA", "BL_3NF", "BL_DM", "CROSS_LAYER"]
SEVERITY_COLORS = {"Critical": "red", "Major": "orange", "Minor": "gold", "Trivial": "grey"}

SMOKE_TEST_IDS = [
    "TC-DQ-COMP-SRC-01", "TC-DQ-COMP-SRC-02",
    "TC-DQ-UNIQ-3NF-11", "TC-DQ-UNIQ-DM-06",
    "TC-ETL-COMP-DM-06",
]
REGRESSION_TEST_IDS = SMOKE_TEST_IDS + [
    "TC-DQ-TIME-RESTART-01", "TC-DQ-TIME-RESTART-04",
]

CRITICAL_PATH_CATEGORIES = {"DQ", "ETL", "SCHEMA", "SECURITY"}
EXTENDED_CATEGORIES = {"ADHOC"}


# ------------------------------------------------------------------
# Data loading
# ------------------------------------------------------------------

def load_test_results(engine, period_start=None, period_end=None):
    df = pd.read_sql("SELECT * FROM bl_cl.test_results", engine)
    df["executed_at"] = pd.to_datetime(df["executed_at"])
    return filter_period(df, period_start, period_end)


def load_profiling_metrics(engine, layer=None):
    df = pd.read_sql("SELECT * FROM bl_cl.profiling_metrics", engine)
    df["executed_at"] = pd.to_datetime(df["executed_at"])
    if layer is not None:
        df = df[df["layer"] == layer]
    return df


# ------------------------------------------------------------------
# Common aggregation helpers
# ------------------------------------------------------------------

def filter_period(df, start, end):
    if start is None and end is None:
        return df
    out = df
    if start is not None:
        out = out[out["executed_at"] >= pd.to_datetime(start)]
    if end is not None:
        out = out[out["executed_at"] <= pd.to_datetime(end)]
    return out


def pass_rate(df, group_cols):
    grouped = df.groupby(group_cols)["status"]
    total = grouped.count()
    passed = grouped.apply(lambda s: (s == "PASS").sum())
    result = pd.DataFrame({"total": total, "passed": passed})
    result["pct_pass"] = (result["passed"] / result["total"] * 100).round(2)
    return result.reset_index()


def severity_breakdown(df, status_filter, group_cols):
    filtered = df[df["status"] == status_filter] if status_filter else df
    pivot = filtered.pivot_table(
        index=group_cols, columns="severity", values="test_id", aggfunc="count", fill_value=0
    )
    for sev in SEVERITY_ORDER:
        if sev not in pivot.columns:
            pivot[sev] = 0
    return pivot[SEVERITY_ORDER].reset_index()


# ------------------------------------------------------------------
# Test Report tables (reporting.md Section 5)
# ------------------------------------------------------------------

def smoke_critical_extended_pass_rates(df):
    def level(row):
        if row["test_id"] in SMOKE_TEST_IDS:
            return "Smoke"
        if row["category"] in EXTENDED_CATEGORIES:
            return "Extended"
        return "Critical Path"

    tagged = df.copy()
    tagged["test_level"] = tagged.apply(level, axis=1)
    return pass_rate(tagged, ["test_level"])


def new_defects_table(df, period_start, period_end):
    period_df = filter_period(df, period_start, period_end)
    return severity_breakdown(period_df, "FAIL", ["defect_status"])


def overall_defects_table(df):
    return severity_breakdown(df, "FAIL", ["defect_status"])


def defect_list(df, status_filter="FAIL"):
    filtered = df[df["status"] == status_filter]
    out = filtered[["test_id", "severity", "test_name", "status", "table_name"]].copy()
    out = out.rename(columns={"test_name": "Summary", "table_name": "Component"})
    return out.reset_index(drop=True)


def regression_summary(df, regression_test_ids=None):
    ids = regression_test_ids or REGRESSION_TEST_IDS
    return pass_rate(df[df["test_id"].isin(ids)], ["test_id"])


# ------------------------------------------------------------------
# Data Profiling Report tables (reporting.md Section 6)
# ------------------------------------------------------------------

def row_counts_by_layer(metrics_df):
    rc = metrics_df[metrics_df["metric_name"] == "ROW_COUNT"]
    return rc.pivot_table(
        index=["layer", "table_name"], columns="source_system", values="metric_value",
        aggfunc="first"
    ).reset_index()


def null_completeness_table(metrics_df, layer):
    subset = metrics_df[(metrics_df["layer"] == layer) & (metrics_df["metric_name"].isin(["NULL_COUNT", "NULL_PCT"]))]
    return subset.pivot_table(
        index="table_name", columns=["column_name", "metric_name"], values="metric_value", aggfunc="first"
    ).reset_index()


def numeric_stats_table(metrics_df, layer):
    subset = metrics_df[(metrics_df["layer"] == layer) & (metrics_df["metric_name"].isin(
        ["MIN_VALUE", "MAX_VALUE", "AVG_VALUE", "SUM_VALUE"]))]
    return subset.pivot_table(
        index=["table_name", "column_name"], columns="metric_name", values="metric_value", aggfunc="first"
    ).reset_index()


def categorical_distribution_table(metrics_df, layer):
    subset = metrics_df[(metrics_df["layer"] == layer) & (metrics_df["metric_name"].isin(
        ["DISTINCT_COUNT", "TOP_VALUE_FREQ"]))]
    return subset[["table_name", "column_name", "metric_name", "metric_value"]].reset_index(drop=True)


def duplicate_summary_table(metrics_df, layer):
    subset = metrics_df[(metrics_df["layer"] == layer) & (metrics_df["metric_name"].isin(
        ["DUPLICATE_FULL_ROW_COUNT", "DUPLICATE_KEY_COUNT"]))]
    return subset[["table_name", "metric_name", "metric_value", "comments"]].reset_index(drop=True)


def row_count_reconciliation_chain(metrics_df):
    subset = metrics_df[metrics_df["metric_name"] == "ROW_COUNT_DELTA"]
    return subset[["table_name", "column_name", "source_system", "metric_value", "comments"]].reset_index(drop=True)


def dq_dimension_summary(test_results_df):
    dq_df = test_results_df[test_results_df["dimension"].notna()]
    return pass_rate(dq_df, ["dimension"])


# ------------------------------------------------------------------
# Charts (reporting.md Section 7)
# ------------------------------------------------------------------

def chart_defects_over_time(df, out_path):
    fail_df = df[df["status"] == "FAIL"].copy()
    if fail_df.empty:
        return
    fail_df["date"] = fail_df["executed_at"].dt.date
    daily = fail_df.groupby(["date", "defect_status"]).size().unstack(fill_value=0)
    submitted = daily.get("Submitted", pd.Series(dtype=int)).cumsum()
    fixed = daily.get("Fixed", pd.Series(dtype=int)).cumsum()
    declined = daily.get("Declined", pd.Series(dtype=int)).cumsum()
    open_defects = submitted.reindex(daily.index, fill_value=0) \
        - fixed.reindex(daily.index, fill_value=0) - declined.reindex(daily.index, fill_value=0)

    plt.figure(figsize=(8, 4))
    plt.plot(daily.index, submitted.reindex(daily.index, fill_value=0), label="Cumulative Submitted")
    plt.plot(daily.index, fixed.reindex(daily.index, fill_value=0), label="Cumulative Fixed")
    plt.plot(daily.index, open_defects, label="Total Open")
    plt.legend()
    plt.title("Defects Over Time")
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(out_path)
    plt.close()


def chart_pass_rate_by_severity(df, out_path):
    pivot = df.pivot_table(index="severity", columns="status", values="test_id", aggfunc="count", fill_value=0)
    pivot = pivot.reindex(SEVERITY_ORDER).fillna(0)
    pivot.plot(kind="bar", figsize=(6, 4), color=["#2ca02c", "#d62728"])
    plt.title("Pass/Fail Count by Severity")
    plt.ylabel("Count")
    plt.tight_layout()
    plt.savefig(out_path)
    plt.close()


def chart_pass_rate_by_category(df, out_path):
    rates = pass_rate(df, ["category"])
    plt.figure(figsize=(6, 4))
    plt.bar(rates["category"], rates["pct_pass"], color="#1f77b4")
    plt.title("Pass Rate by Category")
    plt.ylabel("%PASS")
    plt.tight_layout()
    plt.savefig(out_path)
    plt.close()


def chart_dq_dimension_radar_or_bar(df, out_path):
    rates = dq_dimension_summary(df)
    plt.figure(figsize=(6, 4))
    plt.bar(rates["dimension"], rates["pct_pass"], color="#9467bd")
    plt.title("Pass Rate by DQ Dimension")
    plt.ylabel("%PASS")
    plt.xticks(rotation=30)
    plt.tight_layout()
    plt.savefig(out_path)
    plt.close()


def chart_row_count_funnel(metrics_df, out_path):
    rc = metrics_df[metrics_df["metric_name"] == "ROW_COUNT"].copy()
    rc = rc[rc["layer"].isin(LAYER_ORDER)]
    rc["metric_value"] = pd.to_numeric(rc["metric_value"], errors="coerce")
    pivot = rc.groupby(["source_system", "layer"])["metric_value"].sum().unstack(fill_value=0)
    pivot = pivot.reindex(columns=[l for l in LAYER_ORDER if l in pivot.columns])

    plt.figure(figsize=(7, 4))
    for src in pivot.index:
        plt.plot(pivot.columns, pivot.loc[src], marker="o", label=src)
    plt.legend()
    plt.title("Row Count Funnel by Layer")
    plt.ylabel("Row Count")
    plt.tight_layout()
    plt.savefig(out_path)
    plt.close()


def chart_null_pct_heatmap(metrics_df, layer, out_path):
    subset = metrics_df[(metrics_df["layer"] == layer) & (metrics_df["metric_name"] == "NULL_PCT")].copy()
    if subset.empty:
        return
    subset["metric_value"] = pd.to_numeric(subset["metric_value"], errors="coerce")
    pivot = subset.pivot_table(index="table_name", columns="column_name", values="metric_value", aggfunc="first")

    plt.figure(figsize=(max(6, len(pivot.columns) * 0.6), max(3, len(pivot.index) * 0.5)))
    plt.imshow(pivot.values, cmap="Reds", aspect="auto")
    plt.xticks(range(len(pivot.columns)), pivot.columns, rotation=90)
    plt.yticks(range(len(pivot.index)), pivot.index)
    plt.colorbar(label="NULL_PCT")
    plt.title(f"NULL_PCT Heatmap - {layer}")
    plt.tight_layout()
    plt.savefig(out_path)
    plt.close()


# ------------------------------------------------------------------
# Output helpers
# ------------------------------------------------------------------

def write_tables(tables, xlsx_path, output_dir):
    with pd.ExcelWriter(xlsx_path) as writer:
        for name, df in tables.items():
            if isinstance(df.columns, pd.MultiIndex):
                df = df.copy()
                df.columns = ["_".join(str(c) for c in col if str(c)) for col in df.columns]
            df.to_excel(writer, sheet_name=name[:31], index=False)
            md_path = os.path.join(output_dir, f"{name}.md")
            with open(md_path, "w", encoding="utf-8") as f:
                f.write(df.to_markdown(index=False))


# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db-url", required=True, help="SQLAlchemy/psycopg2 connection string")
    parser.add_argument("--period-start", default=None, help="Reporting period start date (YYYY-MM-DD)")
    parser.add_argument("--period-end", default=None, help="Reporting period end date (YYYY-MM-DD)")
    parser.add_argument("--output-dir", default="./report_output", help="Output directory")
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)
    charts_dir = os.path.join(args.output_dir, "charts")
    os.makedirs(charts_dir, exist_ok=True)

    engine = create_engine(args.db_url)

    test_results = load_test_results(engine)
    period_results = filter_period(test_results, args.period_start, args.period_end)
    metrics = load_profiling_metrics(engine)

    test_tables = {
        "smoke_critical_extended": smoke_critical_extended_pass_rates(test_results),
        "new_defects": new_defects_table(test_results, args.period_start, args.period_end),
        "overall_defects": overall_defects_table(test_results),
        "defect_list": defect_list(test_results),
        "regression_summary": regression_summary(test_results),
        "dq_dimension_summary": dq_dimension_summary(test_results),
    }
    write_tables(test_tables, os.path.join(args.output_dir, "test_report_tables.xlsx"), args.output_dir)

    profiling_tables = {
        "row_counts_by_layer": row_counts_by_layer(metrics),
        "row_count_reconciliation": row_count_reconciliation_chain(metrics),
    }
    for layer in ["SOURCE", "SA", "BL_3NF", "BL_DM"]:
        profiling_tables[f"null_completeness_{layer.lower()}"] = null_completeness_table(metrics, layer)
        profiling_tables[f"numeric_stats_{layer.lower()}"] = numeric_stats_table(metrics, layer)
        profiling_tables[f"categorical_dist_{layer.lower()}"] = categorical_distribution_table(metrics, layer)
        profiling_tables[f"duplicate_summary_{layer.lower()}"] = duplicate_summary_table(metrics, layer)
    write_tables(profiling_tables, os.path.join(args.output_dir, "profiling_report_tables.xlsx"), args.output_dir)

    chart_defects_over_time(test_results, os.path.join(charts_dir, "defects_trend.png"))
    chart_pass_rate_by_severity(test_results, os.path.join(charts_dir, "pass_rate_severity.png"))
    chart_pass_rate_by_category(test_results, os.path.join(charts_dir, "pass_rate_category.png"))
    chart_dq_dimension_radar_or_bar(test_results, os.path.join(charts_dir, "dq_dimensions.png"))
    chart_row_count_funnel(metrics, os.path.join(charts_dir, "row_count_funnel.png"))
    for layer in ["SOURCE", "SA", "BL_3NF", "BL_DM"]:
        chart_null_pct_heatmap(metrics, layer, os.path.join(charts_dir, f"null_pct_heatmap_{layer.lower()}.png"))

    print(f"Reports written to {args.output_dir}")


if __name__ == "__main__":
    main()
