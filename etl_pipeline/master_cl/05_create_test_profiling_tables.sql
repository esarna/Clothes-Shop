-- ============================================================
-- DDL - BL_CL: DQ Test Results and Profiling Metrics
-- Central logging tables for the automated test suite
-- (dq_checks/tests) and the profiling suite (dq_checks/data_profiling).
-- ============================================================


-- ============================================================
-- 1. bl_cl.test_results
-- ============================================================

CREATE SEQUENCE IF NOT EXISTS bl_cl.seq_test_results
    START WITH 1 INCREMENT BY 1 MINVALUE 1 NO MAXVALUE CACHE 1;

CREATE TABLE IF NOT EXISTS bl_cl.test_results (
    test_result_id  BIGINT       NOT NULL DEFAULT nextval('bl_cl.seq_test_results'),
    test_id         VARCHAR(50)  NOT NULL,
    test_name       VARCHAR(200) NOT NULL,
    category        VARCHAR(20)  NOT NULL,   -- DQ | ETL | SCHEMA | SECURITY | ADHOC
    dimension       VARCHAR(20),             -- Completeness|Uniqueness|Accuracy|Validity|Consistency|Timeliness
    layer           VARCHAR(20),             -- SOURCE|SA|BL_3NF|BL_DM|CROSS_LAYER
    schema_name     VARCHAR(50),
    table_name      VARCHAR(100),
    source_system   VARCHAR(20),             -- SA_RETAIL|SA_ECOM|BOTH|N/A
    severity        VARCHAR(20)  NOT NULL,   -- Critical|Major|Minor|Trivial
    status          VARCHAR(10)  NOT NULL,   -- PASS|FAIL
    -- Defect lifecycle tracking (manually updated as defects are triaged).
    defect_status   VARCHAR(20),             -- Submitted|Fixed|Verified|Reopened|Declined, NULL if never FAIL
    expected_value  TEXT,
    actual_value    TEXT,
    details         TEXT,
    executed_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_test_results PRIMARY KEY (test_result_id),
    CONSTRAINT chk_test_results_status   CHECK (status IN ('PASS', 'FAIL')),
    CONSTRAINT chk_test_results_severity CHECK (severity IN ('Critical', 'Major', 'Minor', 'Trivial')),
    CONSTRAINT chk_test_results_defect_status CHECK (
        defect_status IS NULL OR defect_status IN ('Submitted', 'Fixed', 'Verified', 'Reopened', 'Declined')
    )
);

COMMENT ON TABLE bl_cl.test_results IS
    'Single source of truth for the automated DQ/ETL/schema/security test suite. '
    'One row per test execution, written by bl_cl.prc_log_test_result(). '
    'Read by the Python reporting suite in dq_checks/visualisation_and_reporting.';

