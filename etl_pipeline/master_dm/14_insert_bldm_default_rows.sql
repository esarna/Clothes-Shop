-- DML - Default rows for all DIM_ tables in BL_DM

-- ============================================================
-- Default Row Convention:
--
-- Column Type                      Default Value    Notes
-- ──────────────────────────────── ──────────────── ────────────────────────────────────
-- BIGINT surrogate PK / FK         -1               Sentinel value - not a real key
-- VARCHAR / TEXT (all text cols)   'n/a'            Lowercase - project standard
-- INTEGER (numeric non-KPI)        -1               e.g. day_of_week_num, is_weekend
-- CHAR(1) / CHAR(2) / CHAR(4)      matching 'n/a'   Padded or sentinel per field width
-- IS_ACTIVE VARCHAR(1)             'Y'              Default row always "active"
-- START_DT                         DATE '1900-01-01'
-- END_DT                           DATE '9999-12-31'
-- TA_INSERT_DT                     TIMESTAMP '1900-01-01 00:00:00'
-- TA_UPDATE_DT                     TIMESTAMP '1900-01-01 00:00:00'' SCD1/SCD2: date closed;
-- SOURCE_SYSTEM                    'MANUAL'
-- SOURCE_ENTITY                    'MANUAL'
-- <Name>_SRC_ID                    'n/a'            Lowercase sentinel - not a real NK
-- KPI (DECIMAL / nullable)         NULL             Numeric - cannot store 'n/a'
-- PRODUCT_MIN_AMOUNT               NULL             KPI - nullable by design
-- ============================================================


-- ============================================================
-- GROUP 1 - SCD TYPE 0: Immutable reference tables
--           No TA_UPDATE_DT column (rows never modified).
--           SOURCE_SYSTEM = 'MANUAL', SOURCE_ENTITY = 'MANUAL'
-- ============================================================

-- ------------------------------------------------------------
-- 1.2  DIM_PAYMENT_TYPES - default row
--      PK: payment_type_surr_id = -1
--      No TA_UPDATE_DT - SCD Type 0
-- ------------------------------------------------------------

BEGIN;

INSERT INTO bl_dm.dim_payment_types (
    payment_type_surr_id,
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
    FROM   bl_dm.dim_payment_types
    WHERE  payment_type_surr_id = -1
);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM   bl_dm.dim_payment_types
        WHERE  payment_type_surr_id = -1
    ) THEN
        RAISE NOTICE '[OK] bl_dm.dim_payment_types – default row (id=-1) is present.';
    ELSE
        RAISE EXCEPTION '[FAIL] bl_dm.dim_payment_types – default row (id=-1) NOT found after INSERT.';
    END IF;
END;
$$;

COMMIT;


-- ============================================================
-- GROUP 2 - SCD TYPE 1: Overwrite-on-change dimension tables
--           TA_INSERT_DT + TA_UPDATE_DT present.
--           Both set to DATE '1900-01-01' for default row.
-- ============================================================

-- ------------------------------------------------------------
-- 2.1  DIM_EMPLOYEES - default row
--      PK: employee_surr_id = -1
--      All text columns: 'n/a'
--      TA_INSERT_DT + TA_UPDATE_DT = DATE '1900-01-01'
-- ------------------------------------------------------------

BEGIN;

INSERT INTO bl_dm.dim_employees (
    employee_surr_id,
    employee_src_id,
    employee_name,
    employee_gender,
    employee_email,
    employee_phone_number,
    employee_address,
    employee_city,
    employee_state,
    employee_postal_code,
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
    FROM   bl_dm.dim_employees
    WHERE  employee_surr_id = -1
);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM   bl_dm.dim_employees
        WHERE  employee_surr_id = -1
    ) THEN
        RAISE NOTICE '[OK] bl_dm.dim_employees     – default row (id=-1) is present.';
    ELSE
        RAISE EXCEPTION '[FAIL] bl_dm.dim_employees – default row (id=-1) NOT found after INSERT.';
    END IF;
END;
$$;

COMMIT;


