-- ============================================================
-- PROFILING GROUP 1 - SOURCE LAYER (ext_retail_sales, ext_ecom_sales)
-- Every metric is a single scalar query logged via bl_cl.fn_log_profile_safe.
-- ============================================================

-- ---------- ROW_COUNT ----------
SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_retail','ext_retail_sales',NULL,'SA_RETAIL','ROW_COUNT',
    'SELECT COUNT(*)::text FROM sa_retail.ext_retail_sales');
SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_ecom','ext_ecom_sales',NULL,'SA_ECOM','ROW_COUNT',
    'SELECT COUNT(*)::text FROM sa_ecom.ext_ecom_sales');

-- ---------- NULL_COUNT / NULL_PCT - retail key columns ----------
SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_retail','ext_retail_sales',c,'SA_RETAIL','NULL_COUNT',
    format('SELECT COUNT(*)::text FROM sa_retail.ext_retail_sales WHERE %I IS NULL OR TRIM(%I) = ''''', c, c))
FROM   unnest(ARRAY['customer_id','bill_id','product_code','employee_id','description','colour','size']) c;

SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_retail','ext_retail_sales',c,'SA_RETAIL','NULL_PCT',
    format('SELECT ROUND(100.0 * (SELECT COUNT(*) FROM sa_retail.ext_retail_sales WHERE %I IS NULL OR TRIM(%I) = '''') '
           '/ NULLIF((SELECT COUNT(*) FROM sa_retail.ext_retail_sales), 0), 2)::text', c, c))
FROM   unnest(ARRAY['customer_id','bill_id','product_code','employee_id','description','colour','size']) c;

-- ---------- NULL_COUNT / NULL_PCT - ecom key columns ----------
SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_ecom','ext_ecom_sales',c,'SA_ECOM','NULL_COUNT',
    format('SELECT COUNT(*)::text FROM sa_ecom.ext_ecom_sales WHERE %I IS NULL OR TRIM(%I) = ''''', c, c))
FROM   unnest(ARRAY['user_id','payment_id','product_code','ee_id','details']) c;

SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_ecom','ext_ecom_sales',c,'SA_ECOM','NULL_PCT',
    format('SELECT ROUND(100.0 * (SELECT COUNT(*) FROM sa_ecom.ext_ecom_sales WHERE %I IS NULL OR TRIM(%I) = '''') '
           '/ NULLIF((SELECT COUNT(*) FROM sa_ecom.ext_ecom_sales), 0), 2)::text', c, c))
FROM   unnest(ARRAY['user_id','payment_id','product_code','ee_id','details']) c;

-- ---------- UNPARSABLE_NUMERIC_COUNT ----------
SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_retail','ext_retail_sales',c,'SA_RETAIL','UNPARSABLE_NUMERIC_COUNT',
    format('SELECT COUNT(*)::text FROM sa_retail.ext_retail_sales WHERE %I IS NOT NULL AND TRIM(%I) !~ ''^-?[0-9]+\.?[0-9]*$''', c, c))
FROM   unnest(ARRAY['line_item_amount','bill_discount','min_amount','cost','quantity_sold','customer_age']) c;

SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_ecom','ext_ecom_sales',c,'SA_ECOM','UNPARSABLE_NUMERIC_COUNT',
    format('SELECT COUNT(*)::text FROM sa_ecom.ext_ecom_sales WHERE %I IS NOT NULL AND TRIM(%I) !~ ''^-?[0-9]+\.?[0-9]*$''', c, c))
FROM   unnest(ARRAY['sales_amount','discount','cost','quantity','user_age']) c;

-- ---------- UNPARSABLE_DATE_COUNT ----------
SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_retail','ext_retail_sales','transaction_date','SA_RETAIL','UNPARSABLE_DATE_COUNT',
    'SELECT COUNT(*)::text FROM sa_retail.ext_retail_sales WHERE transaction_date IS NOT NULL AND TRIM(transaction_date) !~ ''^\d{4}-\d{2}-\d{2}$''');
SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_ecom','ext_ecom_sales','transaction_date','SA_ECOM','UNPARSABLE_DATE_COUNT',
    'SELECT COUNT(*)::text FROM sa_ecom.ext_ecom_sales WHERE transaction_date IS NOT NULL AND TRIM(transaction_date) !~ ''^\d{4}-\d{2}-\d{2}$''');

-- ---------- DISTINCT_COUNT + TOP_VALUE_FREQ ----------
SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_retail','ext_retail_sales',c,'SA_RETAIL','DISTINCT_COUNT',
    format('SELECT COUNT(DISTINCT %I)::text FROM sa_retail.ext_retail_sales', c))
FROM   unnest(ARRAY['payment_method','zone_code','top_category','category','subcategory','customer_gender','employee_gender']) c;

SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_retail','ext_retail_sales',c,'SA_RETAIL','TOP_VALUE_FREQ',
    format('SELECT string_agg(v || '':'' || n, '', '') FROM ('
           'SELECT %I AS v, COUNT(*) AS n FROM sa_retail.ext_retail_sales '
           'GROUP BY %I ORDER BY COUNT(*) DESC LIMIT 5) t', c, c))
FROM   unnest(ARRAY['payment_method','zone_code','top_category','category','subcategory','customer_gender','employee_gender']) c;

SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_ecom','ext_ecom_sales',c,'SA_ECOM','DISTINCT_COUNT',
    format('SELECT COUNT(DISTINCT %I)::text FROM sa_ecom.ext_ecom_sales', c))
FROM   unnest(ARRAY['payment_type','product_type','user_gender','ee_gender']) c;

SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_ecom','ext_ecom_sales',c,'SA_ECOM','TOP_VALUE_FREQ',
    format('SELECT string_agg(v || '':'' || n, '', '') FROM ('
           'SELECT %I AS v, COUNT(*) AS n FROM sa_ecom.ext_ecom_sales '
           'GROUP BY %I ORDER BY COUNT(*) DESC LIMIT 5) t', c, c))
FROM   unnest(ARRAY['payment_type','product_type','user_gender','ee_gender']) c;

-- ---------- DUPLICATE_FULL_ROW_COUNT ----------
SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_retail','ext_retail_sales',NULL,'SA_RETAIL','DUPLICATE_FULL_ROW_COUNT',
    'SELECT (COUNT(*) - COUNT(DISTINCT t.*::text))::text FROM sa_retail.ext_retail_sales t');
SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_ecom','ext_ecom_sales',NULL,'SA_ECOM','DUPLICATE_FULL_ROW_COUNT',
    'SELECT (COUNT(*) - COUNT(DISTINCT t.*::text))::text FROM sa_ecom.ext_ecom_sales t');

-- ---------- DUPLICATE_KEY_COUNT (bill_id/payment_id, product_code) - split identical vs differing amount ----------
SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_retail','ext_retail_sales',NULL,'SA_RETAIL','DUPLICATE_KEY_COUNT',
    'SELECT COUNT(*)::text FROM (SELECT bill_id, product_code FROM sa_retail.ext_retail_sales GROUP BY bill_id, product_code HAVING COUNT(*) > 1) d',
    'identical_amount vs differing_amount split not computed here; see 41_profiling_sa.sql for SA-layer post-dedup detail');
SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_ecom','ext_ecom_sales',NULL,'SA_ECOM','DUPLICATE_KEY_COUNT',
    'SELECT COUNT(*)::text FROM (SELECT payment_id, product_code FROM sa_ecom.ext_ecom_sales GROUP BY payment_id, product_code HAVING COUNT(*) > 1) d',
    'identical_amount vs differing_amount split not computed here; see 41_profiling_sa.sql for SA-layer post-dedup detail');
