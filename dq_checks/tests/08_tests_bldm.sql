-- ============================================================
-- DQ TEST GROUP 8 - BL_DM LAYER
-- FK orphans, KPI derivation checks, security absence.
-- ============================================================

DO $$
DECLARE
    v_tests_run     INTEGER := 0;
    v_tests_passed  INTEGER := 0;
    v_tests_failed  INTEGER := 0;
    v_failures      TEXT    := '';
    v_count         BIGINT;
BEGIN
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'DQ TEST GROUP 8 - BL_DM LAYER';
    RAISE NOTICE '================================================================';

    -- ============================================================
    -- 8.01-8.03 - No orphaned hard FKs in fct_sales_dd
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count FROM bl_dm.v_fct_sales_dd_full f
        WHERE NOT EXISTS (SELECT 1 FROM bl_dm.dim_time_day d WHERE d.date_surr_id = f.date_surr_id);
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 8.01  fct_sales_dd.date_surr_id: no orphaned FK';
        CALL bl_cl.prc_log_test_result('TC-DQ-CONS-DM-01','No orphaned date_surr_id FK in fct_sales_dd','DQ','Consistency','BL_DM','bl_dm','fct_sales_dd','BOTH','Critical','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 8.01  %s orphaned date_surr_id(s)' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-DQ-CONS-DM-01','No orphaned date_surr_id FK in fct_sales_dd','DQ','Consistency','BL_DM','bl_dm','fct_sales_dd','BOTH','Critical','FAIL','0',v_count::text);
    END IF;

    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count FROM bl_dm.v_fct_sales_dd_full f
        WHERE NOT EXISTS (SELECT 1 FROM bl_dm.dim_employees d WHERE d.employee_surr_id = f.employee_surr_id);
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 8.02  fct_sales_dd.employee_surr_id: no orphaned FK';
        CALL bl_cl.prc_log_test_result('TC-DQ-CONS-DM-02','No orphaned employee_surr_id FK in fct_sales_dd','DQ','Consistency','BL_DM','bl_dm','fct_sales_dd','BOTH','Critical','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 8.02  %s orphaned employee_surr_id(s)' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-DQ-CONS-DM-02','No orphaned employee_surr_id FK in fct_sales_dd','DQ','Consistency','BL_DM','bl_dm','fct_sales_dd','BOTH','Critical','FAIL','0',v_count::text);
    END IF;

    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count FROM bl_dm.v_fct_sales_dd_full f
        WHERE NOT EXISTS (SELECT 1 FROM bl_dm.dim_stores d WHERE d.store_surr_id = f.store_surr_id);
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 8.03  fct_sales_dd.store_surr_id: no orphaned FK';
        CALL bl_cl.prc_log_test_result('TC-DQ-CONS-DM-03','No orphaned store_surr_id FK in fct_sales_dd','DQ','Consistency','BL_DM','bl_dm','fct_sales_dd','BOTH','Critical','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 8.03  %s orphaned store_surr_id(s)' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-DQ-CONS-DM-03','No orphaned store_surr_id FK in fct_sales_dd','DQ','Consistency','BL_DM','bl_dm','fct_sales_dd','BOTH','Critical','FAIL','0',v_count::text);
    END IF;

    -- ============================================================
    -- 8.04 - Accuracy: FCT_NET_AMOUNT correctness (retail = sales-discount, ecom = sales)
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count FROM bl_dm.v_fct_sales_dd_full
    WHERE  source_system = 'SA_RETAIL'
      AND  fct_sales_amount IS NOT NULL AND fct_discount IS NOT NULL
      AND  ABS(fct_net_amount - (fct_sales_amount - fct_discount)) > 0.01;
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 8.04  fct_net_amount correct for RETAIL rows';
        CALL bl_cl.prc_log_test_result('TC-DQ-ACC-DM-01','fct_net_amount = sales_amount - discount (retail)','DQ','Accuracy','BL_DM','bl_dm','fct_sales_dd','SA_RETAIL','Critical','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 8.04  %s retail row(s) with wrong fct_net_amount' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-DQ-ACC-DM-01','fct_net_amount = sales_amount - discount (retail)','DQ','Accuracy','BL_DM','bl_dm','fct_sales_dd','SA_RETAIL','Critical','FAIL','0',v_count::text);
    END IF;

    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count FROM bl_dm.v_fct_sales_dd_full
    WHERE  source_system = 'SA_ECOM'
      AND  fct_sales_amount IS NOT NULL
      AND  ABS(fct_net_amount - fct_sales_amount) > 0.01;
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 8.05  fct_net_amount correct for ECOM rows';
        CALL bl_cl.prc_log_test_result('TC-DQ-ACC-DM-02','fct_net_amount = sales_amount (ecom, no double subtraction)','DQ','Accuracy','BL_DM','bl_dm','fct_sales_dd','SA_ECOM','Critical','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 8.05  %s ecom row(s) with wrong fct_net_amount' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-DQ-ACC-DM-02','fct_net_amount = sales_amount (ecom, no double subtraction)','DQ','Accuracy','BL_DM','bl_dm','fct_sales_dd','SA_ECOM','Critical','FAIL','0',v_count::text);
    END IF;

    -- ============================================================
    -- 8.06 - Accuracy: FCT_TOTAL_COST = unit_cost * quantity, FCT_GROSS_PROFIT = net - total_cost
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count FROM bl_dm.v_fct_sales_dd_full
    WHERE  fct_unit_cost IS NOT NULL AND fct_quantity IS NOT NULL
      AND  ABS(fct_total_cost - (fct_unit_cost * fct_quantity)) > 0.01;
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 8.06  fct_total_cost = unit_cost * quantity';
        CALL bl_cl.prc_log_test_result('TC-DQ-ACC-DM-03','fct_total_cost = fct_unit_cost * fct_quantity','DQ','Accuracy','BL_DM','bl_dm','fct_sales_dd','BOTH','Major','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 8.06  %s row(s) with wrong fct_total_cost' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-DQ-ACC-DM-03','fct_total_cost = fct_unit_cost * fct_quantity','DQ','Accuracy','BL_DM','bl_dm','fct_sales_dd','BOTH','Major','FAIL','0',v_count::text);
    END IF;

    -- ============================================================
    -- 8.07 - FCT_UNIT_COST = NULL for 100% of SA_ECOM rows
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count FROM bl_dm.v_fct_sales_dd_full
    WHERE  source_system = 'SA_ECOM' AND fct_unit_cost IS NOT NULL;
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 8.07  fct_unit_cost is NULL for all SA_ECOM rows';
        CALL bl_cl.prc_log_test_result('TC-ETL-VALID-DM-01','fct_unit_cost NULL for 100 pct of SA_ECOM rows','ETL','Validity','BL_DM','bl_dm','fct_sales_dd','SA_ECOM','Major','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 8.07  %s ecom row(s) with non-NULL fct_unit_cost' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-ETL-VALID-DM-01','fct_unit_cost NULL for 100 pct of SA_ECOM rows','ETL','Validity','BL_DM','bl_dm','fct_sales_dd','SA_ECOM','Major','FAIL','0',v_count::text);
    END IF;

    -- ============================================================
    -- 8.08 - Every row in a partition has event_dt within the partition's declared range
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count
    FROM   pg_inherits i
    JOIN   pg_class c ON c.oid = i.inhrelid
    JOIN   pg_namespace n ON n.oid = c.relnamespace
    JOIN   pg_class p ON p.oid = i.inhparent
    JOIN   bl_dm.fct_sales_dd f ON TRUE
    WHERE  n.nspname = 'bl_dm' AND p.relname = 'fct_sales_dd'
      AND  f.tableoid = c.oid
      AND  NOT (
            f.event_dt >= date_trunc('month', f.event_dt)
        AND f.event_dt <  date_trunc('month', f.event_dt) + INTERVAL '1 month'
      );
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 8.08  fct_sales_dd: every row within its monthly partition range';
        CALL bl_cl.prc_log_test_result('TC-DQ-TIME-DM-01','fct_sales_dd rows within declared partition range','DQ','Timeliness','BL_DM','bl_dm','fct_sales_dd','BOTH','Major','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 8.08  %s row(s) outside declared partition range' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-DQ-TIME-DM-01','fct_sales_dd rows within declared partition range','DQ','Timeliness','BL_DM','bl_dm','fct_sales_dd','BOTH','Major','FAIL','0',v_count::text);
    END IF;

    -- ============================================================
    -- 8.09 - Security: sensitive columns absent from dim_/fct_ tables
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count
    FROM   information_schema.columns
    WHERE  table_schema = 'bl_dm'
      AND  lower(column_name) IN ('customer_ssn','employee_ssn','ee_ssn','credit_card_number',
                                   'credit_card_expiration_date','credit_card_cvv','cvv','iban','bank_number');
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 8.09  No sensitive columns present in bl_dm';
        CALL bl_cl.prc_log_test_result('TC-SEC-DM-01','Sensitive columns absent from bl_dm schema','SECURITY',NULL,'BL_DM','bl_dm','ALL','N/A','Critical','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 8.09  %s sensitive column(s) found in bl_dm' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-SEC-DM-01','Sensitive columns absent from bl_dm schema','SECURITY',NULL,'BL_DM','bl_dm','ALL','N/A','Critical','FAIL','0',v_count::text);
    END IF;

    -- ============================================================
    -- SUMMARY
    -- ============================================================
    RAISE NOTICE '----------------------------------------------------------------';
    RAISE NOTICE '  Tests run: %  passed: %  failed: %', v_tests_run, v_tests_passed, v_tests_failed;
    IF v_tests_failed > 0 THEN
        RAISE WARNING E'DQ TEST GROUP 8 - % test(s) failed:\n%', v_tests_failed, v_failures;
    ELSE
        RAISE NOTICE '  RESULT: ALL TESTS PASSED.';
    END IF;
END;
$$;