-- ------------------------------------------------------------
-- 2.2  DIM_STORES - default row
--      PK: store_surr_id = -1
--      STORE_CHANNEL = 'n/a' - allowed by CHECK constraint
--        (CHECK includes 'n/a' specifically for this default row)
--      STORE_ZONE_ID = -1
--      All text columns: 'n/a'
--      TA_INSERT_DT + TA_UPDATE_DT = DATE '1900-01-01'
-- ------------------------------------------------------------

BEGIN;

INSERT INTO bl_dm.dim_stores (
    store_surr_id,
    store_src_id,
    store_channel,
    store_zone_id,
    store_zone_name,
    store_address,
    store_city,
    store_state,
    store_postal_code,
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
    FROM   bl_dm.dim_stores
    WHERE  store_surr_id = -1
);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM   bl_dm.dim_stores
        WHERE  store_surr_id = -1
    ) THEN
        RAISE NOTICE '[OK] bl_dm.dim_stores        – default row (id=-1) is present.';
    ELSE
        RAISE EXCEPTION '[FAIL] bl_dm.dim_stores – default row (id=-1) NOT found after INSERT.';
    END IF;
END;
$$;

COMMIT;


-- ============================================================
-- GROUP 3 - SCD TYPE 2: Historical dimension tables
--           Single-column PK = _SURR_ID on DM layer.
--           Default row: SURR_ID = -1
--           START_DT = DATE '1900-01-01'
--           END_DT   = DATE '9999-12-31'
--           IS_ACTIVE = 'Y'   (default row always "active")
--           TA_INSERT_DT = TA_UPDATE_DT = DATE '1900-01-01'
-- ============================================================

-- ------------------------------------------------------------
-- 3.1  DIM_CUSTOMERS_SCD - default row
--      PK: customer_surr_id = -1
--      All text columns: 'n/a'
--      SCD2 period: 1900-01-01 → 9999-12-31, IS_ACTIVE = 'Y'
--      TA_INSERT_DT + TA_UPDATE_DT = DATE '1900-01-01'
-- ------------------------------------------------------------

BEGIN;

INSERT INTO bl_dm.dim_customers_scd (
    customer_surr_id,
    customer_src_id,
    customer_name,
    customer_gender,
    customer_email,
    customer_phone_number,
    customer_address,
    customer_city,
    customer_state,
    customer_postal_code,
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
    'n/a',
    'n/a',
    'n/a',
    'n/a',
    DATE '1900-01-01',
    DATE '9999-12-31',
    'Y',
    TIMESTAMP '1900-01-01 00:00:00',
    TIMESTAMP '1900-01-01 00:00:00',
    'MANUAL',
    'MANUAL'
WHERE NOT EXISTS (
    SELECT 1
    FROM   bl_dm.dim_customers_scd
    WHERE  customer_surr_id = -1
);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM   bl_dm.dim_customers_scd
        WHERE  customer_surr_id = -1
    ) THEN
        RAISE NOTICE '[OK] bl_dm.dim_customers_scd – default row (id=-1) is present.';
    ELSE
        RAISE EXCEPTION '[FAIL] bl_dm.dim_customers_scd – default row (id=-1) NOT found after INSERT.';
    END IF;
END;
$$;

COMMIT;


-- ------------------------------------------------------------
-- 3.2  DIM_PRODUCTS_SCD - default row
--      PK: product_surr_id = -1
--      All text columns:      'n/a'
--      All numeric ID cols:   -1
--      PRODUCT_MIN_AMOUNT:    NULL  (KPI - cannot store 'n/a')
--      SCD2 period: 1900-01-01 → 9999-12-31, IS_ACTIVE = 'Y'
--      TA_INSERT_DT + TA_UPDATE_DT = DATE '1900-01-01'
-- ------------------------------------------------------------

BEGIN;

