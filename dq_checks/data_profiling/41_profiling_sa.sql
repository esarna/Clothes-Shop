-- ============================================================
-- PROFILING GROUP 2 - SA LAYER (src_retail_sales, src_ecom_sales)
-- ============================================================

-- ---------- ROW_COUNT + ROW_COUNT_DELTA vs SOURCE layer ----------
SELECT bl_cl.fn_log_profile_safe('SA','sa_retail','src_retail_sales',NULL,'SA_RETAIL','ROW_COUNT',
    'SELECT COUNT(*)::text FROM sa_retail.src_retail_sales');
SELECT bl_cl.fn_log_profile_safe('SA','sa_retail','src_retail_sales',NULL,'SA_RETAIL','ROW_COUNT_DELTA',
    'SELECT ((SELECT COUNT(*) FROM sa_retail.ext_retail_sales) - (SELECT COUNT(*) FROM sa_retail.src_retail_sales))::text',
    'Expected delta = rows removed by dedup + NULL-key filter');

SELECT bl_cl.fn_log_profile_safe('SA','sa_ecom','src_ecom_sales',NULL,'SA_ECOM','ROW_COUNT',
    'SELECT COUNT(*)::text FROM sa_ecom.src_ecom_sales');
SELECT bl_cl.fn_log_profile_safe('SA','sa_ecom','src_ecom_sales',NULL,'SA_ECOM','ROW_COUNT_DELTA',
    'SELECT ((SELECT COUNT(*) FROM sa_ecom.ext_ecom_sales) - (SELECT COUNT(*) FROM sa_ecom.src_ecom_sales))::text',
    'Expected delta = rows removed by dedup + NULL-key filter');

-- ---------- NULL_COUNT / NULL_PCT post-cast (guard rejections) - retail ----------
SELECT bl_cl.fn_log_profile_safe('SA','sa_retail','src_retail_sales',c,'SA_RETAIL','NULL_COUNT',
    format('SELECT COUNT(*)::text FROM sa_retail.src_retail_sales WHERE %I IS NULL', c),
    'post-cast NULL, likely guard rejection')
FROM   unnest(ARRAY['line_item_amount','bill_discount','min_amount','cost','quantity_sold','transaction_date']) c;

SELECT bl_cl.fn_log_profile_safe('SA','sa_retail','src_retail_sales',c,'SA_RETAIL','NULL_PCT',
    format('SELECT ROUND(100.0 * (SELECT COUNT(*) FROM sa_retail.src_retail_sales WHERE %I IS NULL) '
           '/ NULLIF((SELECT COUNT(*) FROM sa_retail.src_retail_sales), 0), 2)::text', c),
    'post-cast NULL, likely guard rejection')
FROM   unnest(ARRAY['line_item_amount','bill_discount','min_amount','cost','quantity_sold','transaction_date']) c;

-- ---------- NULL_COUNT / NULL_PCT post-cast - ecom ----------
SELECT bl_cl.fn_log_profile_safe('SA','sa_ecom','src_ecom_sales',c,'SA_ECOM','NULL_COUNT',
    format('SELECT COUNT(*)::text FROM sa_ecom.src_ecom_sales WHERE %I IS NULL', c),
    'post-cast NULL, likely guard rejection')
FROM   unnest(ARRAY['sales_amount','discount','cost','quantity','transaction_date']) c;

SELECT bl_cl.fn_log_profile_safe('SA','sa_ecom','src_ecom_sales',c,'SA_ECOM','NULL_PCT',
    format('SELECT ROUND(100.0 * (SELECT COUNT(*) FROM sa_ecom.src_ecom_sales WHERE %I IS NULL) '
           '/ NULLIF((SELECT COUNT(*) FROM sa_ecom.src_ecom_sales), 0), 2)::text', c),
    'post-cast NULL, likely guard rejection')
FROM   unnest(ARRAY['sales_amount','discount','cost','quantity','transaction_date']) c;

-- ---------- MIN/MAX/AVG/SUM_VALUE - numeric columns ----------
SELECT bl_cl.fn_log_profile_safe('SA','sa_retail','src_retail_sales',c,'SA_RETAIL',m,
    format('SELECT %s(%I)::text FROM sa_retail.src_retail_sales', fn, c))
