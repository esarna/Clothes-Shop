-- ============================================================
-- DQ TEST GROUP 9 - SCHEMA VALIDATION, SECURITY, AD HOC
-- ============================================================

DO $$
DECLARE
    v_tests_run     INTEGER := 0;
    v_tests_passed  INTEGER := 0;
    v_tests_failed  INTEGER := 0;
    v_failures      TEXT    := '';
    v_count         BIGINT;
    v_expected_tables TEXT[] := ARRAY[
        'bl_3nf.ce_store_zones','bl_3nf.ce_payment_types','bl_3nf.ce_product_top_categories',
        'bl_3nf.ce_product_categories','bl_3nf.ce_product_subcategories','bl_3nf.ce_locations',
        'bl_3nf.ce_employees','bl_3nf.ce_stores','bl_3nf.ce_customers_scd','bl_3nf.ce_products_scd',
        'bl_3nf.ce_sales',
        'bl_dm.dim_payment_types','bl_dm.dim_employees','bl_dm.dim_stores',
        'bl_dm.dim_customers_scd','bl_dm.dim_products_scd','bl_dm.fct_sales_dd','bl_dm.dim_time_day'
    ];
    v_expected_default_row_tables TEXT[] := ARRAY[
        'bl_3nf.ce_store_zones','bl_3nf.ce_payment_types','bl_3nf.ce_product_top_categories',
        'bl_3nf.ce_product_categories','bl_3nf.ce_product_subcategories','bl_3nf.ce_locations',
        'bl_3nf.ce_employees','bl_3nf.ce_stores',
        'bl_dm.dim_payment_types','bl_dm.dim_employees','bl_dm.dim_stores'
    ];
    v_missing_tables TEXT := '';
    v_missing_pk     TEXT := '';
    v_missing_default TEXT := '';
    t TEXT;