CREATE INDEX IF NOT EXISTS idx_test_results_status_dt
    ON bl_cl.test_results (status, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_test_results_test_id
    ON bl_cl.test_results (test_id, executed_at DESC);


-- ============================================================
-- 2. bl_cl.prc_log_test_result
-- ============================================================

CREATE OR REPLACE PROCEDURE bl_cl.prc_log_test_result(
    p_test_id        VARCHAR,
    p_test_name      VARCHAR,
    p_category       VARCHAR,
    p_dimension      VARCHAR,
    p_layer          VARCHAR,
    p_schema_name    VARCHAR,
    p_table_name     VARCHAR,
    p_source_system  VARCHAR,
    p_severity       VARCHAR,
    p_status         VARCHAR,
    p_expected_value TEXT DEFAULT NULL,
    p_actual_value   TEXT DEFAULT NULL,
    p_details        TEXT DEFAULT NULL
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO bl_cl.test_results (
        test_id, test_name, category, dimension, layer,
        schema_name, table_name, source_system, severity, status,
        defect_status, expected_value, actual_value, details
    ) VALUES (
        p_test_id, p_test_name, p_category, p_dimension, p_layer,
        p_schema_name, p_table_name, p_source_system, p_severity, p_status,
        CASE WHEN p_status = 'FAIL' THEN 'Submitted' ELSE NULL END,
        p_expected_value, p_actual_value, p_details
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '[prc_log_test_result] Failed to log test [%]. Error: [%].', p_test_id, SQLERRM;
END;
$$;

COMMENT ON PROCEDURE bl_cl.prc_log_test_result(
    VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT, TEXT, TEXT
) IS 'Logs one row into bl_cl.test_results. Never raises - never masks a test failure.';


-- ============================================================
-- 3. bl_cl.profiling_metrics
-- ============================================================

CREATE SEQUENCE IF NOT EXISTS bl_cl.seq_profiling_metrics
    START WITH 1 INCREMENT BY 1 MINVALUE 1 NO MAXVALUE CACHE 1;

CREATE TABLE IF NOT EXISTS bl_cl.profiling_metrics (
    metric_id       BIGINT       NOT NULL DEFAULT nextval('bl_cl.seq_profiling_metrics'),
    layer           VARCHAR(20)  NOT NULL,   -- SOURCE|SA|BL_3NF|BL_DM
    schema_name     VARCHAR(50),
    table_name      VARCHAR(100) NOT NULL,
    column_name     VARCHAR(100),            -- NULL for table-level metrics
    source_system   VARCHAR(20),             -- SA_RETAIL|SA_ECOM|BOTH|N/A
    metric_name     VARCHAR(50)  NOT NULL,
    metric_value    TEXT,
    comments        TEXT,
    executed_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_profiling_metrics PRIMARY KEY (metric_id)
);

COMMENT ON TABLE bl_cl.profiling_metrics IS
    'Descriptive (no pass/fail) profiling metrics for every DWH layer, written by '
    'bl_cl.prc_log_profiling_metric(). Read by the Python reporting suite. '
    'Kept separate from bl_cl.test_results by design - profiling has no pass/fail concept.';

CREATE INDEX IF NOT EXISTS idx_profiling_metrics_lookup
    ON bl_cl.profiling_metrics (layer, table_name, metric_name);


-- ============================================================
-- 4. bl_cl.prc_log_profiling_metric
-- ============================================================

CREATE OR REPLACE PROCEDURE bl_cl.prc_log_profiling_metric(
    p_layer         VARCHAR,
    p_schema_name   VARCHAR,
    p_table_name    VARCHAR,
    p_column_name   VARCHAR,
    p_source_system VARCHAR,
    p_metric_name   VARCHAR,
    p_metric_value  TEXT,
    p_comments      TEXT DEFAULT NULL
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO bl_cl.profiling_metrics (
        layer, schema_name, table_name, column_name, source_system,
        metric_name, metric_value, comments
    ) VALUES (
        p_layer, p_schema_name, p_table_name, p_column_name, p_source_system,
        p_metric_name, p_metric_value, p_comments
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '[prc_log_profiling_metric] Failed to log metric [%] on [%.%]. Error: [%].',
            p_metric_name, p_schema_name, p_table_name, SQLERRM;
END;
$$;

COMMENT ON PROCEDURE bl_cl.prc_log_profiling_metric(
    VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT, TEXT
) IS 'Logs one row into bl_cl.profiling_metrics. Never raises.';


-- ============================================================
-- 5. bl_cl.fn_log_profile_safe
--    Executes a dynamic scalar-returning query and logs the result as one
--    profiling metric. Never raises - a failing metric is logged as
--    metric_value='ERROR' with the error text in comments, per profiling suite
--    execution rules (one bad metric must not abort the run).
-- ============================================================

CREATE OR REPLACE FUNCTION bl_cl.fn_log_profile_safe(
    p_layer         VARCHAR,
    p_schema_name   VARCHAR,
    p_table_name    VARCHAR,
    p_column_name   VARCHAR,
    p_source_system VARCHAR,
    p_metric_name   VARCHAR,
    p_query         TEXT,
    p_comments      TEXT DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    v_value TEXT;
BEGIN
    BEGIN
        EXECUTE p_query INTO v_value;
        CALL bl_cl.prc_log_profiling_metric(
            p_layer, p_schema_name, p_table_name, p_column_name, p_source_system,
            p_metric_name, v_value, p_comments
        );
    EXCEPTION WHEN OTHERS THEN
        CALL bl_cl.prc_log_profiling_metric(
            p_layer, p_schema_name, p_table_name, p_column_name, p_source_system,
            p_metric_name, 'ERROR', SQLERRM
        );
    END;
END;
$$;

COMMENT ON FUNCTION bl_cl.fn_log_profile_safe(
    VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT, TEXT
) IS 'Runs p_query (must return a single scalar), logs it as one profiling metric. Never raises.';


-- ============================================================
-- 6. VERIFICATION
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='bl_cl' AND table_name='test_results') THEN
        RAISE EXCEPTION '[FAIL] bl_cl.test_results NOT found.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='bl_cl' AND table_name='profiling_metrics') THEN
        RAISE EXCEPTION '[FAIL] bl_cl.profiling_metrics NOT found.';
    END IF;
    RAISE NOTICE '[OK] bl_cl.test_results and bl_cl.profiling_metrics ready.';
END;
$$;
