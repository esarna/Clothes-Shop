-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================

-- Physical deduplication result for retail:
SELECT
    COUNT(*)                                    AS total_src_rows,
    COUNT(DISTINCT bill_id || '|' || product_code) AS distinct_grain_keys
FROM sa_retail.src_retail_sales;
-- total_src_rows should equal distinct_grain_keys → no duplicates remain

-- Physical deduplication result for ecom:
SELECT
    COUNT(*)                                        AS total_src_rows,
    COUNT(DISTINCT payment_id || '|' || product_code) AS distinct_grain_keys
FROM sa_ecom.src_ecom_sales;

-- No physical duplicates remain in retail:
SELECT bill_id, product_code, COUNT(*) AS cnt
FROM sa_retail.src_retail_sales
GROUP BY bill_id, product_code
HAVING COUNT(*) > 1;
-- Expected: 0 rows

-- No physical duplicates remain in ecom:
SELECT payment_id, product_code, COUNT(*) AS cnt
FROM sa_ecom.src_ecom_sales
GROUP BY payment_id, product_code
HAVING COUNT(*) > 1;
-- Expected: 0 rows

-- Row counts ext vs src (shows how many duplicates were removed):
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