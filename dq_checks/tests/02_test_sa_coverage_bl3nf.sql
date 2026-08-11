-- ============================================================
-- DQ TEST GROUP 2 — SA Layer Coverage in BL_3NF

DO $$
DECLARE
    v_tests_run         INTEGER := 0;
    v_tests_passed      INTEGER := 0;
    v_tests_failed      INTEGER := 0;
    v_failures          TEXT    := '';

    v_missing_count     BIGINT;
    v_sa_retail_total   BIGINT;
    v_sa_ecom_total     BIGINT;
    v_ce_sales_retail   BIGINT;
    v_ce_sales_ecom     BIGINT;

BEGIN
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'DQ TEST GROUP 2 — SA LAYER COVERAGE IN BL_3NF.CE_SALES';
    RAISE NOTICE 'Executed at: %', CURRENT_TIMESTAMP;
    RAISE NOTICE '================================================================';


    -- ── Row count context (informational) ────────────────────
    SELECT COUNT(DISTINCT (TRIM(bill_id), TRIM(product_code)))
    INTO   v_sa_retail_total
    FROM   sa_retail.src_retail_sales
    WHERE  bill_id     IS NOT NULL AND TRIM(bill_id)     <> ''
      AND  product_code IS NOT NULL AND TRIM(product_code) <> '';

    SELECT COUNT(DISTINCT (TRIM(payment_id), TRIM(product_code)))
    INTO   v_sa_ecom_total
    FROM   sa_ecom.src_ecom_sales
    WHERE  payment_id   IS NOT NULL AND TRIM(payment_id)   <> ''
      AND  product_code IS NOT NULL AND TRIM(product_code) <> '';

    SELECT COUNT(*) INTO v_ce_sales_retail
    FROM   bl_3nf.ce_sales
    WHERE  source_system = 'SA_RETAIL';

    SELECT COUNT(*) INTO v_ce_sales_ecom
    FROM   bl_3nf.ce_sales
    WHERE  source_system = 'SA_ECOM';

    RAISE NOTICE '  [INFO] SA_RETAIL  valid grain rows (bill_id+product_code): %', v_sa_retail_total;
    RAISE NOTICE '  [INFO] CE_SALES   SA_RETAIL rows loaded                  : %', v_ce_sales_retail;
    RAISE NOTICE '  [INFO] SA_ECOM    valid grain rows (payment_id+product_code): %', v_sa_ecom_total;
    RAISE NOTICE '  [INFO] CE_SALES   SA_ECOM rows loaded                    : %', v_ce_sales_ecom;
    RAISE NOTICE '----------------------------------------------------------------';


    -- ============================================================
    -- TEST 2.01 — SA_RETAIL coverage
    --   Every valid (bill_id, product_code) grain in
    --   src_retail_sales must exist in ce_sales.
    --
    --   Match logic:
    --     ce_sales.sale_src_id   = TRIM(src.bill_id)
    --     ce_sales.source_system = 'SA_RETAIL'
    --
    --   NOTE: product_id join via ce_products_scd would be
    --   circular — we verify grain coverage via sale_src_id
    --   + source_system (which is the dedup key ETL uses).
    --   This correctly mirrors the ETL NOT EXISTS guard.
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*)
    INTO   v_missing_count
    FROM (
        SELECT DISTINCT
            TRIM(src.bill_id)       AS sale_src_id,
            TRIM(src.product_code)  AS product_code
        FROM sa_retail.src_retail_sales src
        WHERE src.bill_id     IS NOT NULL AND TRIM(src.bill_id)     <> ''
          AND src.product_code IS NOT NULL AND TRIM(src.product_code) <> ''
    ) sa
    WHERE NOT EXISTS (
        SELECT 1
        FROM   bl_3nf.ce_sales    tgt
        JOIN   bl_3nf.ce_products_scd p ON p.product_id = tgt.product_id
        WHERE  tgt.sale_src_id   = sa.sale_src_id
        AND  tgt.source_system = 'SA_RETAIL'
        AND  p.product_src_id  = sa.product_code
    );

    IF v_missing_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 2.01  SA_RETAIL → CE_SALES coverage: all % grain rows present',
            v_sa_retail_total;
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 2.01  SA_RETAIL: %s grain row(s) in src_retail_sales have NO match in ce_sales' || chr(10),
                v_missing_count);
        RAISE WARNING '  [FAIL] 2.01  SA_RETAIL → CE_SALES: % grain row(s) missing', v_missing_count;
    END IF;


    -- ============================================================
    -- TEST 2.02 — SA_ECOM coverage
    --   Every valid (payment_id, product_code) grain in
    --   src_ecom_sales must exist in ce_sales.
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*)
    INTO   v_missing_count
    FROM (
        SELECT DISTINCT
            TRIM(src.payment_id)    AS sale_src_id,
            TRIM(src.product_code)  AS product_code
        FROM sa_ecom.src_ecom_sales src
        WHERE src.payment_id  IS NOT NULL AND TRIM(src.payment_id)  <> ''
          AND src.product_code IS NOT NULL AND TRIM(src.product_code) <> ''
    ) sa
    WHERE NOT EXISTS (
        SELECT 1
        FROM   bl_3nf.ce_sales    tgt
        JOIN   bl_3nf.ce_products_scd p ON p.product_id = tgt.product_id
        WHERE  tgt.sale_src_id   = sa.sale_src_id
            AND  tgt.source_system = 'SA_ECOM'
            AND  p.product_src_id  = sa.product_code
    );

    IF v_missing_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 2.02  SA_ECOM → CE_SALES coverage: all % grain rows present',
            v_sa_ecom_total;
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 2.02  SA_ECOM: %s grain row(s) in src_ecom_sales have NO match in ce_sales' || chr(10),
                v_missing_count);
        RAISE WARNING '  [FAIL] 2.02  SA_ECOM → CE_SALES: % grain row(s) missing', v_missing_count;
    END IF;


    -- ============================================================
    -- TEST 2.03 — SA_RETAIL distinct customers coverage
    --   Every distinct customer_id in SA_RETAIL must have at
    --   least one row in ce_customers_scd (any version).
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*)
    INTO   v_missing_count
    FROM (
        SELECT DISTINCT TRIM(customer_id) AS customer_src_id
        FROM   sa_retail.src_retail_sales
        WHERE  customer_id IS NOT NULL AND TRIM(customer_id) <> ''
    ) sa
    WHERE NOT EXISTS (
        SELECT 1
        FROM   bl_3nf.ce_customers_scd tgt
        WHERE  tgt.customer_src_id = sa.customer_src_id
    );

    IF v_missing_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 2.03  SA_RETAIL customers → CE_CUSTOMERS_SCD: all present';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 2.03  SA_RETAIL: %s customer(s) not found in ce_customers_scd' || chr(10),
                v_missing_count);
        RAISE WARNING '  [FAIL] 2.03  SA_RETAIL customers missing in CE_CUSTOMERS_SCD: %', v_missing_count;
    END IF;


    -- ============================================================
    -- TEST 2.04 — SA_ECOM distinct customers coverage
    --   Every distinct user_id in SA_ECOM must have at least
    --   one row in ce_customers_scd.
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*)
    INTO   v_missing_count
    FROM (
        SELECT DISTINCT TRIM(user_id) AS customer_src_id
        FROM   sa_ecom.src_ecom_sales
        WHERE  user_id IS NOT NULL AND TRIM(user_id) <> ''
    ) sa
    WHERE NOT EXISTS (
        SELECT 1
        FROM   bl_3nf.ce_customers_scd tgt
        WHERE  tgt.customer_src_id = sa.customer_src_id
    );

    IF v_missing_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 2.04  SA_ECOM customers → CE_CUSTOMERS_SCD: all present';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 2.04  SA_ECOM: %s user(s) not found in ce_customers_scd' || chr(10),
                v_missing_count);
        RAISE WARNING '  [FAIL] 2.04  SA_ECOM customers missing in CE_CUSTOMERS_SCD: %', v_missing_count;
    END IF;


    -- ============================================================
    -- TEST 2.05 — SA distinct products coverage (both sources)
    --   Every distinct product_code from both SA sources must
    --   have at least one row in ce_products_scd.
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*)
    INTO   v_missing_count
    FROM (
        SELECT DISTINCT TRIM(product_code) AS product_src_id
        FROM   sa_retail.src_retail_sales
        WHERE  product_code IS NOT NULL AND TRIM(product_code) <> ''
        UNION
        SELECT DISTINCT TRIM(product_code)
        FROM   sa_ecom.src_ecom_sales
        WHERE  product_code IS NOT NULL AND TRIM(product_code) <> ''
    ) sa
    WHERE NOT EXISTS (
        SELECT 1
        FROM   bl_3nf.ce_products_scd tgt
        WHERE  tgt.product_src_id = sa.product_src_id
    );

    IF v_missing_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 2.05  SA products → CE_PRODUCTS_SCD: all product codes present';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 2.05  %s product code(s) from SA not found in ce_products_scd' || chr(10),
                v_missing_count);
        RAISE WARNING '  [FAIL] 2.05  Products missing in CE_PRODUCTS_SCD: %', v_missing_count;
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
        RAISE EXCEPTION E'DQ TEST GROUP 2 FAILED — % test(s) failed:\n%',
            v_tests_failed, v_failures;
    ELSE
        RAISE NOTICE '  RESULT: ALL TESTS PASSED — SA layer fully covered in BL_3NF.';
        RAISE NOTICE '================================================================';
    END IF;

END;
$$;