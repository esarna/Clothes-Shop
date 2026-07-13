-- ============================================================
-- FILE:    etl_pipeline/deduplication/cross_source_dedup_note.sql
-- PURPOSE: Cross-source deduplication strategy documentation
--          and BL_CL helper structures for Hierarchy L1 approach
--
-- STRATEGY: Hierarchy L1 (Deduplication.pptx, Slide 11-12)
-- ============================================================
--
-- PROBLEM:
--   The same physical customer may appear in BOTH source systems:
--     sa_retail.src_retail_sales  → identified by customer_id
--     sa_ecom.src_ecom_sales      → identified by user_id
--   Retail has no email; ecom has no store info.
--   Both sources may have different phone numbers, addresses.
--
-- SOLUTION – Hierarchy L1 (Option 2 from Deduplication.pptx):
--
--   LEVEL 1 (BL_3NF.CE_CUSTOMERS_L1):
--     Contains IMMUTABLE attributes that uniquely identify
--     a real-world person: name + gender + age (as surrogate
--     for birthday). Shared across both sources.
--     Populated ONCE; used as the master deduplication anchor.
--
--   LEVEL 2 (BL_3NF.CE_CUSTOMERS_SCD):
--     Contains per-source rows with source-specific attributes.
--     Each row has a CUSTOMER_L1_ID FK pointing back to L1.
--     Retail row (customer_id) and ecom row (user_id) for the
--     same person both link to the same L1 record.
--     This preserves full source detail while resolving the
--     real-world identity at the L1 level.
--
--   RESULT (per Deduplication.pptx Slide 12):
--     CE_CUSTOMERS_L1:  1 row  → Mariya Pavlova (the person)
--     CE_CUSTOMERS_SCD: 2 rows → one from retail, one from ecom
--                                both with customer_l1_id = 1
--
-- NOTE: The actual L1 table DDL and ETL logic are implemented
--   in etl_pipeline/bl_3NF/ scripts.
--   This file documents the SA-level consideration and serves
--   as the deduplication folder entry per repository structure.
--
-- ============================================================

-- ============================================================
-- VERIFICATION QUERIES (run after 05_load_src_tables.sql)
-- ============================================================

-- 1. Check physical deduplication result for retail:
SELECT
    COUNT(*)                                    AS total_src_rows,
    COUNT(DISTINCT bill_id || '|' || product_code) AS distinct_grain_keys
FROM sa_retail.src_retail_sales;
-- total_src_rows should equal distinct_grain_keys → no duplicates remain

-- 2. Check physical deduplication result for ecom:
SELECT
    COUNT(*)                                        AS total_src_rows,
    COUNT(DISTINCT payment_id || '|' || product_code) AS distinct_grain_keys
FROM sa_ecom.src_ecom_sales;

-- 3. Confirm no physical duplicates remain in retail:
SELECT bill_id, product_code, COUNT(*) AS cnt
FROM sa_retail.src_retail_sales
GROUP BY bill_id, product_code
HAVING COUNT(*) > 1;
-- Expected: 0 rows

-- 4. Confirm no physical duplicates remain in ecom:
SELECT payment_id, product_code, COUNT(*) AS cnt
FROM sa_ecom.src_ecom_sales
GROUP BY payment_id, product_code
HAVING COUNT(*) > 1;
-- Expected: 0 rows

-- 5. Compare row counts ext vs src (shows how many duplicates were removed):
SELECT
    'RETAIL'                                    AS source,
    (SELECT COUNT(*) FROM sa_retail.ext_retail_sales) AS ext_count,
    (SELECT COUNT(*) FROM sa_retail.src_retail_sales) AS src_count,
    (SELECT COUNT(*) FROM sa_retail.ext_retail_sales)
    - (SELECT COUNT(*) FROM sa_retail.src_retail_sales) AS duplicates_removed
UNION ALL
SELECT
    'ECOM',
    (SELECT COUNT(*) FROM sa_ecom.ext_ecom_sales),
    (SELECT COUNT(*) FROM sa_ecom.src_ecom_sales),
    (SELECT COUNT(*) FROM sa_ecom.ext_ecom_sales)
    - (SELECT COUNT(*) FROM sa_ecom.src_ecom_sales);