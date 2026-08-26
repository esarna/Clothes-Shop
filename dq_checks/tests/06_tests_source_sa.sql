-- ============================================================
-- DQ TEST GROUP 6 - SOURCE + SA LAYER
-- Completeness, uniqueness, validity, source-to-SA ETL checks.
-- ============================================================

DO $$
DECLARE
    v_tests_run     INTEGER := 0;
    v_tests_passed  INTEGER := 0;
    v_tests_failed  INTEGER := 0;
    v_failures      TEXT    := '';
    v_count         BIGINT;
    v_count2        BIGINT;
BEGIN
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'DQ TEST GROUP 6 - SOURCE + SA LAYER';
    RAISE NOTICE '================================================================';

    -- ============================================================
    -- 6.01 / 6.02 - Row count > 0 in ext_retail_sales / ext_ecom_sales
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count FROM sa_retail.ext_retail_sales;
    IF v_count > 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 6.01  ext_retail_sales row count: %', v_count;
        CALL bl_cl.prc_log_test_result('TC-DQ-COMP-SRC-01','ext_retail_sales has rows','DQ','Completeness','SOURCE','sa_retail','ext_retail_sales','SA_RETAIL','Critical','PASS','>0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || '  [FAIL] 6.01  ext_retail_sales is empty' || chr(10);
        CALL bl_cl.prc_log_test_result('TC-DQ-COMP-SRC-01','ext_retail_sales has rows','DQ','Completeness','SOURCE','sa_retail','ext_retail_sales','SA_RETAIL','Critical','FAIL','>0',v_count::text);
    END IF;

    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count FROM sa_ecom.ext_ecom_sales;
    IF v_count > 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 6.02  ext_ecom_sales row count: %', v_count;
        CALL bl_cl.prc_log_test_result('TC-DQ-COMP-SRC-02','ext_ecom_sales has rows','DQ','Completeness','SOURCE','sa_ecom','ext_ecom_sales','SA_ECOM','Critical','PASS','>0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || '  [FAIL] 6.02  ext_ecom_sales is empty' || chr(10);
        CALL bl_cl.prc_log_test_result('TC-DQ-COMP-SRC-02','ext_ecom_sales has rows','DQ','Completeness','SOURCE','sa_ecom','ext_ecom_sales','SA_ECOM','Critical','FAIL','>0',v_count::text);
    END IF;

    -- ============================================================
    -- 6.03 / 6.04 - Completeness: grain key blank/NULL rows excluded from src_*
    --   (tests.md 4.7 - rows with NULL/blank grain key confirmed excluded)
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count
    FROM   sa_retail.src_retail_sales
    WHERE  bill_id IS NULL OR TRIM(bill_id) = '' OR product_code IS NULL OR TRIM(product_code) = '';
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 6.03  src_retail_sales: no blank grain key rows';
        CALL bl_cl.prc_log_test_result('TC-ETL-VALID-SA-01','src_retail_sales excludes blank grain key rows','ETL','Validity','SA','sa_retail','src_retail_sales','SA_RETAIL','Critical','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 6.03  src_retail_sales: %s row(s) with blank grain key' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-ETL-VALID-SA-01','src_retail_sales excludes blank grain key rows','ETL','Validity','SA','sa_retail','src_retail_sales','SA_RETAIL','Critical','FAIL','0',v_count::text);
    END IF;

    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count
    FROM   sa_ecom.src_ecom_sales
    WHERE  payment_id IS NULL OR TRIM(payment_id) = '' OR product_code IS NULL OR TRIM(product_code) = '';
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 6.04  src_ecom_sales: no blank grain key rows';
        CALL bl_cl.prc_log_test_result('TC-ETL-VALID-SA-02','src_ecom_sales excludes blank grain key rows','ETL','Validity','SA','sa_ecom','src_ecom_sales','SA_ECOM','Critical','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 6.04  src_ecom_sales: %s row(s) with blank grain key' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-ETL-VALID-SA-02','src_ecom_sales excludes blank grain key rows','ETL','Validity','SA','sa_ecom','src_ecom_sales','SA_ECOM','Critical','FAIL','0',v_count::text);
    END IF;

    -- ============================================================
    -- 6.05 / 6.06 - Uniqueness: no full-row duplicates in src_* (post-dedup)
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count FROM (
        SELECT bill_id, product_code, COUNT(*) c
        FROM   sa_retail.src_retail_sales
        GROUP BY bill_id, product_code, line_item_amount, quantity_sold
        HAVING COUNT(*) > 1
    ) d;
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 6.05  src_retail_sales: no full-row duplicates';
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-SA-01','No full-row duplicates in src_retail_sales','DQ','Uniqueness','SA','sa_retail','src_retail_sales','SA_RETAIL','Critical','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 6.05  src_retail_sales: %s duplicate row group(s)' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-SA-01','No full-row duplicates in src_retail_sales','DQ','Uniqueness','SA','sa_retail','src_retail_sales','SA_RETAIL','Critical','FAIL','0',v_count::text);
    END IF;

    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count FROM (
        SELECT payment_id, product_code, COUNT(*) c
        FROM   sa_ecom.src_ecom_sales
        GROUP BY payment_id, product_code, sales_amount, quantity
        HAVING COUNT(*) > 1
    ) d;
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 6.06  src_ecom_sales: no full-row duplicates';
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-SA-02','No full-row duplicates in src_ecom_sales','DQ','Uniqueness','SA','sa_ecom','src_ecom_sales','SA_ECOM','Critical','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 6.06  src_ecom_sales: %s duplicate row group(s)' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-SA-02','No full-row duplicates in src_ecom_sales','DQ','Uniqueness','SA','sa_ecom','src_ecom_sales','SA_ECOM','Critical','FAIL','0',v_count::text);
    END IF;

    -- ============================================================
    -- 6.07 - Validity: cast guard, unparsable numeric values in ext_ become NULL in src_
    --   (a raw value that fails ^-?[0-9]+\.?[0-9]*$ must be NULL post-cast, not an error)
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count
    FROM   sa_retail.ext_retail_sales e
    WHERE  e.line_item_amount IS NOT NULL
      AND  TRIM(e.line_item_amount) !~ '^-?[0-9]+\.?[0-9]*$';
    SELECT COUNT(*) INTO v_count2
    FROM   sa_retail.src_retail_sales
    WHERE  line_item_amount IS NULL;
    IF v_count <= v_count2 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 6.07  src_retail_sales: cast guard absorbs % unparsable value(s) into % NULL(s)', v_count, v_count2;
        CALL bl_cl.prc_log_test_result('TC-DQ-VALID-SA-01','Cast guard for line_item_amount produces NULL not error','DQ','Validity','SA','sa_retail','src_retail_sales','SA_RETAIL','Major','PASS',v_count::text,v_count2::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 6.07  src_retail_sales: %s unparsable value(s) but only %s NULL(s) post-cast' || chr(10), v_count, v_count2);
        CALL bl_cl.prc_log_test_result('TC-DQ-VALID-SA-01','Cast guard for line_item_amount produces NULL not error','DQ','Validity','SA','sa_retail','src_retail_sales','SA_RETAIL','Major','FAIL',v_count::text,v_count2::text);
    END IF;

    -- ============================================================
    -- 6.08 - Validity: default value rule - ecom customer_email NOT 'n/a'/NULL,
    --   retail customer_email = 'n/a' (field absent in retail source)
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count
    FROM   bl_3nf.ce_customers_scd
    WHERE  source_system = 'SA_RETAIL' AND customer_email <> 'n/a' AND customer_id > 0;
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 6.08  ce_customers_scd: retail customer_email defaulted to n/a';
        CALL bl_cl.prc_log_test_result('TC-DQ-VALID-3NF-01','Retail customer_email defaults to n/a','DQ','Validity','BL_3NF','bl_3nf','ce_customers_scd','SA_RETAIL','Minor','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 6.08  %s retail customer row(s) with non n/a email' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-DQ-VALID-3NF-01','Retail customer_email defaults to n/a','DQ','Validity','BL_3NF','bl_3nf','ce_customers_scd','SA_RETAIL','Minor','FAIL','0',v_count::text);
    END IF;

    -- ============================================================
    -- 6.09 - Validity: gender columns contain only single value or n/a
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    SELECT COUNT(*) INTO v_count
    FROM   bl_3nf.ce_customers_scd
    WHERE  customer_gender NOT IN ('M', 'F', 'n/a');
    IF v_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 6.09  ce_customers_scd: customer_gender domain valid';
        CALL bl_cl.prc_log_test_result('TC-DQ-VALID-3NF-02','customer_gender domain restricted to M/F/n-a','DQ','Validity','BL_3NF','bl_3nf','ce_customers_scd','BOTH','Minor','PASS','0',v_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures || format('  [FAIL] 6.09  %s row(s) with invalid customer_gender' || chr(10), v_count);
        CALL bl_cl.prc_log_test_result('TC-DQ-VALID-3NF-02','customer_gender domain restricted to M/F/n-a','DQ','Validity','BL_3NF','bl_3nf','ce_customers_scd','BOTH','Minor','FAIL','0',v_count::text);
    END IF;

    -- ============================================================
    -- SUMMARY
    -- ============================================================
    RAISE NOTICE '----------------------------------------------------------------';
    RAISE NOTICE '  Tests run: %  passed: %  failed: %', v_tests_run, v_tests_passed, v_tests_failed;
    IF v_tests_failed > 0 THEN
        RAISE WARNING E'DQ TEST GROUP 6 - % test(s) failed:\n%', v_tests_failed, v_failures;
    ELSE
        RAISE NOTICE '  RESULT: ALL TESTS PASSED.';
    END IF;
END;
$$;