BEGIN
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'DQ TEST GROUP 9 - SCHEMA VALIDATION, SECURITY, AD HOC';
    RAISE NOTICE '================================================================';

    -- ============================================================
    -- 9.01 - Table existence: every expected table present
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    FOREACH t IN ARRAY v_expected_tables LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema || '.' || table_name = t
        ) THEN
            v_missing_tables := v_missing_tables || t || ', ';
        END IF;
    END LOOP;
    IF v_missing_tables = '' THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 9.01  All expected tables exist';
        CALL bl_cl.prc_log_test_result('TC-SCHEMA-01','All expected core tables exist','SCHEMA',NULL,'CROSS_LAYER',NULL,'ALL','N/A','Critical','PASS','0 missing','0 missing');
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 9.01  Missing tables: %s' || chr(10), v_missing_tables);
        CALL bl_cl.prc_log_test_result('TC-SCHEMA-01','All expected core tables exist','SCHEMA',NULL,'CROSS_LAYER',NULL,'ALL','N/A','Critical','FAIL','0 missing',v_missing_tables);
    END IF;

    -- ============================================================
    -- 9.02 - PK exists on every expected table
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    FOREACH t IN ARRAY v_expected_tables LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM   information_schema.table_constraints tc
            WHERE  tc.table_schema || '.' || tc.table_name = t
              AND  tc.constraint_type = 'PRIMARY KEY'
        ) THEN
            v_missing_pk := v_missing_pk || t || ', ';
        END IF;
    END LOOP;
    IF v_missing_pk = '' THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 9.02  Every table has a PRIMARY KEY';
        CALL bl_cl.prc_log_test_result('TC-SCHEMA-02','PRIMARY KEY exists on every core table','SCHEMA',NULL,'CROSS_LAYER',NULL,'ALL','N/A','Critical','PASS','0 missing','0 missing');
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 9.02  Tables missing PK: %s' || chr(10), v_missing_pk);
        CALL bl_cl.prc_log_test_result('TC-SCHEMA-02','PRIMARY KEY exists on every core table','SCHEMA',NULL,'CROSS_LAYER',NULL,'ALL','N/A','Critical','FAIL','0 missing',v_missing_pk);
    END IF;

    -- ============================================================
    -- 9.03 - Default row (id = -1) exists in every ce_*/dim_* dimension table
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    v_missing_default := '';
    IF NOT EXISTS (SELECT 1 FROM bl_3nf.ce_store_zones WHERE store_zone_id = -1) THEN v_missing_default := v_missing_default || 'ce_store_zones, '; END IF;
    IF NOT EXISTS (SELECT 1 FROM bl_3nf.ce_payment_types WHERE payment_type_id = -1) THEN v_missing_default := v_missing_default || 'ce_payment_types, '; END IF;
    IF NOT EXISTS (SELECT 1 FROM bl_3nf.ce_product_top_categories WHERE product_top_category_id = -1) THEN v_missing_default := v_missing_default || 'ce_product_top_categories, '; END IF;
    IF NOT EXISTS (SELECT 1 FROM bl_3nf.ce_product_categories WHERE product_category_id = -1) THEN v_missing_default := v_missing_default || 'ce_product_categories, '; END IF;
    IF NOT EXISTS (SELECT 1 FROM bl_3nf.ce_product_subcategories WHERE product_subcategory_id = -1) THEN v_missing_default := v_missing_default || 'ce_product_subcategories, '; END IF;
    IF NOT EXISTS (SELECT 1 FROM bl_3nf.ce_locations WHERE location_id = -1) THEN v_missing_default := v_missing_default || 'ce_locations, '; END IF;
    IF NOT EXISTS (SELECT 1 FROM bl_3nf.ce_employees WHERE employee_id = -1) THEN v_missing_default := v_missing_default || 'ce_employees, '; END IF;
    IF NOT EXISTS (SELECT 1 FROM bl_3nf.ce_stores WHERE store_id = -1) THEN v_missing_default := v_missing_default || 'ce_stores, '; END IF;
    IF NOT EXISTS (SELECT 1 FROM bl_dm.dim_payment_types WHERE payment_type_surr_id = -1) THEN v_missing_default := v_missing_default || 'dim_payment_types, '; END IF;
    IF NOT EXISTS (SELECT 1 FROM bl_dm.dim_employees WHERE employee_surr_id = -1) THEN v_missing_default := v_missing_default || 'dim_employees, '; END IF;
    IF NOT EXISTS (SELECT 1 FROM bl_dm.dim_stores WHERE store_surr_id = -1) THEN v_missing_default := v_missing_default || 'dim_stores, '; END IF;

    IF v_missing_default = '' THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 9.03  Default row (-1) present in every dimension table';
        CALL bl_cl.prc_log_test_result('TC-SCHEMA-03','Default row -1 present in every dimension table','SCHEMA',NULL,'CROSS_LAYER',NULL,'ALL','N/A','Minor','PASS','0 missing','0 missing');
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 9.03  Missing default rows in: %s' || chr(10), v_missing_default);
        CALL bl_cl.prc_log_test_result('TC-SCHEMA-03','Default row -1 present in every dimension table','SCHEMA',NULL,'CROSS_LAYER',NULL,'ALL','N/A','Minor','FAIL','0 missing',v_missing_default);
    END IF;

    -- ============================================================
    -- 9.04 - Security sweep: sensitive columns absent from SA/BL_3NF/BL_DM (all schemas at once)
    -- ============================================================
    -- ext_* foreign tables are raw 1:1 CSV mirrors and are expected to carry
    -- sensitive columns; the exclusion policy applies from src_* onward.
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count
    FROM   information_schema.columns
    WHERE  table_schema IN ('sa_retail', 'sa_ecom', 'bl_3nf', 'bl_dm')
      AND  table_name NOT LIKE 'ext_%'
      AND  lower(column_name) IN ('customer_ssn','employee_ssn','ee_ssn','user_ssn','credit_card_number',
                                   'credit_card_expiration_date','credit_card_cvv','cvv','iban','bank_number');
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 9.04  Full sweep: sensitive columns absent from SA/BL_3NF/BL_DM (excluding raw ext_*)';
        CALL bl_cl.prc_log_test_result('TC-SEC-ALL-01','Sensitive columns absent across SA/BL_3NF/BL_DM (full sweep, excl. raw ext_*)','SECURITY',NULL,'CROSS_LAYER',NULL,'ALL','N/A','Critical','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 9.04  %s sensitive column(s) found across SA/BL_3NF/BL_DM' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-SEC-ALL-01','Sensitive columns absent across SA/BL_3NF/BL_DM (full sweep, excl. raw ext_*)','SECURITY',NULL,'CROSS_LAYER',NULL,'ALL','N/A','Critical','FAIL','0',v_count::text);
    END IF;

    -- ============================================================
    -- 9.05 - Ad hoc: product hierarchy self-consistency
    --   no subcategory associated with more than one distinct parent category
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count FROM (
        SELECT product_subcategory_id
        FROM   bl_3nf.ce_product_subcategories
        GROUP BY product_subcategory_id
        HAVING COUNT(DISTINCT product_category_id) > 1
    ) d;
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 9.05  Product hierarchy self-consistent (no subcategory with >1 parent)';
        CALL bl_cl.prc_log_test_result('TC-ADHOC-01','Product hierarchy self-consistency (subcategory to category)','ADHOC',NULL,'BL_3NF','bl_3nf','ce_product_subcategories','BOTH','Minor','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 9.05  %s subcategory(ies) with multiple parent categories' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-ADHOC-01','Product hierarchy self-consistency (subcategory to category)','ADHOC',NULL,'BL_3NF','bl_3nf','ce_product_subcategories','BOTH','Minor','FAIL','0',v_count::text);
    END IF;

    -- ============================================================
    -- SUMMARY
    -- ============================================================
    RAISE NOTICE '----------------------------------------------------------------';
    RAISE NOTICE '  Tests run: %  passed: %  failed: %', v_tests_run, v_tests_passed, v_tests_failed;
    IF v_tests_failed > 0 THEN
        RAISE WARNING E'DQ TEST GROUP 9 - % test(s) failed:\n%', v_tests_failed, v_failures;
    ELSE
        RAISE NOTICE '  RESULT: ALL TESTS PASSED.';
    END IF;
END;
$$;