FROM   unnest(ARRAY['line_item_amount','bill_discount','min_amount','cost','quantity_sold']) c
CROSS JOIN (VALUES ('MIN_VALUE','MIN'), ('MAX_VALUE','MAX'), ('AVG_VALUE','AVG'), ('SUM_VALUE','SUM')) AS agg(m, fn);

SELECT bl_cl.fn_log_profile_safe('SA','sa_ecom','src_ecom_sales',c,'SA_ECOM',m,
    format('SELECT %s(%I)::text FROM sa_ecom.src_ecom_sales', fn, c))
FROM   unnest(ARRAY['sales_amount','discount','cost','quantity']) c
CROSS JOIN (VALUES ('MIN_VALUE','MIN'), ('MAX_VALUE','MAX'), ('AVG_VALUE','AVG'), ('SUM_VALUE','SUM')) AS agg(m, fn);

-- ---------- MIN/MAX_VALUE - transaction_date ----------
SELECT bl_cl.fn_log_profile_safe('SA','sa_retail','src_retail_sales','transaction_date','SA_RETAIL','MIN_VALUE',
    'SELECT MIN(transaction_date)::text FROM sa_retail.src_retail_sales');
SELECT bl_cl.fn_log_profile_safe('SA','sa_retail','src_retail_sales','transaction_date','SA_RETAIL','MAX_VALUE',
    'SELECT MAX(transaction_date)::text FROM sa_retail.src_retail_sales');
SELECT bl_cl.fn_log_profile_safe('SA','sa_ecom','src_ecom_sales','transaction_date','SA_ECOM','MIN_VALUE',
    'SELECT MIN(transaction_date)::text FROM sa_ecom.src_ecom_sales');
SELECT bl_cl.fn_log_profile_safe('SA','sa_ecom','src_ecom_sales','transaction_date','SA_ECOM','MAX_VALUE',
    'SELECT MAX(transaction_date)::text FROM sa_ecom.src_ecom_sales');

-- ---------- MIN/MAX_LENGTH - text columns (truncation check basis) ----------
SELECT bl_cl.fn_log_profile_safe('SA','sa_retail','src_retail_sales',c,'SA_RETAIL','MIN_LENGTH',
    format('SELECT MIN(LENGTH(%I))::text FROM sa_retail.src_retail_sales', c))
FROM   unnest(ARRAY['description','customer_name','employee_name','customer_address','employee_address','store_address']) c;
SELECT bl_cl.fn_log_profile_safe('SA','sa_retail','src_retail_sales',c,'SA_RETAIL','MAX_LENGTH',
    format('SELECT MAX(LENGTH(%I))::text FROM sa_retail.src_retail_sales', c))
FROM   unnest(ARRAY['description','customer_name','employee_name','customer_address','employee_address','store_address']) c;

-- ---------- MIN/MAX_LENGTH - ecom text columns (truncation check basis) ----------
SELECT bl_cl.fn_log_profile_safe('SA','sa_ecom','src_ecom_sales',c,'SA_ECOM','MIN_LENGTH',
    format('SELECT MIN(LENGTH(%I))::text FROM sa_ecom.src_ecom_sales', c))
FROM   unnest(ARRAY['details','user_name','ee_name','user_address','ee_address']) c;
SELECT bl_cl.fn_log_profile_safe('SA','sa_ecom','src_ecom_sales',c,'SA_ECOM','MAX_LENGTH',
    format('SELECT MAX(LENGTH(%I))::text FROM sa_ecom.src_ecom_sales', c))
FROM   unnest(ARRAY['details','user_name','ee_name','user_address','ee_address']) c;

-- ---------- DISTINCT_COUNT + TOP_VALUE_FREQ - categorical columns ----------
SELECT bl_cl.fn_log_profile_safe('SA','sa_retail','src_retail_sales',c,'SA_RETAIL','DISTINCT_COUNT',
    format('SELECT COUNT(DISTINCT %I)::text FROM sa_retail.src_retail_sales', c))
FROM   unnest(ARRAY['payment_method','zone_code','top_category','category','subcategory','customer_gender','employee_gender']) c;

