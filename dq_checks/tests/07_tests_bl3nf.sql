-- ============================================================
-- DQ TEST GROUP 7 - BL_3NF LAYER
-- FK orphans, SCD2 non-overlap, accuracy reconciliation.
-- ============================================================

DO $$
DECLARE
    v_tests_run     INTEGER := 0;
    v_tests_passed  INTEGER := 0;
    v_tests_failed  INTEGER := 0;
    v_failures      TEXT    := '';
    v_count         BIGINT;
    v_sum_src       NUMERIC;
    v_sum_3nf       NUMERIC;
BEGIN
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'DQ TEST GROUP 7 - BL_3NF LAYER';
    RAISE NOTICE '================================================================';

    -- ============================================================
    -- 7.01-7.05 - Consistency: no orphaned FK in ce_sales (COALESCE to -1 guard)
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count FROM bl_3nf.ce_sales s
        WHERE NOT EXISTS (SELECT 1 FROM bl_dm.dim_time_day d WHERE d.date_surr_id = s.date_id);
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 7.01  ce_sales.date_id: no orphaned FK';
        CALL bl_cl.prc_log_test_result('TC-DQ-CONS-3NF-01','No orphaned date_id FK in ce_sales','DQ','Consistency','BL_3NF','bl_3nf','ce_sales','BOTH','Critical','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 7.01  %s orphaned date_id(s)' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-DQ-CONS-3NF-01','No orphaned date_id FK in ce_sales','DQ','Consistency','BL_3NF','bl_3nf','ce_sales','BOTH','Critical','FAIL','0',v_count::text);
    END IF;

    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count FROM bl_3nf.ce_sales s
        WHERE NOT EXISTS (SELECT 1 FROM bl_3nf.ce_employees e WHERE e.employee_id = s.employee_id);
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 7.02  ce_sales.employee_id: no orphaned FK';
        CALL bl_cl.prc_log_test_result('TC-DQ-CONS-3NF-02','No orphaned employee_id FK in ce_sales','DQ','Consistency','BL_3NF','bl_3nf','ce_sales','BOTH','Critical','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 7.02  %s orphaned employee_id(s)' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-DQ-CONS-3NF-02','No orphaned employee_id FK in ce_sales','DQ','Consistency','BL_3NF','bl_3nf','ce_sales','BOTH','Critical','FAIL','0',v_count::text);
    END IF;

    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count FROM bl_3nf.ce_sales s
        WHERE NOT EXISTS (SELECT 1 FROM bl_3nf.ce_stores st WHERE st.store_id = s.store_id);
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 7.03  ce_sales.store_id: no orphaned FK';
        CALL bl_cl.prc_log_test_result('TC-DQ-CONS-3NF-03','No orphaned store_id FK in ce_sales','DQ','Consistency','BL_3NF','bl_3nf','ce_sales','BOTH','Critical','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 7.03  %s orphaned store_id(s)' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-DQ-CONS-3NF-03','No orphaned store_id FK in ce_sales','DQ','Consistency','BL_3NF','bl_3nf','ce_sales','BOTH','Critical','FAIL','0',v_count::text);
    END IF;

    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count FROM bl_3nf.ce_sales s
        WHERE NOT EXISTS (SELECT 1 FROM bl_3nf.ce_payment_types p WHERE p.payment_type_id = s.payment_type_id);
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 7.04  ce_sales.payment_type_id: no orphaned FK';
        CALL bl_cl.prc_log_test_result('TC-DQ-CONS-3NF-04','No orphaned payment_type_id FK in ce_sales','DQ','Consistency','BL_3NF','bl_3nf','ce_sales','BOTH','Critical','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 7.04  %s orphaned payment_type_id(s)' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-DQ-CONS-3NF-04','No orphaned payment_type_id FK in ce_sales','DQ','Consistency','BL_3NF','bl_3nf','ce_sales','BOTH','Critical','FAIL','0',v_count::text);
    END IF;

    -- logical FKs (customer_id / product_id) - must resolve to an existing row or -1
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count FROM bl_3nf.ce_sales s
        WHERE s.customer_id <> -1
          AND NOT EXISTS (SELECT 1 FROM bl_3nf.ce_customers_scd c WHERE c.customer_id = s.customer_id);
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 7.05  ce_sales.customer_id: resolves to existing row or -1';
        CALL bl_cl.prc_log_test_result('TC-DQ-CONS-3NF-05','Logical customer_id FK resolves or defaults to -1','DQ','Consistency','BL_3NF','bl_3nf','ce_sales','BOTH','Major','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 7.05  %s unresolved customer_id(s)' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-DQ-CONS-3NF-05','Logical customer_id FK resolves or defaults to -1','DQ','Consistency','BL_3NF','bl_3nf','ce_sales','BOTH','Major','FAIL','0',v_count::text);
    END IF;

    -- ============================================================
    -- 7.06 - SCD2 temporal non-overlap in ce_customers_scd
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count
    FROM   bl_3nf.ce_customers_scd a
    JOIN   bl_3nf.ce_customers_scd b
           ON  a.customer_src_id = b.customer_src_id
           AND a.source_system   = b.source_system
           AND a.start_dt        <> b.start_dt
           AND a.start_dt <= b.end_dt AND b.start_dt <= a.end_dt
    WHERE  a.customer_id > 0 AND b.customer_id > 0;
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 7.06  ce_customers_scd: no overlapping SCD2 versions';
        CALL bl_cl.prc_log_test_result('TC-DQ-CONS-3NF-06','No overlapping SCD2 periods in ce_customers_scd','DQ','Consistency','BL_3NF','bl_3nf','ce_customers_scd','BOTH','Critical','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 7.06  %s overlapping SCD2 version pair(s)' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-DQ-CONS-3NF-06','No overlapping SCD2 periods in ce_customers_scd','DQ','Consistency','BL_3NF','bl_3nf','ce_customers_scd','BOTH','Critical','FAIL','0',v_count::text);
    END IF;

    -- ============================================================
    -- 7.07 - ce_locations NK collision indicator (informational, always PASS)
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count FROM bl_3nf.ce_locations WHERE location_src_id = 'n/a_n/a';
    v_tests_passed := v_tests_passed + 1;
    RAISE NOTICE '  [PASS] 7.07  ce_locations n/a_n/a collision count (informational): %', v_count;
    CALL bl_cl.prc_log_test_result('TC-DQ-CONS-3NF-07','ce_locations n-a_n-a NK collision count (informational)','DQ','Consistency','BL_3NF','bl_3nf','ce_locations','BOTH','Trivial','PASS','n/a',v_count::text);

    -- ============================================================
    -- 7.08 - Accuracy: aggregate reconciliation SUM(sales_amount) SA vs BL_3NF, per source
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    SELECT COALESCE(SUM(line_item_amount), 0) INTO v_sum_src FROM sa_retail.src_retail_sales;
    SELECT COALESCE(SUM(sales_amount), 0) INTO v_sum_3nf FROM bl_3nf.ce_sales WHERE source_system = 'SA_RETAIL';
    IF ABS(v_sum_src - v_sum_3nf) < 0.01 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 7.08  SUM(sales_amount) SA_RETAIL reconciles: SA=% 3NF=%', v_sum_src, v_sum_3nf;
        CALL bl_cl.prc_log_test_result('TC-DQ-ACC-3NF-01','SUM sales_amount reconciles SA to ce_sales (retail)','DQ','Accuracy','BL_3NF','bl_3nf','ce_sales','SA_RETAIL','Critical','PASS',v_sum_src::text,v_sum_3nf::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 7.08  SUM mismatch SA=%s 3NF=%s' || chr(10), v_sum_src, v_sum_3nf);
        CALL bl_cl.prc_log_test_result('TC-DQ-ACC-3NF-01','SUM sales_amount reconciles SA to ce_sales (retail)','DQ','Accuracy','BL_3NF','bl_3nf','ce_sales','SA_RETAIL','Critical','FAIL',v_sum_src::text,v_sum_3nf::text);
    END IF;

    -- ============================================================
    -- 7.09 - Security: sensitive columns absent from ce_* (spot check ce_customers_scd, ce_employees)
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count
    FROM   information_schema.columns
    WHERE  table_schema = 'bl_3nf'
      AND  table_name IN ('ce_customers_scd', 'ce_employees')
      AND  lower(column_name) IN ('customer_ssn','employee_ssn','ee_ssn','credit_card_number',
                                   'credit_card_expiration_date','credit_card_cvv','cvv','iban','bank_number');
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 7.09  No sensitive columns present in ce_customers_scd/ce_employees';
        CALL bl_cl.prc_log_test_result('TC-SEC-3NF-01','Sensitive columns absent from ce_customers_scd/ce_employees','SECURITY',NULL,'BL_3NF','bl_3nf','ce_customers_scd/ce_employees','N/A','Critical','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 7.09  %s sensitive column(s) found' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-SEC-3NF-01','Sensitive columns absent from ce_customers_scd/ce_employees','SECURITY',NULL,'BL_3NF','bl_3nf','ce_customers_scd/ce_employees','N/A','Critical','FAIL','0',v_count::text);
    END IF;

    -- ============================================================
    -- SUMMARY
    -- ============================================================
    RAISE NOTICE '----------------------------------------------------------------';
    RAISE NOTICE '  Tests run: %  passed: %  failed: %', v_tests_run, v_tests_passed, v_tests_failed;
    IF v_tests_failed > 0 THEN
        RAISE WARNING E'DQ TEST GROUP 7 - % test(s) failed:\n%', v_tests_failed, v_failures;
    ELSE
        RAISE NOTICE '  RESULT: ALL TESTS PASSED.';
    END IF;
END;
$$;
