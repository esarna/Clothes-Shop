-- DML - Default rows for all dimension/reference tables (NOT for CE_SALES fact)

-- Default Row presentation and naming convention:
-- Column Type                     Default Value   Notes
-- ─────────────────────────────── ─────────────── ──────────────────────────────────
-- BIGINT / SMALLINT / numeric PK  -1              Includes SMALLINT date fields
-- Text / VARCHAR                  'n/a'           Lowercase - project standard
-- IS_ACTIVE (VARCHAR(1))          'Y'             Default row is always "active"
-- START_DT                        '1900-01-01'
-- END_DT                          '9999-12-31'
-- TA_INSERT_DT, TA_UPDATE_DT      '1900-01-01'    SCD2 ta_update_dt = date closed
-- SOURCE_SYSTEM, SOURCE_ENTITY    'MANUAL'
-- <Name>_src_id                   'n/a'           Lowercase sentinel, not a NK
-- KPI (DECIMAL, nullable)         NULL            Cannot store n/a in numeric
--

-- Tables requiring default rows (with NOT EXISTS guard + COMMIT):
-- CE_PAYMENT_TYPES - default row (PAYMENT_TYPE_ID = -1)
-- CE_STORE_ZONES - default row (STORE_ZONE_ID = -1)
-- CE_PRODUCT_TOP_CATEGORIES - default row (PRODUCT_TOP_CATEGORY_ID = -1)
-- CE_PRODUCT_CATEGORIES - default row (PRODUCT_CATEGORY_ID = -1, PRODUCT_TOP_CATEGORY_ID = -1)
-- CE_PRODUCT_SUBCATEGORIES - default row (PRODUCT_SUBCATEGORY_ID = -1, PRODUCT_CATEGORY_ID = -1)
-- CE_LOCATIONS - default row (LOCATION_ID = -1)
-- CE_STORES - default row (STORE_ID = -1, STORE_ZONE_ID = -1, STORE_LOCATION_ID = -1)
-- CE_EMPLOYEES - default row (EMPLOYEE_ID = -1, EMPLOYEE_LOCATION_ID = -1)
-- CE_CUSTOMERS_SCD - default row (CUSTOMER_ID = -1, CUSTOMER_LOCATION_ID = -1)
-- CE_PRODUCTS_SCD - default row (PRODUCT_ID = -1, PRODUCT_SUBCATEGORY_ID = -1)
--
-- ============================================================


-- ============================================================
-- GROUP 1 - SCD TYPE 0: Immutable reference tables
--           No TA_UPDATE_DT column (rows never modified).
--           SOURCE_SYSTEM = 'MANUAL', SOURCE_ENTITY = 'MANUAL'
-- ============================================================

-- ------------------------------------------------------------
-- 1.2  CE_STORE_ZONES - default row
--      PK: store_zone_id = -1
--      No TA_UPDATE_DT: SCD Type 0
--      CASE NOTE: store_zone_src_id = 'n/a' (lowercase).
-- ------------------------------------------------------------
BEGIN;

INSERT INTO bl_3nf.ce_store_zones (
    store_zone_id,
    store_zone_src_id,
    store_zone_name,
    ta_insert_dt,
    source_system,
    source_entity
)
SELECT
    -1,
    'n/a',
    'n/a',
    TIMESTAMP '1900-01-01 00:00:00',
    'MANUAL',
    'MANUAL'
WHERE NOT EXISTS (
    SELECT 1
    FROM   bl_3nf.ce_store_zones
    WHERE  store_zone_id = -1
);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM bl_3nf.ce_store_zones WHERE store_zone_id = -1) THEN
        RAISE NOTICE '[OK] bl_3nf.ce_store_zones     – default row (id=-1) is present.';
    ELSE
        RAISE EXCEPTION '[FAIL] bl_3nf.ce_store_zones – default row (id=-1) NOT found after INSERT.';
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- 1.3  CE_PAYMENT_TYPES - default row
--      PK: payment_type_id = -1
--      No TA_UPDATE_DT: SCD Type 0
--      CASE NOTE: payment_type_src_id = 'n/a' (lowercase).
-- ------------------------------------------------------------
INSERT INTO bl_3nf.ce_payment_types (
    payment_type_id,
    payment_type_src_id,
    payment_type_name,
    ta_insert_dt,
    source_system,
    source_entity
)
SELECT
    -1,
    'n/a',
    'n/a',
    TIMESTAMP '1900-01-01 00:00:00',
    'MANUAL',
    'MANUAL'