SELECT bl_cl.fn_log_profile_safe('SA','sa_retail','src_retail_sales',c,'SA_RETAIL','TOP_VALUE_FREQ',
    format('SELECT string_agg(v || '':'' || n, '', '') FROM ('
           'SELECT %I AS v, COUNT(*) AS n FROM sa_retail.src_retail_sales '
           'GROUP BY %I ORDER BY COUNT(*) DESC LIMIT 5) t', c, c))
FROM   unnest(ARRAY['payment_method','zone_code','top_category','category','subcategory','customer_gender','employee_gender']) c;

SELECT bl_cl.fn_log_profile_safe('SA','sa_ecom','src_ecom_sales',c,'SA_ECOM','DISTINCT_COUNT',
    format('SELECT COUNT(DISTINCT %I)::text FROM sa_ecom.src_ecom_sales', c))
FROM   unnest(ARRAY['payment_type','product_type','user_gender','ee_gender']) c;

SELECT bl_cl.fn_log_profile_safe('SA','sa_ecom','src_ecom_sales',c,'SA_ECOM','TOP_VALUE_FREQ',
    format('SELECT string_agg(v || '':'' || n, '', '') FROM ('
           'SELECT %I AS v, COUNT(*) AS n FROM sa_ecom.src_ecom_sales '
           'GROUP BY %I ORDER BY COUNT(*) DESC LIMIT 5) t', c, c))
FROM   unnest(ARRAY['payment_type','product_type','user_gender','ee_gender']) c;

-- ---------- DUPLICATE_FULL_ROW_COUNT (expected 0, post-dedup) ----------
SELECT bl_cl.fn_log_profile_safe('SA','sa_retail','src_retail_sales',NULL,'SA_RETAIL','DUPLICATE_FULL_ROW_COUNT',
    'SELECT (COUNT(*) - COUNT(DISTINCT t.*::text))::text FROM sa_retail.src_retail_sales t');
SELECT bl_cl.fn_log_profile_safe('SA','sa_ecom','src_ecom_sales',NULL,'SA_ECOM','DUPLICATE_FULL_ROW_COUNT',
    'SELECT (COUNT(*) - COUNT(DISTINCT t.*::text))::text FROM sa_ecom.src_ecom_sales t');

-- ---------- DUPLICATE_KEY_COUNT (bill_id/payment_id, product_code) - post-dedup, expected <= SOURCE value ----------
SELECT bl_cl.fn_log_profile_safe('SA','sa_retail','src_retail_sales',NULL,'SA_RETAIL','DUPLICATE_KEY_COUNT',
    'SELECT COUNT(*)::text FROM (SELECT bill_id, product_code FROM sa_retail.src_retail_sales GROUP BY bill_id, product_code HAVING COUNT(*) > 1) d',
    'post-dedup grain-key duplicates; compare against 40_profiling_source.sql SOURCE-layer value');
SELECT bl_cl.fn_log_profile_safe('SA','sa_ecom','src_ecom_sales',NULL,'SA_ECOM','DUPLICATE_KEY_COUNT',
    'SELECT COUNT(*)::text FROM (SELECT payment_id, product_code FROM sa_ecom.src_ecom_sales GROUP BY payment_id, product_code HAVING COUNT(*) > 1) d',
    'post-dedup grain-key duplicates; compare against 40_profiling_source.sql SOURCE-layer value');

-- ---------- DUPLICATE_KEY_COUNT split - identical vs differing sales_amount within same grain key ----------
SELECT bl_cl.fn_log_profile_safe('SA','sa_ecom','src_ecom_sales',NULL,'SA_ECOM','DUPLICATE_KEY_COUNT',
    'SELECT COUNT(*)::text FROM (SELECT payment_id, product_code FROM sa_ecom.src_ecom_sales GROUP BY payment_id, product_code HAVING COUNT(DISTINCT sales_amount) = 1 AND COUNT(*) > 1) d',
    'identical_amount subset of grain-key duplicates');
SELECT bl_cl.fn_log_profile_safe('SA','sa_ecom','src_ecom_sales',NULL,'SA_ECOM','DUPLICATE_KEY_COUNT',
    'SELECT COUNT(*)::text FROM (SELECT payment_id, product_code FROM sa_ecom.src_ecom_sales GROUP BY payment_id, product_code HAVING COUNT(DISTINCT sales_amount) > 1) d',
    'differing_amount subset of grain-key duplicates');
