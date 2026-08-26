-- ============================================================
-- DQ TEST GROUP 1 — No Duplicates in BL_3NF

DO $$
DECLARE
    -- Counters
    v_tests_run     INTEGER := 0;
    v_tests_passed  INTEGER := 0;
    v_tests_failed  INTEGER := 0;
    v_failures      TEXT    := '';

    -- Working variable
    v_dup_count     BIGINT;

BEGIN
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'DQ TEST GROUP 1 — BL_3NF: NO DUPLICATES';
    RAISE NOTICE 'Executed at: %', CURRENT_TIMESTAMP;
    RAISE NOTICE '================================================================';


    -- ============================================================
    -- TEST 1.01 — CE_STORE_ZONES
    --   NK: STORE_ZONE_SRC_ID
    --   SCD Type 0 — one row per NK, no versioning
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*)
    INTO   v_dup_count
    FROM (
        SELECT store_zone_src_id
        FROM   bl_3nf.ce_store_zones
        GROUP BY store_zone_src_id
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 1.01  ce_store_zones          — NK store_zone_src_id: no duplicates';
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-01','No duplicate NK in ce_store_zones','DQ','Uniqueness','BL_3NF','bl_3nf','ce_store_zones','N/A','Major','PASS','0',v_dup_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 1.01  ce_store_zones: %s duplicate NK(s) found in store_zone_src_id' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 1.01  ce_store_zones — % duplicate NK(s)', v_dup_count;
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-01','No duplicate NK in ce_store_zones','DQ','Uniqueness','BL_3NF','bl_3nf','ce_store_zones','N/A','Major','FAIL','0',v_dup_count::text);
    END IF;


    -- ============================================================
    -- TEST 1.02 — CE_PAYMENT_TYPES
    --   NK: PAYMENT_TYPE_SRC_ID
    --   SCD Type 0
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*)
    INTO   v_dup_count
    FROM (
        SELECT payment_type_src_id
        FROM   bl_3nf.ce_payment_types
        GROUP BY payment_type_src_id
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 1.02  ce_payment_types        — NK payment_type_src_id: no duplicates';
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-02','No duplicate NK in ce_payment_types','DQ','Uniqueness','BL_3NF','bl_3nf','ce_payment_types','N/A','Major','PASS','0',v_dup_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 1.02  ce_payment_types: %s duplicate NK(s) found' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 1.02  ce_payment_types — % duplicate NK(s)', v_dup_count;
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-02','No duplicate NK in ce_payment_types','DQ','Uniqueness','BL_3NF','bl_3nf','ce_payment_types','N/A','Major','FAIL','0',v_dup_count::text);
    END IF;


    -- ============================================================
    -- TEST 1.03 — CE_PRODUCT_TOP_CATEGORIES
    --   NK: PRODUCT_TOP_CATEGORY_SRC_ID
    --   SCD Type 1
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*)
    INTO   v_dup_count
    FROM (
        SELECT product_top_category_src_id
        FROM   bl_3nf.ce_product_top_categories
        GROUP BY product_top_category_src_id, source_system
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 1.03  ce_product_top_categories — NK: no duplicates';
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-03','No duplicate NK in ce_product_top_categories','DQ','Uniqueness','BL_3NF','bl_3nf','ce_product_top_categories','N/A','Major','PASS','0',v_dup_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 1.03  ce_product_top_categories: %s duplicate NK(s)' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 1.03  ce_product_top_categories — % duplicate NK(s)', v_dup_count;
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-03','No duplicate NK in ce_product_top_categories','DQ','Uniqueness','BL_3NF','bl_3nf','ce_product_top_categories','N/A','Major','FAIL','0',v_dup_count::text);
    END IF;


    -- ============================================================
    -- TEST 1.04 — CE_PRODUCT_CATEGORIES
    --   NK: PRODUCT_CATEGORY_SRC_ID
    --   SCD Type 1
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*)
    INTO   v_dup_count
    FROM (
        SELECT product_category_src_id
        FROM   bl_3nf.ce_product_categories
        GROUP BY product_category_src_id, source_system
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 1.04  ce_product_categories   — NK: no duplicates';
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-04','No duplicate NK in ce_product_categories','DQ','Uniqueness','BL_3NF','bl_3nf','ce_product_categories','N/A','Major','PASS','0',v_dup_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 1.04  ce_product_categories: %s duplicate NK(s)' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 1.04  ce_product_categories — % duplicate NK(s)', v_dup_count;
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-04','No duplicate NK in ce_product_categories','DQ','Uniqueness','BL_3NF','bl_3nf','ce_product_categories','N/A','Major','FAIL','0',v_dup_count::text);
    END IF;


    -- ============================================================
    -- TEST 1.05 — CE_PRODUCT_SUBCATEGORIES
    --   NK: PRODUCT_SUBCATEGORY_SRC_ID
    --   SCD Type 1
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*)
    INTO   v_dup_count
    FROM (
        SELECT product_subcategory_src_id
        FROM   bl_3nf.ce_product_subcategories
        GROUP BY product_subcategory_src_id, source_system
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 1.05  ce_product_subcategories — NK: no duplicates';
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-05','No duplicate NK in ce_product_subcategories','DQ','Uniqueness','BL_3NF','bl_3nf','ce_product_subcategories','N/A','Major','PASS','0',v_dup_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 1.05  ce_product_subcategories: %s duplicate NK(s)' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 1.05  ce_product_subcategories — % duplicate NK(s)', v_dup_count;
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-05','No duplicate NK in ce_product_subcategories','DQ','Uniqueness','BL_3NF','bl_3nf','ce_product_subcategories','N/A','Major','FAIL','0',v_dup_count::text);
    END IF;


    -- ============================================================
    -- TEST 1.06 — CE_LOCATIONS
    --   NK: LOCATION_SRC_ID
    --   SCD Type 1
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*)
    INTO   v_dup_count
    FROM (
        SELECT location_src_id
        FROM   bl_3nf.ce_locations
        GROUP BY location_src_id
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 1.06  ce_locations            — NK location_src_id: no duplicates';
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-06','No duplicate NK in ce_locations','DQ','Uniqueness','BL_3NF','bl_3nf','ce_locations','N/A','Major','PASS','0',v_dup_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 1.06  ce_locations: %s duplicate NK(s)' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 1.06  ce_locations — % duplicate NK(s)', v_dup_count;
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-06','No duplicate NK in ce_locations','DQ','Uniqueness','BL_3NF','bl_3nf','ce_locations','N/A','Major','FAIL','0',v_dup_count::text);
    END IF;


    -- ============================================================
    -- TEST 1.07 — CE_EMPLOYEES
    --   NK: EMPLOYEE_SRC_ID
    --   SCD Type 1
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*)
    INTO   v_dup_count
    FROM (
        SELECT employee_src_id
        FROM   bl_3nf.ce_employees
        GROUP BY employee_src_id
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 1.07  ce_employees            — NK employee_src_id: no duplicates';
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-07','No duplicate NK in ce_employees','DQ','Uniqueness','BL_3NF','bl_3nf','ce_employees','N/A','Major','PASS','0',v_dup_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 1.07  ce_employees: %s duplicate NK(s)' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 1.07  ce_employees — % duplicate NK(s)', v_dup_count;
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-07','No duplicate NK in ce_employees','DQ','Uniqueness','BL_3NF','bl_3nf','ce_employees','N/A','Major','FAIL','0',v_dup_count::text);
    END IF;


    -- ============================================================
    -- TEST 1.08 — CE_STORES
    --   NK: STORE_SRC_ID
    --   SCD Type 1
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*)
    INTO   v_dup_count
    FROM (
        SELECT store_src_id
        FROM   bl_3nf.ce_stores
        GROUP BY store_src_id
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 1.08  ce_stores               — NK store_src_id: no duplicates';
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-08','No duplicate NK in ce_stores','DQ','Uniqueness','BL_3NF','bl_3nf','ce_stores','N/A','Major','PASS','0',v_dup_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 1.08  ce_stores: %s duplicate NK(s)' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 1.08  ce_stores — % duplicate NK(s)', v_dup_count;
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-08','No duplicate NK in ce_stores','DQ','Uniqueness','BL_3NF','bl_3nf','ce_stores','N/A','Major','FAIL','0',v_dup_count::text);
    END IF;


    -- ============================================================
    -- TEST 1.09 — CE_CUSTOMERS_SCD
    --   Composite PK: (CUSTOMER_ID + START_DT)
    --   Test A: no duplicate composite PK rows
    --   Test B: no more than one IS_ACTIVE='Y' per NK
    --   SCD Type 2
    -- ============================================================

    -- Test A: composite PK uniqueness
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*)
    INTO   v_dup_count
    FROM (
        SELECT customer_id, start_dt
        FROM   bl_3nf.ce_customers_scd
        GROUP BY customer_id, start_dt
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 1.09a ce_customers_scd        — composite PK (customer_id+start_dt): no duplicates';
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-09A','Composite PK uniqueness in ce_customers_scd','DQ','Uniqueness','BL_3NF','bl_3nf','ce_customers_scd','N/A','Critical','PASS','0',v_dup_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 1.09a ce_customers_scd: %s duplicate composite PK(s)' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 1.09a ce_customers_scd composite PK — % duplicate(s)', v_dup_count;
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-09A','Composite PK uniqueness in ce_customers_scd','DQ','Uniqueness','BL_3NF','bl_3nf','ce_customers_scd','N/A','Critical','FAIL','0',v_dup_count::text);
    END IF;

    -- Test B: max one active version per NK
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*)
    INTO   v_dup_count
    FROM (
        SELECT customer_src_id
        FROM   bl_3nf.ce_customers_scd
        WHERE  is_active = 'Y'
          AND  customer_id > 0      -- exclude default row
        GROUP BY customer_src_id
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 1.09b ce_customers_scd        — IS_ACTIVE=Y uniqueness per NK: OK';
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-09B','Single active SCD2 version per NK in ce_customers_scd','DQ','Uniqueness','BL_3NF','bl_3nf','ce_customers_scd','N/A','Critical','PASS','0',v_dup_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 1.09b ce_customers_scd: %s NK(s) with more than one IS_ACTIVE=Y row' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 1.09b ce_customers_scd — % NK(s) with multiple active rows', v_dup_count;
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-09B','Single active SCD2 version per NK in ce_customers_scd','DQ','Uniqueness','BL_3NF','bl_3nf','ce_customers_scd','N/A','Critical','FAIL','0',v_dup_count::text);
    END IF;


    -- ============================================================
    -- TEST 1.10 — CE_PRODUCTS_SCD
    --   Composite PK: (PRODUCT_ID + START_DT)
    --   Test A: no duplicate composite PK rows
    --   Test B: no more than one IS_ACTIVE='Y' per NK
    --   SCD Type 2
    -- ============================================================

    -- Test A
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*)
    INTO   v_dup_count
    FROM (
        SELECT product_id, start_dt
        FROM   bl_3nf.ce_products_scd
        GROUP BY product_id, start_dt
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 1.10a ce_products_scd         — composite PK (product_id+start_dt): no duplicates';
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-10A','Composite PK uniqueness in ce_products_scd','DQ','Uniqueness','BL_3NF','bl_3nf','ce_products_scd','N/A','Critical','PASS','0',v_dup_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 1.10a ce_products_scd: %s duplicate composite PK(s)' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 1.10a ce_products_scd composite PK — % duplicate(s)', v_dup_count;
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-10A','Composite PK uniqueness in ce_products_scd','DQ','Uniqueness','BL_3NF','bl_3nf','ce_products_scd','N/A','Critical','FAIL','0',v_dup_count::text);
    END IF;

    -- Test B
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*)
    INTO   v_dup_count
    FROM (
        SELECT product_src_id
        FROM   bl_3nf.ce_products_scd
        WHERE  is_active = 'Y'
          AND  product_id > 0
        GROUP BY product_src_id
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 1.10b ce_products_scd         — IS_ACTIVE=Y uniqueness per NK: OK';
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-10B','Single active SCD2 version per NK in ce_products_scd','DQ','Uniqueness','BL_3NF','bl_3nf','ce_products_scd','N/A','Critical','PASS','0',v_dup_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 1.10b ce_products_scd: %s NK(s) with more than one IS_ACTIVE=Y row' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 1.10b ce_products_scd — % NK(s) with multiple active rows', v_dup_count;
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-10B','Single active SCD2 version per NK in ce_products_scd','DQ','Uniqueness','BL_3NF','bl_3nf','ce_products_scd','N/A','Critical','FAIL','0',v_dup_count::text);
    END IF;


    -- ============================================================
    -- TEST 1.11 — CE_SALES
    --   Grain NK: (SALE_SRC_ID + SOURCE_SYSTEM + PRODUCT_ID)
    --   per UNIQUE constraint uq_ce_sales_src
    --   Fact table — append-only, no SCD
    -- ============================================================
    v_tests_run := v_tests_run + 1;

    SELECT COUNT(*)
    INTO   v_dup_count
    FROM (
        SELECT sale_src_id, source_system, product_id
        FROM   bl_3nf.ce_sales
        GROUP BY sale_src_id, source_system, product_id
        HAVING COUNT(*) > 1
    ) dups;

    IF v_dup_count = 0 THEN
        v_tests_passed := v_tests_passed + 1;
        RAISE NOTICE '  [PASS] 1.11  ce_sales                — grain NK (sale_src_id+source_system+product_id): no duplicates';
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-11','Fact grain uniqueness in ce_sales','DQ','Uniqueness','BL_3NF','bl_3nf','ce_sales','BOTH','Critical','PASS','0',v_dup_count::text);
    ELSE
        v_tests_failed := v_tests_failed + 1;
        v_failures := v_failures ||
            format('  [FAIL] 1.11  ce_sales: %s duplicate grain NK(s)' || chr(10), v_dup_count);
        RAISE WARNING '  [FAIL] 1.11  ce_sales — % duplicate grain NK(s)', v_dup_count;
        CALL bl_cl.prc_log_test_result('TC-DQ-UNIQ-3NF-11','Fact grain uniqueness in ce_sales','DQ','Uniqueness','BL_3NF','bl_3nf','ce_sales','BOTH','Critical','FAIL','0',v_dup_count::text);
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
        RAISE EXCEPTION E'DQ TEST GROUP 1 FAILED — % test(s) failed:\n%',
            v_tests_failed, v_failures;
    ELSE
        RAISE NOTICE '  RESULT: ALL TESTS PASSED — BL_3NF contains no duplicates.';
        RAISE NOTICE '================================================================';
    END IF;

END;
$$;