WHERE NOT EXISTS (
    SELECT 1
    FROM   bl_3nf.ce_payment_types
    WHERE  payment_type_id = -1
);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM bl_3nf.ce_payment_types WHERE payment_type_id = -1) THEN
        RAISE NOTICE '[OK] bl_3nf.ce_payment_types   – default row (id=-1) is present.';
    ELSE
        RAISE EXCEPTION '[FAIL] bl_3nf.ce_payment_types – default row (id=-1) NOT found after INSERT.';
    END IF;
END;
$$;

COMMIT;


-- ============================================================
-- GROUP 2 - SCD TYPE 1: Product category hierarchy
--           Inserted top-down: parent -1 row before child -1 row
--           to satisfy FK constraints.
--           All have TA_INSERT_DT + TA_UPDATE_DT.
-- ============================================================

-- ------------------------------------------------------------
-- 2.1  CE_PRODUCT_TOP_CATEGORIES - default row
--      PK: product_top_category_id = -1
--      No parent FK (top of hierarchy)
-- ------------------------------------------------------------

BEGIN;

INSERT INTO bl_3nf.ce_product_top_categories (
    product_top_category_id,
    product_top_category_src_id,
    product_top_category_name,
    ta_insert_dt,
    ta_update_dt,
    source_system,
    source_entity
)
SELECT
    -1,
    'n/a',
    'n/a',
    TIMESTAMP '1900-01-01 00:00:00',
    TIMESTAMP '1900-01-01 00:00:00',
    'MANUAL',
    'MANUAL'
WHERE NOT EXISTS (
    SELECT 1
    FROM   bl_3nf.ce_product_top_categories
    WHERE  product_top_category_id = -1
);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM bl_3nf.ce_product_top_categories WHERE product_top_category_id = -1) THEN
        RAISE NOTICE '[OK] bl_3nf.ce_product_top_categories – default row (id=-1) is present.';
    ELSE
        RAISE EXCEPTION '[FAIL] bl_3nf.ce_product_top_categories – default row (id=-1) NOT found after INSERT.';
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- 2.2  CE_PRODUCT_CATEGORIES - default row
--      PK: product_category_id = -1
--      FK: product_top_category_id = -1  ← parent default row
--          already inserted in step 2.1
-- ------------------------------------------------------------
INSERT INTO bl_3nf.ce_product_categories (
    product_category_id,
    product_category_src_id,
    product_category_name,
    product_top_category_id,
    ta_insert_dt,
    ta_update_dt,
    source_system,
    source_entity
)
SELECT
    -1,
    'n/a',
    'n/a',
    -1,
    TIMESTAMP '1900-01-01 00:00:00',
    TIMESTAMP '1900-01-01 00:00:00',
    'MANUAL',
    'MANUAL'
WHERE NOT EXISTS (
    SELECT 1
    FROM   bl_3nf.ce_product_categories
    WHERE  product_category_id = -1
);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM bl_3nf.ce_product_categories WHERE product_category_id = -1) THEN
        RAISE NOTICE '[OK] bl_3nf.ce_product_categories    – default row (id=-1) is present.';
    ELSE
        RAISE EXCEPTION '[FAIL] bl_3nf.ce_product_categories – default row (id=-1) NOT found after INSERT.';
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- 2.3  CE_PRODUCT_SUBCATEGORIES - default row
--      PK: product_subcategory_id = -1
--      FK: product_category_id = -1  ← parent default row
--          already inserted in step 2.2
-- ------------------------------------------------------------
INSERT INTO bl_3nf.ce_product_subcategories (
    product_subcategory_id,
    product_subcategory_src_id,
    product_subcategory_name,
    product_category_id,
    ta_insert_dt,
    ta_update_dt,
    source_system,
    source_entity
)
SELECT
    -1,
    'n/a',
    'n/a',
    -1,
    TIMESTAMP '1900-01-01 00:00:00',
    TIMESTAMP '1900-01-01 00:00:00',
    'MANUAL',
    'MANUAL'
WHERE NOT EXISTS (
    SELECT 1
    FROM   bl_3nf.ce_product_subcategories
    WHERE  product_subcategory_id = -1
);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM bl_3nf.ce_product_subcategories WHERE product_subcategory_id = -1) THEN
        RAISE NOTICE '[OK] bl_3nf.ce_product_subcategories – default row (id=-1) is present.';
    ELSE
        RAISE EXCEPTION '[FAIL] bl_3nf.ce_product_subcategories – default row (id=-1) NOT found after INSERT.';
    END IF;
