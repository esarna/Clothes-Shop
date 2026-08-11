-- ============================================================
-- DQ TEST GROUP 3 — No Duplicates in BL_DM

DO $$
DECLARE
    v_tests_run     INTEGER := 0;
    v_tests_passed  INTEGER := 0;
    v_tests_failed  INTEGER := 0;
    v_failures      TEXT    := '';
    v_dup_count     BIGINT;
BEGIN
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'DQ TEST GROUP 3 — BL_DM: NO DUPLICATES';
    RAISE NOTICE 'Executed at: %', CURRENT_TIMESTAMP;
    RAISE NOTICE '================================================================';


    -- ============================================================
    -- TEST 3.01 — DIM_PAYMENT_TYPES
    --   NK: PAYMENT_TYPE_SRC_ID
    --   SCD Type 0 — one row per NK
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*) INTO v_dup_count
    FROM (
        SELECT payment_type_src_id
        FROM   bl_dm.dim_payment_types
        GROUP BY payment_type_src_id
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 3.01  dim_payment_types    — NK payment_type_src_id: no duplicates';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 3.01  dim_payment_types: %s duplicate NK(s)' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 3.01  dim_payment_types — % duplicate NK(s)', v_dup_count;
    END IF;


    -- ============================================================
    -- TEST 3.02 — DIM_EMPLOYEES
    --   NK: EMPLOYEE_SRC_ID + SOURCE_SYSTEM
    --   SCD Type 1
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*) INTO v_dup_count
    FROM (
        SELECT employee_src_id, source_system
        FROM   bl_dm.dim_employees
        GROUP BY employee_src_id, source_system
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 3.02  dim_employees       — NK (employee_src_id+source_system): no duplicates';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 3.02  dim_employees: %s duplicate NK(s)' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 3.02  dim_employees — % duplicate NK(s)', v_dup_count;
    END IF;


    -- ============================================================
    -- TEST 3.03 — DIM_STORES
    --   NK: STORE_SRC_ID
    --   SCD Type 1
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*) INTO v_dup_count
    FROM (
        SELECT store_src_id
        FROM   bl_dm.dim_stores
        GROUP BY store_src_id
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 3.03  dim_stores          — NK store_src_id: no duplicates';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 3.03  dim_stores: %s duplicate NK(s)' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 3.03  dim_stores — % duplicate NK(s)', v_dup_count;
    END IF;


    -- ============================================================
    -- TEST 3.04 — DIM_CUSTOMERS_SCD
    --   Test A: no more than one IS_ACTIVE='Y' per NK+source_system
    --   Test B: SURR_ID uniqueness (PK — sanity check)
    --   SCD Type 2
    -- ============================================================

    -- Test A: active version uniqueness per NK
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*) INTO v_dup_count
    FROM (
        SELECT customer_src_id, source_system
        FROM   bl_dm.dim_customers_scd
        WHERE  is_active = 'Y'
          AND  customer_surr_id > 0
        GROUP BY customer_src_id, source_system
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 3.04a dim_customers_scd   — IS_ACTIVE=Y uniqueness per NK: OK';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 3.04a dim_customers_scd: %s NK(s) with >1 active row' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 3.04a dim_customers_scd — % NK(s) with multiple active rows', v_dup_count;
    END IF;

    -- Test B: SURR_ID is unique (PK sanity)
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*) INTO v_dup_count
    FROM (
        SELECT customer_surr_id
        FROM   bl_dm.dim_customers_scd
        GROUP BY customer_surr_id
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 3.04b dim_customers_scd   — SURR_ID uniqueness: OK';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 3.04b dim_customers_scd: %s duplicate SURR_ID(s)' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 3.04b dim_customers_scd — % duplicate SURR_ID(s)', v_dup_count;
    END IF;


    -- ============================================================
    -- TEST 3.05 — DIM_PRODUCTS_SCD
    --   Test A: no more than one IS_ACTIVE='Y' per NK+source_system
    --   Test B: SURR_ID uniqueness (PK — sanity check)
    --   SCD Type 2
    -- ============================================================

    -- Test A
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*) INTO v_dup_count
    FROM (
        SELECT product_src_id, source_system
        FROM   bl_dm.dim_products_scd
        WHERE  is_active = 'Y'
          AND  product_surr_id > 0
        GROUP BY product_src_id, source_system
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 3.05a dim_products_scd    — IS_ACTIVE=Y uniqueness per NK: OK';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 3.05a dim_products_scd: %s NK(s) with >1 active row' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 3.05a dim_products_scd — % NK(s) with multiple active rows', v_dup_count;
    END IF;

    -- Test B
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*) INTO v_dup_count
    FROM (
        SELECT product_surr_id
        FROM   bl_dm.dim_products_scd
        GROUP BY product_surr_id
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 3.05b dim_products_scd    — SURR_ID uniqueness: OK';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 3.05b dim_products_scd: %s duplicate SURR_ID(s)' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 3.05b dim_products_scd — % duplicate SURR_ID(s)', v_dup_count;
    END IF;


    -- ============================================================
    -- TEST 3.06 — FCT_SALES_DD
    --   Grain NK: (LINE_SRC_ID + SOURCE_SYSTEM + EVENT_DT)
    --   per UNIQUE constraint uq_fct_sales_dd_grain
    --   Fact table — append-only, partitioned
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*) INTO v_dup_count
    FROM (
        SELECT line_src_id, source_system, event_dt
        FROM   bl_dm.fct_sales_dd
        GROUP BY line_src_id, source_system, event_dt
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 3.06  fct_sales_dd        — grain NK (line_src_id+source_system+event_dt): no duplicates';
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 3.06  fct_sales_dd: %s duplicate grain NK(s)' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 3.06  fct_sales_dd — % duplicate grain NK(s)', v_dup_count;
    END IF;


    -- ============================================================
    -- TEST 3.07 — FCT_SALES_DD partition existence check
    --   Verifies that at least one partition exists on the
    --   partitioned FCT_SALES_DD table (partition attach worked).
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*) INTO v_dup_count
    FROM   pg_inherits     i
    JOIN   pg_class        c ON c.oid = i.inhrelid
    JOIN   pg_namespace    n ON n.oid = c.relnamespace
    JOIN   pg_class        p ON p.oid = i.inhparent
    WHERE  n.nspname = 'bl_dm'
      AND  p.relname = 'fct_sales_dd';

    IF v_dup_count > 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 3.07  fct_sales_dd        — % partition(s) attached', v_dup_count;
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            '  [FAIL] 3.07  fct_sales_dd: no partitions found — ATTACH PARTITION may have failed' || chr(10);
        RAISE WARNING '  [FAIL] 3.07  fct_sales_dd — no partitions attached';
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
        RAISE EXCEPTION E'DQ TEST GROUP 3 FAILED — % test(s) failed:\n%',
            v_tests_failed, v_failures;
    ELSE
        RAISE NOTICE '  RESULT: ALL TESTS PASSED — BL_DM contains no duplicates.';
        RAISE NOTICE '================================================================';
    END IF;

END;
$$;