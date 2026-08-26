-- ============================================================
-- PROFILING GROUP 3 - BL_3NF LAYER (all ce_* tables)
-- ============================================================

-- ---------- ROW_COUNT per table, split by source_system where tagged ----------
SELECT bl_cl.fn_log_profile_safe('BL_3NF','bl_3nf',t,NULL,'BOTH','ROW_COUNT',
    format('SELECT COUNT(*)::text FROM bl_3nf.%I', t))
FROM   unnest(ARRAY['ce_store_zones','ce_payment_types','ce_product_top_categories','ce_product_categories',
                     'ce_product_subcategories','ce_locations']) t;

SELECT bl_cl.fn_log_profile_safe('BL_3NF','bl_3nf',t,NULL,ss,'ROW_COUNT',
    format('SELECT COUNT(*)::text FROM bl_3nf.%I WHERE source_system = %L', t, ss))
FROM   unnest(ARRAY['ce_sales','ce_customers_scd','ce_products_scd','ce_employees','ce_stores']) t
CROSS JOIN unnest(ARRAY['SA_RETAIL','SA_ECOM']) ss;

-- ---------- ROW_COUNT_DELTA vs SA layer for ce_sales ----------
SELECT bl_cl.fn_log_profile_safe('BL_3NF','bl_3nf','ce_sales',NULL,'SA_RETAIL','ROW_COUNT_DELTA',
    'SELECT ((SELECT COUNT(*) FROM sa_retail.src_retail_sales) - (SELECT COUNT(*) FROM bl_3nf.ce_sales WHERE source_system = ''SA_RETAIL''))::text');
SELECT bl_cl.fn_log_profile_safe('BL_3NF','bl_3nf','ce_sales',NULL,'SA_ECOM','ROW_COUNT_DELTA',
    'SELECT ((SELECT COUNT(*) FROM sa_ecom.src_ecom_sales) - (SELECT COUNT(*) FROM bl_3nf.ce_sales WHERE source_system = ''SA_ECOM''))::text');

-- ---------- SCD2 versioning volume: is_active split + versions per key ----------
SELECT bl_cl.fn_log_profile_safe('BL_3NF','bl_3nf','ce_customers_scd',NULL,'BOTH','ROW_COUNT',
    format('SELECT COUNT(*)::text FROM bl_3nf.ce_customers_scd WHERE is_active = %L', ia))
FROM   unnest(ARRAY['Y','N']) ia;
SELECT bl_cl.fn_log_profile_safe('BL_3NF','bl_3nf','ce_customers_scd','customer_src_id','BOTH','DISTINCT_COUNT',
    'SELECT COUNT(DISTINCT customer_src_id)::text FROM bl_3nf.ce_customers_scd',
    'compare to total row count for average versions per natural key');

SELECT bl_cl.fn_log_profile_safe('BL_3NF','bl_3nf','ce_products_scd',NULL,'BOTH','ROW_COUNT',
    format('SELECT COUNT(*)::text FROM bl_3nf.ce_products_scd WHERE is_active = %L', ia))
FROM   unnest(ARRAY['Y','N']) ia;
SELECT bl_cl.fn_log_profile_safe('BL_3NF','bl_3nf','ce_products_scd','product_src_id','BOTH','DISTINCT_COUNT',
    'SELECT COUNT(DISTINCT product_src_id)::text FROM bl_3nf.ce_products_scd',
    'compare to total row count for average versions per natural key');

-- ---------- ce_sales measures + unresolved FK counts ----------
SELECT bl_cl.fn_log_profile_safe('BL_3NF','bl_3nf','ce_sales',c,'BOTH',m,
    format('SELECT %s(%I)::text FROM bl_3nf.ce_sales', fn, c))
FROM   unnest(ARRAY['sales_amount','discount','cost','quantity']) c
CROSS JOIN (VALUES ('MIN_VALUE','MIN'), ('MAX_VALUE','MAX'), ('AVG_VALUE','AVG'), ('SUM_VALUE','SUM')) AS agg(m, fn);

SELECT bl_cl.fn_log_profile_safe('BL_3NF','bl_3nf','ce_sales',fk,'BOTH','ROW_COUNT',
    format('SELECT COUNT(*)::text FROM bl_3nf.ce_sales WHERE %I = -1', fk),
    'unresolved lookup FK count')
FROM   unnest(ARRAY['date_id','employee_id','store_id','payment_type_id','customer_id','product_id']) fk;

-- ---------- ce_locations n/a_n/a collision indicator ----------
SELECT bl_cl.fn_log_profile_safe('BL_3NF','bl_3nf','ce_locations',NULL,'BOTH','ROW_COUNT',
    'SELECT COUNT(*)::text FROM bl_3nf.ce_locations WHERE location_src_id = ''n/a_n/a''',
    'natural key collision indicator');

-- ---------- Product hierarchy: DISTINCT_COUNT + TOP_VALUE_FREQ ----------
SELECT bl_cl.fn_log_profile_safe('BL_3NF','bl_3nf',t,c,'BOTH','DISTINCT_COUNT',
    format('SELECT COUNT(DISTINCT %I)::text FROM bl_3nf.%I', c, t))
FROM   (VALUES
    ('ce_product_top_categories','product_top_category_name'),
    ('ce_product_categories','product_category_name'),
    ('ce_product_subcategories','product_subcategory_name')
) AS x(t, c);

SELECT bl_cl.fn_log_profile_safe('BL_3NF','bl_3nf',t,c,'BOTH','TOP_VALUE_FREQ',
    format('SELECT string_agg(v || '':'' || n, '', '') FROM (SELECT %I AS v, COUNT(*) AS n FROM bl_3nf.%I GROUP BY %I ORDER BY COUNT(*) DESC LIMIT 5) s', c, t, c))
FROM   (VALUES
    ('ce_product_top_categories','product_top_category_name'),
    ('ce_product_categories','product_category_name'),
    ('ce_product_subcategories','product_subcategory_name')
) AS x(t, c);

-- ---------- NULL_COUNT for every NOT NULL column (deviation = defaulting rule failure) ----------
SELECT bl_cl.fn_log_profile_safe('BL_3NF', col.table_schema::text, col.table_name::text, col.column_name::text, 'BOTH', 'NULL_COUNT',
    format('SELECT COUNT(*)::text FROM %I.%I WHERE %I IS NULL', col.table_schema, col.table_name, col.column_name),
    'expected 0 - deviation indicates a defaulting rule failure')
FROM   information_schema.columns col
WHERE  col.table_schema = 'bl_3nf'
  AND  col.is_nullable = 'NO'
  AND  col.table_name LIKE 'ce_%';