END;
$$;

COMMIT;


-- ============================================================
-- GROUP 3 - SCD TYPE 1: Address and store chain
--           CE_LOCATIONS inserted first (CE_EMPLOYEES and
--           CE_STORES both reference it via FK).
-- ============================================================

-- ------------------------------------------------------------
-- 3.1  CE_LOCATIONS - default row
--      PK: location_id = -1
--      No parent FK
-- ------------------------------------------------------------

BEGIN;

INSERT INTO bl_3nf.ce_locations (
    location_id,
    location_src_id,
    location_address,
    location_postal_code,
    location_city,
    location_state,
    ta_insert_dt,
    ta_update_dt,
    source_system,
    source_entity
)
SELECT
    -1,
    'n/a',
    'n/a',
    'n/a',
    'n/a',
    'n/a',
    TIMESTAMP '1900-01-01 00:00:00',
    TIMESTAMP '1900-01-01 00:00:00',
    'MANUAL',
    'MANUAL'
WHERE NOT EXISTS (
    SELECT 1
    FROM   bl_3nf.ce_locations
    WHERE  location_id = -1
);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM bl_3nf.ce_locations WHERE location_id = -1) THEN
        RAISE NOTICE '[OK] bl_3nf.ce_locations         – default row (id=-1) is present.';
    ELSE
        RAISE EXCEPTION '[FAIL] bl_3nf.ce_locations – default row (id=-1) NOT found after INSERT.';
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- 3.2  CE_EMPLOYEES - default row
--      PK: employee_id = -1
--      FK: employee_location_id = -1  ← default row step 3.1
-- ------------------------------------------------------------
INSERT INTO bl_3nf.ce_employees (
    employee_id,
    employee_src_id,
    employee_name,
    employee_gender,
    employee_email,
    employee_phone_number,
    employee_location_id,
    ta_insert_dt,
    ta_update_dt,
    source_system,
    source_entity
)
SELECT
    -1,
    'n/a',
    'n/a',
    'n/a',
    'n/a',
    'n/a',
    -1,
    TIMESTAMP '1900-01-01 00:00:00',
    TIMESTAMP '1900-01-01 00:00:00',
    'MANUAL',
    'MANUAL'
WHERE NOT EXISTS (
    SELECT 1
    FROM   bl_3nf.ce_employees
    WHERE  employee_id = -1
);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM bl_3nf.ce_employees WHERE employee_id = -1) THEN
        RAISE NOTICE '[OK] bl_3nf.ce_employees         – default row (id=-1) is present.';
    ELSE
        RAISE EXCEPTION '[FAIL] bl_3nf.ce_employees – default row (id=-1) NOT found after INSERT.';
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- 3.3  CE_STORES - default row
--      PK: store_id = -1
--      FK: store_zone_id     = -1  ← default row step 1.2
--          store_location_id = -1  ← default row step 3.1
-- ------------------------------------------------------------

INSERT INTO bl_3nf.ce_stores (
    store_id,
    store_src_id,
    store_channel,
    store_zone_id,
    store_location_id,
    ta_insert_dt,
    ta_update_dt,
    source_system,
    source_entity
)
SELECT
    -1,
    'n/a',
    'n/a',
    -1,
    -1,
    TIMESTAMP '1900-01-01 00:00:00',
    TIMESTAMP '1900-01-01 00:00:00',
    'MANUAL',
    'MANUAL'
WHERE NOT EXISTS (
    SELECT 1
    FROM   bl_3nf.ce_stores
    WHERE  store_id = -1
);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM bl_3nf.ce_stores WHERE store_id = -1) THEN
        RAISE NOTICE '[OK] bl_3nf.ce_stores            – default row (id=-1) is present.';
    ELSE
        RAISE EXCEPTION '[FAIL] bl_3nf.ce_stores – default row (id=-1) NOT found after INSERT.';
    END IF;
END;
$$;

COMMIT;


-- ============================================================
-- GROUP 4 - SCD TYPE 2: Historical dimension tables
--           Composite PK = (_ID + START_DT).
--           Default row: surrogate key = -1, start_dt = 1900-01-01
--           end_dt = 9999-12-31, is_active = 'Y'
--           No TA_UPDATE_DT (SCD2 – new row inserted on change).
--           FK columns in default rows set to -1.
-- ============================================================