INSERT INTO bl_dm.dim_products_scd (
    product_surr_id,
    product_src_id,
    product_description,
    product_colour,
    product_size,
    product_min_amount,
    product_subcategory_id,
    product_subcategory_name,
    product_category_id,
    product_category_name,
    product_top_category_id,
    product_top_category_name,
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
    NULL,
    -1,
    'n/a',
    -1,
    'n/a',
    -1,
    'n/a',
    DATE '1900-01-01',
    DATE '9999-12-31',
    'Y',
    TIMESTAMP '1900-01-01 00:00:00',
    TIMESTAMP '1900-01-01 00:00:00',
    'MANUAL',
    'MANUAL'
WHERE NOT EXISTS (
    SELECT 1
    FROM   bl_dm.dim_products_scd
    WHERE  product_surr_id = -1
);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM   bl_dm.dim_products_scd
        WHERE  product_surr_id = -1
    ) THEN
        RAISE NOTICE '[OK] bl_dm.dim_products_scd  – default row (id=-1) is present.';
    ELSE
        RAISE EXCEPTION '[FAIL] bl_dm.dim_products_scd – default row (id=-1) NOT found after INSERT.';
    END IF;
END;
$$;

COMMIT;


-- ============================================================
-- FINAL VERIFICATION - Check all 6 default rows individually
-- ============================================================

DO $$
DECLARE
    v_total    INTEGER := 0;
    v_expected INTEGER := 5;
    v_missing  TEXT    := '';
    v_ok       BOOLEAN;
BEGIN
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'BL_DM DEFAULT ROW VERIFICATION SUMMARY';
    RAISE NOTICE '==============================================';

    -- Group 1 - SCD Type 0

    SELECT EXISTS(
        SELECT 1 FROM bl_dm.dim_payment_types
        WHERE payment_type_surr_id = -1
    ) INTO v_ok;
    IF v_ok THEN
        v_total := v_total + 1;
        RAISE NOTICE '  [OK] dim_payment_types';
    ELSE
        v_missing := v_missing || 'dim_payment_types, ';
        RAISE WARNING '  [MISSING] dim_payment_types';
    END IF;

    -- Group 2 - SCD Type 1
    SELECT EXISTS(
        SELECT 1 FROM bl_dm.dim_employees
        WHERE employee_surr_id = -1
    ) INTO v_ok;
    IF v_ok THEN
        v_total := v_total + 1;
        RAISE NOTICE '  [OK] dim_employees';
    ELSE
        v_missing := v_missing || 'dim_employees, ';
        RAISE WARNING '  [MISSING] dim_employees';
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM bl_dm.dim_stores
        WHERE store_surr_id = -1
    ) INTO v_ok;
    IF v_ok THEN
        v_total := v_total + 1;
        RAISE NOTICE '  [OK] dim_stores';
    ELSE
        v_missing := v_missing || 'dim_stores, ';
        RAISE WARNING '  [MISSING] dim_stores';
    END IF;

    -- Group 3 - SCD Type 2
    SELECT EXISTS(
        SELECT 1 FROM bl_dm.dim_customers_scd
        WHERE customer_surr_id = -1
    ) INTO v_ok;
    IF v_ok THEN
        v_total := v_total + 1;
        RAISE NOTICE '  [OK] dim_customers_scd';
    ELSE
        v_missing := v_missing || 'dim_customers_scd, ';
        RAISE WARNING '  [MISSING] dim_customers_scd';
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM bl_dm.dim_products_scd
        WHERE product_surr_id = -1
    ) INTO v_ok;
    IF v_ok THEN
        v_total := v_total + 1;
        RAISE NOTICE '  [OK] dim_products_scd';
    ELSE
        v_missing := v_missing || 'dim_products_scd, ';
        RAISE WARNING '  [MISSING] dim_products_scd';
    END IF;

    RAISE NOTICE '----------------------------------------------';
    RAISE NOTICE '  TOTAL: % / % default rows present.',
                 v_total, v_expected;

    IF v_missing <> '' THEN
        v_missing := LEFT(v_missing, LENGTH(v_missing) - 2);
        RAISE WARNING 'MISSING default rows in: [%]. Re-run inserts above.', v_missing;
    ELSE
        RAISE NOTICE '  All % default rows verified OK.', v_expected;
    END IF;

    RAISE NOTICE '==============================================';
EXCEPTION
    WHEN OTHERS THEN RAISE;
END;
$$;