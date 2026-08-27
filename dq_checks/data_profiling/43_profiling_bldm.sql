-- ============================================================
-- PROFILING GROUP 4 - BL_DM LAYER (all dim_* and fct_sales_dd)
-- ============================================================

-- ---------- ROW_COUNT per dimension table ----------
SELECT bl_cl.fn_log_profile_safe('BL_DM','bl_dm',t,NULL,'BOTH','ROW_COUNT',
    format('SELECT COUNT(*)::text FROM bl_dm.%I', t))
FROM   unnest(ARRAY['dim_payment_types','dim_employees','dim_stores','dim_customers_scd','dim_products_scd','dim_time_day']) t;

-- ---------- fct_sales_dd ROW_COUNT split by source_system ----------
SELECT bl_cl.fn_log_profile_safe('BL_DM','bl_dm','fct_sales_dd',NULL,ss,'ROW_COUNT',
    format('SELECT COUNT(*)::text FROM bl_dm.fct_sales_dd WHERE source_system = %L', ss))
FROM   unnest(ARRAY['SA_RETAIL','SA_ECOM']) ss;

-- ---------- fct_sales_dd ROW_COUNT per attached partition ----------
SELECT bl_cl.fn_log_profile_safe('BL_DM','bl_dm', c.relname::text, NULL, 'BOTH', 'ROW_COUNT',
    format('SELECT COUNT(*)::text FROM bl_dm.%I', c.relname),
    'per-partition row count')
FROM   pg_inherits i
JOIN   pg_class c ON c.oid = i.inhrelid
JOIN   pg_class p ON p.oid = i.inhparent
JOIN   pg_namespace n ON n.oid = p.relnamespace
WHERE  n.nspname = 'bl_dm' AND p.relname = 'fct_sales_dd';

-- ---------- MIN/MAX/AVG/SUM for fct_* measures, split by source_system ----------
SELECT bl_cl.fn_log_profile_safe('BL_DM','bl_dm','fct_sales_dd',c,ss,m,
    format('SELECT %s(%I)::text FROM bl_dm.fct_sales_dd WHERE source_system = %L', fn, c, ss))
FROM   unnest(ARRAY['fct_sales_amount','fct_discount','fct_net_amount','fct_unit_cost','fct_quantity','fct_total_cost','fct_gross_profit']) c
CROSS JOIN (VALUES ('MIN_VALUE','MIN'), ('MAX_VALUE','MAX'), ('AVG_VALUE','AVG'), ('SUM_VALUE','SUM')) AS agg(m, fn)
CROSS JOIN unnest(ARRAY['SA_RETAIL','SA_ECOM']) ss;

-- ---------- NULL_PCT for fct_unit_cost/fct_total_cost on SA_ECOM (expect 100) ----------
SELECT bl_cl.fn_log_profile_safe('BL_DM','bl_dm','fct_sales_dd',c,'SA_ECOM','NULL_PCT',
    format('SELECT ROUND(100.0 * (SELECT COUNT(*) FROM bl_dm.fct_sales_dd WHERE source_system = ''SA_ECOM'' AND %I IS NULL) '
           '/ NULLIF((SELECT COUNT(*) FROM bl_dm.fct_sales_dd WHERE source_system = ''SA_ECOM''), 0), 2)::text', c),
    'expected 100 - cost data not available from SA_ECOM source')
FROM   unnest(ARRAY['fct_unit_cost','fct_total_cost']) c;

-- ---------- NULL_PCT for core KPI columns, both source systems (expect 0) ----------
SELECT bl_cl.fn_log_profile_safe('BL_DM','bl_dm','fct_sales_dd',c,ss,'NULL_PCT',
    format('SELECT ROUND(100.0 * (SELECT COUNT(*) FROM bl_dm.fct_sales_dd WHERE source_system = %L AND %I IS NULL) '
           '/ NULLIF((SELECT COUNT(*) FROM bl_dm.fct_sales_dd WHERE source_system = %L), 0), 2)::text', ss, c, ss),
    'expected 0 for core KPI columns')
FROM   unnest(ARRAY['fct_sales_amount','fct_discount','fct_net_amount','fct_quantity']) c
CROSS JOIN unnest(ARRAY['SA_RETAIL','SA_ECOM']) ss;
SELECT bl_cl.fn_log_profile_safe('BL_DM','bl_dm','fct_sales_dd','fct_gross_profit','SA_RETAIL','NULL_PCT',
    'SELECT ROUND(100.0 * (SELECT COUNT(*) FROM bl_dm.fct_sales_dd WHERE source_system = ''SA_RETAIL'' AND fct_gross_profit IS NULL) '
    '/ NULLIF((SELECT COUNT(*) FROM bl_dm.fct_sales_dd WHERE source_system = ''SA_RETAIL''), 0), 2)::text',
    'expected 0 - retail-only KPI (ecom gross profit = net amount, see fct_net_amount)');

-- ---------- Default row (surrogate = -1) presence - one per dim_* table ----------
SELECT bl_cl.fn_log_profile_safe('BL_DM','bl_dm',t,pk,'BOTH','ROW_COUNT',
    format('SELECT COUNT(*)::text FROM bl_dm.%I WHERE %I = -1', t, pk),
    'expected 1 - default row presence check')
FROM   (VALUES
    ('dim_payment_types','payment_type_surr_id'), ('dim_employees','employee_surr_id'),
    ('dim_stores','store_surr_id'), ('dim_customers_scd','customer_surr_id'),
    ('dim_products_scd','product_surr_id')
) AS x(t, pk);

-- ---------- ROW_COUNT where FK = -1 (unresolved lookup), one per FK ----------
SELECT bl_cl.fn_log_profile_safe('BL_DM','bl_dm','fct_sales_dd',fk,'BOTH','ROW_COUNT',
    format('SELECT COUNT(*)::text FROM bl_dm.fct_sales_dd WHERE %I = -1', fk),
    'unresolved lookup FK count')
FROM   unnest(ARRAY['date_surr_id','employee_surr_id','store_surr_id','payment_type_surr_id','customer_surr_id','product_surr_id']) fk;

-- ---------- DISTINCT_COUNT - product hierarchy breadth ----------
SELECT bl_cl.fn_log_profile_safe('BL_DM','bl_dm','dim_products_scd',c,'BOTH','DISTINCT_COUNT',
    format('SELECT COUNT(DISTINCT %I)::text FROM bl_dm.dim_products_scd', c))
FROM   unnest(ARRAY['product_top_category_name','product_category_name','product_subcategory_name']) c;

-- ---------- DISTINCT_COUNT - dim_time_day coverage confirmation ----------
SELECT bl_cl.fn_log_profile_safe('BL_DM','bl_dm','dim_time_day',c,'BOTH','DISTINCT_COUNT',
    format('SELECT COUNT(DISTINCT %I)::text FROM bl_dm.dim_time_day', c))
FROM   unnest(ARRAY['year_num','month_num']) c;