-- ------------------------------------------------------------
-- 4.1  CE_CUSTOMERS_SCD - default row
--      PK (composite): customer_id = -1, start_dt = '1900-01-01'
--      FK: customer_location_id = -1  (logical FK, no DB constraint)
-- ------------------------------------------------------------

BEGIN;

INSERT INTO bl_3nf.ce_customers_scd (
    customer_id,
    customer_src_id,
    customer_name,
    customer_gender,
    customer_email,
    customer_phone_number,
    customer_location_id,
    start_dt,
    end_dt,
    is_active,
    ta_insert_dt,
    ta_update_dt,
    source_system,
    source_entity
)
SELECT
    -1,
    'n/a',
    'n/a',
    'n/a',
    'n/a',
    'n/a',
    -1,
    DATE '1900-01-01',
    DATE '9999-12-31',
    'Y',
    TIMESTAMP '1900-01-01 00:00:00',
    TIMESTAMP '1900-01-01 00:00:00',
    'MANUAL',
    'MANUAL'
WHERE NOT EXISTS (
    SELECT 1
    FROM   bl_3nf.ce_customers_scd
    WHERE  customer_id = -1
      AND  start_dt    = DATE '1900-01-01'
);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM   bl_3nf.ce_customers_scd
        WHERE  customer_id = -1
          AND  start_dt    = DATE '1900-01-01'
    ) THEN
        RAISE NOTICE '[OK] bl_3nf.ce_customers_scd     – default row (id=-1, start_dt=1900-01-01) is present.';
    ELSE
        RAISE EXCEPTION '[FAIL] bl_3nf.ce_customers_scd – default row NOT found after INSERT.';
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- 4.2  CE_PRODUCTS_SCD - default row
--      PK (composite): product_id = -1, start_dt = '1900-01-01'
--      FK: product_subcategory_id = -1  ← default row step 2.3
--      product_min_amount = NULL
--      product_colour / product_size / product_description = 'n/a'
-- ------------------------------------------------------------
INSERT INTO bl_3nf.ce_products_scd (
    product_id,
    product_src_id,
    product_subcategory_id,
    product_description,
    product_colour,
    product_size,
    product_min_amount,
    start_dt,
    end_dt,
    is_active,
    ta_insert_dt,
    ta_update_dt,
    source_system,
    source_entity
)
SELECT
    -1,
    'n/a',
    -1,
    'n/a',
    'n/a',
    'n/a',
    NULL,
    DATE '1900-01-01',
    DATE '9999-12-31',
    'Y',
    TIMESTAMP '1900-01-01 00:00:00',
    TIMESTAMP '1900-01-01 00:00:00',
    'MANUAL',
    'MANUAL'
WHERE NOT EXISTS (
    SELECT 1
    FROM   bl_3nf.ce_products_scd
    WHERE  product_id = -1
      AND  start_dt   = DATE '1900-01-01'
);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM   bl_3nf.ce_products_scd
        WHERE  product_id = -1
          AND  start_dt   = DATE '1900-01-01'
    ) THEN
        RAISE NOTICE '[OK] bl_3nf.ce_products_scd      – default row (id=-1, start_dt=1900-01-01) is present.';
    ELSE
        RAISE EXCEPTION '[FAIL] bl_3nf.ce_products_scd – default row NOT found after INSERT.';
    END IF;
END;
$$;

COMMIT;


-- ============================================================
-- FINAL VERIFICATION - Check each default row individually
-- ============================================================

DO $$
DECLARE
    v_total    INTEGER := 0;
    v_expected INTEGER := 10;
    v_missing  TEXT    := '';
    v_ok       BOOLEAN;
