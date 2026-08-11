-- ============================================================
-- DQ TEST GROUP 4 — BL_3NF Coverage in BL_DM

DO $$
DECLARE
    v_tests_run     INTEGER := 0;
    v_tests_passed  INTEGER := 0;
    v_tests_failed  INTEGER := 0;
    v_failures      TEXT    := '';
    v_missing_count BIGINT;
BEGIN
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'DQ TEST GROUP 4 — BL_3NF COVERAGE IN BL_DM';
    RAISE NOTICE 'Executed at: %', CURRENT_TIMESTAMP;
    RAISE NOTICE '================================================================';


    -- ============================================================
    -- TEST 4.01 — CE_PAYMENT_TYPES → DIM_PAYMENT_TYPES
    --   Every PAYMENT_TYPE_SRC_ID in BL_3NF (excl. default -1)
    --   must exist in BL_DM.
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*) INTO v_missing_count
    FROM (
        SELECT payment_type_src_id
        FROM   bl_3nf.ce_payment_types
        WHERE  payment_type_id > 0
    ) src
    WHERE NOT EXISTS (
        SELECT 1 FROM bl_dm.dim_payment_types tgt
        WHERE  tgt.payment_type_src_id = src.payment_type_src_id
    );

    IF v_missing_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 4.01  CE_PAYMENT_TYPES → DIM_PAYMENT_TYPES: all keys present';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 4.01  DIM_PAYMENT_TYPES: %s key(s) missing from BL_3NF' || chr(10), v_missing_count);
        RAISE WARNING '  [FAIL] 4.01  DIM_PAYMENT_TYPES missing % key(s)', v_missing_count;
    END IF;


    -- ============================================================
    -- TEST 4.02 — CE_EMPLOYEES → DIM_EMPLOYEES
    --   Every (EMPLOYEE_SRC_ID + SOURCE_SYSTEM) in BL_3NF
    --   (excl. default -1) must exist in BL_DM.
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*) INTO v_missing_count
    FROM (
        SELECT employee_src_id, source_system
        FROM   bl_3nf.ce_employees
        WHERE  employee_id > 0
    ) src
    WHERE NOT EXISTS (
        SELECT 1 FROM bl_dm.dim_employees tgt
        WHERE  tgt.employee_src_id = src.employee_src_id
          AND  tgt.source_system   = src.source_system
    );

    IF v_missing_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 4.02  CE_EMPLOYEES → DIM_EMPLOYEES: all keys present';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 4.02  DIM_EMPLOYEES: %s key(s) missing' || chr(10), v_missing_count);
        RAISE WARNING '  [FAIL] 4.02  DIM_EMPLOYEES missing % key(s)', v_missing_count;
    END IF;


    -- ============================================================
    -- TEST 4.03 — CE_STORES → DIM_STORES
    --   Every STORE_SRC_ID in BL_3NF (excl. default -1)
    --   must exist in BL_DM.
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*) INTO v_missing_count
    FROM (
        SELECT store_src_id
        FROM   bl_3nf.ce_stores
        WHERE  store_id > 0
    ) src
    WHERE NOT EXISTS (
        SELECT 1 FROM bl_dm.dim_stores tgt
        WHERE  tgt.store_src_id = src.store_src_id
    );

    IF v_missing_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 4.03  CE_STORES → DIM_STORES: all keys present';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 4.03  DIM_STORES: %s key(s) missing' || chr(10), v_missing_count);
        RAISE WARNING '  [FAIL] 4.03  DIM_STORES missing % key(s)', v_missing_count;
    END IF;


    -- ============================================================
    -- TEST 4.04 — CE_CUSTOMERS_SCD → DIM_CUSTOMERS_SCD
    --   Every CUSTOMER_SRC_ID+SOURCE_SYSTEM with IS_ACTIVE='Y'
    --   in BL_3NF must have an active version in BL_DM.
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*) INTO v_missing_count
    FROM (
        SELECT customer_src_id, source_system
        FROM   bl_3nf.ce_customers_scd
        WHERE  is_active   = 'Y'
          AND  customer_id > 0
    ) src
    WHERE NOT EXISTS (
        SELECT 1 FROM bl_dm.dim_customers_scd tgt
        WHERE  tgt.customer_src_id = src.customer_src_id
          AND  tgt.source_system   = src.source_system
          AND  tgt.is_active       = 'Y'
    );

    IF v_missing_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 4.04  CE_CUSTOMERS_SCD → DIM_CUSTOMERS_SCD: all active versions present';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 4.04  DIM_CUSTOMERS_SCD: %s active version(s) missing' || chr(10), v_missing_count);
        RAISE WARNING '  [FAIL] 4.04  DIM_CUSTOMERS_SCD missing % active version(s)', v_missing_count;
    END IF;


    -- ============================================================
    -- TEST 4.05 — CE_PRODUCTS_SCD → DIM_PRODUCTS_SCD
    --   Every PRODUCT_SRC_ID+SOURCE_SYSTEM with IS_ACTIVE='Y'
    --   in BL_3NF must have an active version in BL_DM.
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*) INTO v_missing_count
    FROM (
        SELECT product_src_id, source_system
        FROM   bl_3nf.ce_products_scd
        WHERE  is_active  = 'Y'
          AND  product_id > 0
    ) src
    WHERE NOT EXISTS (
        SELECT 1 FROM bl_dm.dim_products_scd tgt
        WHERE  tgt.product_src_id = src.product_src_id
          AND  tgt.source_system  = src.source_system
          AND  tgt.is_active      = 'Y'
    );

    IF v_missing_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 4.05  CE_PRODUCTS_SCD → DIM_PRODUCTS_SCD: all active versions present';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 4.05  DIM_PRODUCTS_SCD: %s active version(s) missing' || chr(10), v_missing_count);
        RAISE WARNING '  [FAIL] 4.05  DIM_PRODUCTS_SCD missing % active version(s)', v_missing_count;
    END IF;


    -- ============================================================
    -- TEST 4.06 — CE_SALES → FCT_SALES_DD
    --   Every grain row in CE_SALES must have a corresponding
    --   row in FCT_SALES_DD.
    --   Match: LINE_SRC_ID = sale_src_id || '_' || product_src_id
    --          resolved via ce_products_scd.product_src_id
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*) INTO v_missing_count
    FROM (
        SELECT
            (s.sale_src_id || '_' || COALESCE(p.product_src_id, 'n/a')) AS line_src_id,
            s.source_system
        FROM   bl_3nf.ce_sales s
        LEFT JOIN bl_3nf.ce_products_scd p
               ON p.product_id = s.product_id
        WHERE  s.sale_id > 0
    ) src
    WHERE NOT EXISTS (
        -- from all partitions — full history.
        SELECT 1 FROM bl_dm.v_fct_sales_dd_full tgt
        WHERE  tgt.line_src_id   = src.line_src_id
          AND  tgt.source_system = src.source_system
    );

    IF v_missing_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 4.06  CE_SALES → FCT_SALES_DD: all grain rows present';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 4.06  FCT_SALES_DD: %s grain row(s) from CE_SALES missing' || chr(10), v_missing_count);
        RAISE WARNING '  [FAIL] 4.06  FCT_SALES_DD missing % grain row(s) from CE_SALES', v_missing_count;
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
        RAISE EXCEPTION E'DQ TEST GROUP 4 FAILED — % test(s) failed:\n%',
            v_tests_failed, v_failures;
    ELSE
        RAISE NOTICE '  RESULT: ALL TESTS PASSED — BL_3NF fully covered in BL_DM.';
        RAISE NOTICE '================================================================';
    END IF;

END;
$$;