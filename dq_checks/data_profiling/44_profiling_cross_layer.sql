-- ============================================================
-- PROFILING GROUP 5 - CROSS-LAYER RECONCILIATION
-- ============================================================

-- ---------- ROW_COUNT_DELTA chain per source_system: SOURCE -> SA -> BL_3NF -> BL_DM ----------
SELECT bl_cl.fn_log_profile_safe('CROSS_LAYER',NULL,'source_to_sa_retail',NULL,'SA_RETAIL','ROW_COUNT_DELTA',
    '(SELECT (SELECT COUNT(*) FROM sa_retail.ext_retail_sales) - (SELECT COUNT(*) FROM sa_retail.src_retail_sales))::text',
    'SOURCE to SA: expected delta = dedup + NULL-key filter removals');
SELECT bl_cl.fn_log_profile_safe('CROSS_LAYER',NULL,'sa_to_bl3nf_retail',NULL,'SA_RETAIL','ROW_COUNT_DELTA',
    '(SELECT (SELECT COUNT(*) FROM sa_retail.src_retail_sales) - (SELECT COUNT(*) FROM bl_3nf.ce_sales WHERE source_system = ''SA_RETAIL''))::text',
    'SA to BL_3NF: expected 0 for append-only ce_sales load');
SELECT bl_cl.fn_log_profile_safe('CROSS_LAYER',NULL,'bl3nf_to_bldm_retail',NULL,'SA_RETAIL','ROW_COUNT_DELTA',
    '(SELECT (SELECT COUNT(*) FROM bl_3nf.ce_sales WHERE source_system = ''SA_RETAIL'') - (SELECT COUNT(*) FROM bl_dm.fct_sales_dd WHERE source_system = ''SA_RETAIL''))::text',
    'BL_3NF to BL_DM: expected 0, 1:1 grain load');

SELECT bl_cl.fn_log_profile_safe('CROSS_LAYER',NULL,'source_to_sa_ecom',NULL,'SA_ECOM','ROW_COUNT_DELTA',
    '(SELECT (SELECT COUNT(*) FROM sa_ecom.ext_ecom_sales) - (SELECT COUNT(*) FROM sa_ecom.src_ecom_sales))::text',
    'SOURCE to SA: expected delta = dedup + NULL-key filter removals');
SELECT bl_cl.fn_log_profile_safe('CROSS_LAYER',NULL,'sa_to_bl3nf_ecom',NULL,'SA_ECOM','ROW_COUNT_DELTA',
    '(SELECT (SELECT COUNT(*) FROM sa_ecom.src_ecom_sales) - (SELECT COUNT(*) FROM bl_3nf.ce_sales WHERE source_system = ''SA_ECOM''))::text',
    'SA to BL_3NF: expected 0 for append-only ce_sales load');
SELECT bl_cl.fn_log_profile_safe('CROSS_LAYER',NULL,'bl3nf_to_bldm_ecom',NULL,'SA_ECOM','ROW_COUNT_DELTA',
    '(SELECT (SELECT COUNT(*) FROM bl_3nf.ce_sales WHERE source_system = ''SA_ECOM'') - (SELECT COUNT(*) FROM bl_dm.fct_sales_dd WHERE source_system = ''SA_ECOM''))::text',
    'BL_3NF to BL_DM: expected 0, 1:1 grain load');

-- ---------- SUM_VALUE reconciliation for the sales-amount measure, one metric per layer ----------
SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_retail','ext_retail_sales','line_item_amount','SA_RETAIL','SUM_VALUE',
    'SELECT SUM(line_item_amount::numeric)::text FROM sa_retail.ext_retail_sales WHERE TRIM(line_item_amount) ~ ''^-?[0-9]+\.?[0-9]*$''');
SELECT bl_cl.fn_log_profile_safe('SA','sa_retail','src_retail_sales','line_item_amount','SA_RETAIL','SUM_VALUE',
    'SELECT SUM(line_item_amount)::text FROM sa_retail.src_retail_sales');
SELECT bl_cl.fn_log_profile_safe('BL_3NF','bl_3nf','ce_sales','sales_amount','SA_RETAIL','SUM_VALUE',
    'SELECT SUM(sales_amount)::text FROM bl_3nf.ce_sales WHERE source_system = ''SA_RETAIL''');
SELECT bl_cl.fn_log_profile_safe('BL_DM','bl_dm','fct_sales_dd','fct_sales_amount','SA_RETAIL','SUM_VALUE',
    'SELECT SUM(fct_sales_amount)::text FROM bl_dm.fct_sales_dd WHERE source_system = ''SA_RETAIL''');

SELECT bl_cl.fn_log_profile_safe('SOURCE','sa_ecom','ext_ecom_sales','sales_amount','SA_ECOM','SUM_VALUE',
    'SELECT SUM(sales_amount::numeric)::text FROM sa_ecom.ext_ecom_sales WHERE TRIM(sales_amount) ~ ''^-?[0-9]+\.?[0-9]*$''');
SELECT bl_cl.fn_log_profile_safe('SA','sa_ecom','src_ecom_sales','sales_amount','SA_ECOM','SUM_VALUE',
    'SELECT SUM(sales_amount)::text FROM sa_ecom.src_ecom_sales');
SELECT bl_cl.fn_log_profile_safe('BL_3NF','bl_3nf','ce_sales','sales_amount','SA_ECOM','SUM_VALUE',
    'SELECT SUM(sales_amount)::text FROM bl_3nf.ce_sales WHERE source_system = ''SA_ECOM''');
SELECT bl_cl.fn_log_profile_safe('BL_DM','bl_dm','fct_sales_dd','fct_sales_amount','SA_ECOM','SUM_VALUE',
    'SELECT SUM(fct_sales_amount)::text FROM bl_dm.fct_sales_dd WHERE source_system = ''SA_ECOM''');
