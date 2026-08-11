-- ============================================================
-- DQ TEST GROUP 5 — Restartability (Idempotency)

DO $$
DECLARE
    v_tests_run     INTEGER := 0;
    v_tests_passed  INTEGER := 0;
    v_tests_failed  INTEGER := 0;
    v_failures      TEXT    := '';

    -- Row count snapshots: before / after 2nd run
    v_before_ce_sales           BIGINT;
    v_before_ce_customers       BIGINT;
    v_before_ce_products        BIGINT;
    v_before_fct_sales          BIGINT;
    v_before_dim_customers      BIGINT;
    v_before_dim_products       BIGINT;

    v_after_ce_sales            BIGINT;
    v_after_ce_customers        BIGINT;
    v_after_ce_products         BIGINT;
    v_after_fct_sales           BIGINT;
    v_after_dim_customers       BIGINT;
    v_after_dim_products        BIGINT;

    -- Log check
    v_log_ts_before             TIMESTAMP;
    v_rows_inserted_ce_sales    INTEGER;
    v_rows_inserted_fct_sales   INTEGER;
    v_error_count               INTEGER;

BEGIN
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'DQ TEST GROUP 5 — RESTARTABILITY (IDEMPOTENCY TEST)';
    RAISE NOTICE 'Executed at: %', CURRENT_TIMESTAMP;
    RAISE NOTICE '================================================================';
    RAISE NOTICE '  Step 1: Capture row counts BEFORE 2nd ETL run...';

    -- ── Step 1: Snapshot BEFORE ───────────────────────────────────
    SELECT COUNT(*) INTO v_before_ce_sales       FROM bl_3nf.ce_sales;
    SELECT COUNT(*) INTO v_before_ce_customers   FROM bl_3nf.ce_customers_scd  WHERE customer_id > 0;
    SELECT COUNT(*) INTO v_before_ce_products    FROM bl_3nf.ce_products_scd   WHERE product_id  > 0;
    SELECT COUNT(*) INTO v_before_fct_sales      FROM bl_dm.v_fct_sales_dd_full;
    SELECT COUNT(*) INTO v_before_dim_customers  FROM bl_dm.dim_customers_scd  WHERE customer_surr_id > 0;
    SELECT COUNT(*) INTO v_before_dim_products   FROM bl_dm.dim_products_scd   WHERE product_surr_id  > 0;

    RAISE NOTICE '  [BEFORE] ce_sales          : %', v_before_ce_sales;
    RAISE NOTICE '  [BEFORE] ce_customers_scd  : %', v_before_ce_customers;
    RAISE NOTICE '  [BEFORE] ce_products_scd   : %', v_before_ce_products;
    RAISE NOTICE '  [BEFORE] fct_sales_dd      : %', v_before_fct_sales;
    RAISE NOTICE '  [BEFORE] dim_customers_scd : %', v_before_dim_customers;
    RAISE NOTICE '  [BEFORE] dim_products_scd  : %', v_before_dim_products;
    RAISE NOTICE '----------------------------------------------------------------';

    -- Record timestamp just before 2nd run (for log queries)
    v_log_ts_before := CURRENT_TIMESTAMP;

    RAISE NOTICE '  Step 2: Executing 2nd ETL run (prc_master_load_bl3nf + prc_master_load_bldm)...';

    -- ── Step 2: Execute 2nd full ETL run ──────────────────────────
    CALL bl_cl.prc_master_load_bl3nf();
    CALL bl_cl.prc_master_load_bldm();

    RAISE NOTICE '  Step 2: ETL run completed.';
    RAISE NOTICE '----------------------------------------------------------------';
    RAISE NOTICE '  Step 3: Capture row counts AFTER 2nd ETL run...';

    -- ── Step 3: Snapshot AFTER ────────────────────────────────────
    SELECT COUNT(*) INTO v_after_ce_sales       FROM bl_3nf.ce_sales;
    SELECT COUNT(*) INTO v_after_ce_customers   FROM bl_3nf.ce_customers_scd  WHERE customer_id > 0;
    SELECT COUNT(*) INTO v_after_ce_products    FROM bl_3nf.ce_products_scd   WHERE product_id  > 0;
    SELECT COUNT(*) INTO v_after_fct_sales      FROM bl_dm.v_fct_sales_dd_full;
    SELECT COUNT(*) INTO v_after_dim_customers  FROM bl_dm.dim_customers_scd  WHERE customer_surr_id > 0;
    SELECT COUNT(*) INTO v_after_dim_products   FROM bl_dm.dim_products_scd   WHERE product_surr_id  > 0;

    RAISE NOTICE '  [AFTER]  ce_sales          : %', v_after_ce_sales;
    RAISE NOTICE '  [AFTER]  ce_customers_scd  : %', v_after_ce_customers;
    RAISE NOTICE '  [AFTER]  ce_products_scd   : %', v_after_ce_products;
    RAISE NOTICE '  [AFTER]  fct_sales_dd      : %', v_after_fct_sales;
    RAISE NOTICE '  [AFTER]  dim_customers_scd : %', v_after_dim_customers;
    RAISE NOTICE '  [AFTER]  dim_products_scd  : %', v_after_dim_products;
    RAISE NOTICE '----------------------------------------------------------------';

    -- ============================================================
    -- TEST 5.01 — CE_SALES row count unchanged
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    IF v_after_ce_sales = v_before_ce_sales THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 5.01  ce_sales row count unchanged on 2nd run: %', v_after_ce_sales;
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 5.01  ce_sales: BEFORE=%s AFTER=%s (delta=%s unexpected rows)' || chr(10),
                v_before_ce_sales, v_after_ce_sales, v_after_ce_sales - v_before_ce_sales);
        RAISE WARNING '  [FAIL] 5.01  ce_sales changed: % → %', v_before_ce_sales, v_after_ce_sales;
    END IF;

    -- ============================================================
    -- TEST 5.02 — CE_CUSTOMERS_SCD row count unchanged
    --   (SCD2 — no new attribute changes on re-run with same data)
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    IF v_after_ce_customers = v_before_ce_customers THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 5.02  ce_customers_scd row count unchanged: %', v_after_ce_customers;
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 5.02  ce_customers_scd: BEFORE=%s AFTER=%s' || chr(10),
                v_before_ce_customers, v_after_ce_customers);
        RAISE WARNING '  [FAIL] 5.02  ce_customers_scd changed: % → %', v_before_ce_customers, v_after_ce_customers;
    END IF;

    -- ============================================================
    -- TEST 5.03 — CE_PRODUCTS_SCD row count unchanged
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    IF v_after_ce_products = v_before_ce_products THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 5.03  ce_products_scd row count unchanged: %', v_after_ce_products;
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 5.03  ce_products_scd: BEFORE=%s AFTER=%s' || chr(10),
                v_before_ce_products, v_after_ce_products);
        RAISE WARNING '  [FAIL] 5.03  ce_products_scd changed: % → %', v_before_ce_products, v_after_ce_products;
    END IF;

    -- ============================================================
    -- TEST 5.04 — FCT_SALES_DD row count unchanged
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    IF v_after_fct_sales = v_before_fct_sales THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 5.04  fct_sales_dd row count unchanged: %', v_after_fct_sales;
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 5.04  fct_sales_dd: BEFORE=%s AFTER=%s (delta=%s)' || chr(10),
                v_before_fct_sales, v_after_fct_sales, v_after_fct_sales - v_before_fct_sales);
        RAISE WARNING '  [FAIL] 5.04  fct_sales_dd changed: % → %', v_before_fct_sales, v_after_fct_sales;
    END IF;

    -- ============================================================
    -- TEST 5.05 — DIM_CUSTOMERS_SCD row count unchanged
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    IF v_after_dim_customers = v_before_dim_customers THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 5.05  dim_customers_scd row count unchanged: %', v_after_dim_customers;
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 5.05  dim_customers_scd: BEFORE=%s AFTER=%s' || chr(10),
                v_before_dim_customers, v_after_dim_customers);
        RAISE WARNING '  [FAIL] 5.05  dim_customers_scd changed: % → %', v_before_dim_customers, v_after_dim_customers;
    END IF;

    -- ============================================================
    -- TEST 5.06 — DIM_PRODUCTS_SCD row count unchanged
    -- ============================================================
    v_tests_run := v_tests_run + 1;
    IF v_after_dim_products = v_before_dim_products THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 5.06  dim_products_scd row count unchanged: %', v_after_dim_products;
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 5.06  dim_products_scd: BEFORE=%s AFTER=%s' || chr(10),
                v_before_dim_products, v_after_dim_products);
        RAISE WARNING '  [FAIL] 5.06  dim_products_scd changed: % → %', v_before_dim_products, v_after_dim_products;
    END IF;

    -- ============================================================
    -- TEST 5.07 — Log check: rows_inserted = 0 for CE_SALES on 2nd run
    --   Verifies the logging table confirms idempotency.
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COALESCE(SUM(rows_inserted), 0)
    INTO   v_rows_inserted_ce_sales
    FROM   bl_cl.mta_load_logs
    WHERE  procedure_name LIKE '%prc_load_ce_sales%'
      AND  status          = 'SUCCESS'
      AND  ta_log_dt       > v_log_ts_before;

    IF v_rows_inserted_ce_sales = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 5.07  Log: prc_load_ce_sales rows_inserted=0 on 2nd run (idempotent)';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 5.07  prc_load_ce_sales logged %s rows_inserted on 2nd run — '
                   'expected 0 (same source data)' || chr(10), v_rows_inserted_ce_sales);
        RAISE WARNING '  [FAIL] 5.07  prc_load_ce_sales: % rows_inserted on 2nd run',
                      v_rows_inserted_ce_sales;
    END IF;

    -- ============================================================
    -- TEST 5.08 — Log check: rows_inserted = 0 for FCT_SALES_DD on 2nd run
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COALESCE(SUM(rows_inserted), 0)
    INTO   v_rows_inserted_fct_sales
    FROM   bl_cl.mta_load_logs
    WHERE  procedure_name = 'prc_load_fct_sales_dd'
      AND  status         = 'SUCCESS'
      AND  ta_log_dt      > v_log_ts_before;

    IF v_rows_inserted_fct_sales = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 5.08  Log: prc_load_fct_sales_dd rows_inserted=0 on 2nd run (idempotent)';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 5.08  prc_load_fct_sales_dd logged %s rows_inserted on 2nd run — '
                   'expected 0' || chr(10), v_rows_inserted_fct_sales);
        RAISE WARNING '  [FAIL] 5.08  prc_load_fct_sales_dd: % rows_inserted on 2nd run',
                      v_rows_inserted_fct_sales;
    END IF;

    -- ============================================================
    -- TEST 5.09 — No ERROR status in logs from 2nd run
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*) INTO v_error_count
    FROM   bl_cl.mta_load_logs
    WHERE  status    = 'ERROR'
      AND  ta_log_dt > v_log_ts_before;

    IF v_error_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 5.09  Log: no ERROR entries from 2nd ETL run';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 5.09  % ERROR log entry(ies) found from 2nd ETL run' || chr(10), v_error_count);
        RAISE WARNING '  [FAIL] 5.09  % ERROR entries in mta_load_logs from 2nd run', v_error_count;
    END IF;

    -- ============================================================
    -- SUMMARY
    -- ============================================================
    RAISE NOTICE '----------------------------------------------------------------';
    RAISE NOTICE '  Tests run   : %', v_tests_run;
    RAISE NOTICE '  Tests passed: %', v_tests_passed;
    RAISE NOTICE '  Tests failed: %', v_tests_failed;
    RAISE NOTICE '================================================================';

    IF v_tests_failed > 0 THEN
        RAISE EXCEPTION E'DQ TEST GROUP 5 FAILED — % test(s) failed:\n%',
            v_tests_failed, v_failures;
    ELSE
        RAISE NOTICE '  RESULT: ALL TESTS PASSED — ETL is fully restartable/idempotent.';
        RAISE NOTICE '================================================================';
    END IF;

END;
$$;