BEGIN
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'BL_3NF DEFAULT ROW VERIFICATION SUMMARY';
    RAISE NOTICE '==============================================';

    -- SCD Type 0
    SELECT EXISTS(SELECT 1 FROM bl_3nf.ce_store_zones WHERE store_zone_id = -1)
        INTO v_ok;
    IF v_ok THEN v_total := v_total + 1; RAISE NOTICE '  [OK] ce_store_zones';
    ELSE v_missing := v_missing || 'ce_store_zones, '; RAISE WARNING '  [MISSING] ce_store_zones'; END IF;

    SELECT EXISTS(SELECT 1 FROM bl_3nf.ce_payment_types WHERE payment_type_id = -1)
        INTO v_ok;
    IF v_ok THEN v_total := v_total + 1; RAISE NOTICE '  [OK] ce_payment_types';
    ELSE v_missing := v_missing || 'ce_payment_types, '; RAISE WARNING '  [MISSING] ce_payment_types'; END IF;

    -- SCD Type 1 – product hierarchy
    SELECT EXISTS(SELECT 1 FROM bl_3nf.ce_product_top_categories WHERE product_top_category_id = -1)
        INTO v_ok;
    IF v_ok THEN v_total := v_total + 1; RAISE NOTICE '  [OK] ce_product_top_categories';
    ELSE v_missing := v_missing || 'ce_product_top_categories, '; RAISE WARNING '  [MISSING] ce_product_top_categories'; END IF;

    SELECT EXISTS(SELECT 1 FROM bl_3nf.ce_product_categories WHERE product_category_id = -1)
        INTO v_ok;
    IF v_ok THEN v_total := v_total + 1; RAISE NOTICE '  [OK] ce_product_categories';
    ELSE v_missing := v_missing || 'ce_product_categories, '; RAISE WARNING '  [MISSING] ce_product_categories'; END IF;

    SELECT EXISTS(SELECT 1 FROM bl_3nf.ce_product_subcategories WHERE product_subcategory_id = -1)
        INTO v_ok;
    IF v_ok THEN v_total := v_total + 1; RAISE NOTICE '  [OK] ce_product_subcategories';
    ELSE v_missing := v_missing || 'ce_product_subcategories, '; RAISE WARNING '  [MISSING] ce_product_subcategories'; END IF;

    -- SCD Type 1 – address + store chain
    SELECT EXISTS(SELECT 1 FROM bl_3nf.ce_locations WHERE location_id = -1)
        INTO v_ok;
    IF v_ok THEN v_total := v_total + 1; RAISE NOTICE '  [OK] ce_locations';
    ELSE v_missing := v_missing || 'ce_locations, '; RAISE WARNING '  [MISSING] ce_locations'; END IF;

    SELECT EXISTS(SELECT 1 FROM bl_3nf.ce_employees WHERE employee_id = -1)
        INTO v_ok;
    IF v_ok THEN v_total := v_total + 1; RAISE NOTICE '  [OK] ce_employees';
    ELSE v_missing := v_missing || 'ce_employees, '; RAISE WARNING '  [MISSING] ce_employees'; END IF;

    SELECT EXISTS(SELECT 1 FROM bl_3nf.ce_stores WHERE store_id = -1)
        INTO v_ok;
    IF v_ok THEN v_total := v_total + 1; RAISE NOTICE '  [OK] ce_stores';
    ELSE v_missing := v_missing || 'ce_stores, '; RAISE WARNING '  [MISSING] ce_stores'; END IF;

    -- SCD Type 2 (composite PK)
    SELECT EXISTS(
        SELECT 1 FROM bl_3nf.ce_customers_scd
        WHERE customer_id = -1 AND start_dt = DATE '1900-01-01'
    ) INTO v_ok;
    IF v_ok THEN v_total := v_total + 1; RAISE NOTICE '  [OK] ce_customers_scd';
    ELSE v_missing := v_missing || 'ce_customers_scd, '; RAISE WARNING '  [MISSING] ce_customers_scd'; END IF;

    SELECT EXISTS(
        SELECT 1 FROM bl_3nf.ce_products_scd
        WHERE product_id = -1 AND start_dt = DATE '1900-01-01'
    ) INTO v_ok;
    IF v_ok THEN v_total := v_total + 1; RAISE NOTICE '  [OK] ce_products_scd';
    ELSE v_missing := v_missing || 'ce_products_scd, '; RAISE WARNING '  [MISSING] ce_products_scd'; END IF;

    RAISE NOTICE '----------------------------------------------';
    RAISE NOTICE '  TOTAL: % / % default rows present', v_total, v_expected;

    IF v_missing <> '' THEN
        v_missing := LEFT(v_missing, LENGTH(v_missing) - 2);
        RAISE WARNING 'MISSING default rows in: [%]', v_missing;
    ELSE
        RAISE NOTICE '  All % default rows verified OK.', v_expected;
    END IF;

    RAISE NOTICE '==============================================';
EXCEPTION
    WHEN OTHERS THEN RAISE;
END;
$$;