-- DDL — Sequences (one per table, per naming convention)

-- SEQ_CE_DATES_ID
-- SEQ_CE_PAYMENT_TYPES_ID
-- SEQ_CE_STORE_ZONES_ID
-- SEQ_CE_PRODUCT_TOP_CATEGORIES_ID
-- SEQ_CE_PRODUCT_CATEGORIES_ID
-- SEQ_CE_PRODUCT_SUBCATEGORIES_ID
-- SEQ_CE_LOCATIONS_ID
-- SEQ_CE_STORES_ID
-- SEQ_CE_EMPLOYEES_ID
-- SEQ_CE_CUSTOMERS_SCD_ID
-- SEQ_CE_PRODUCTS_SCD_ID
-- SEQ_CE_SALES_ID
-- ⚠️ Convention: USE SEQUENCES ONLY — no SERIAL type (per Naming Conventions doc).

-- ============================================================
-- FILE:    07_create_bl3nf_sequences.sql
-- LAYER:   BL_3NF (Business Layer – Third Normal Form)
-- PURPOSE: Create all surrogate key sequences for BL_3NF CE_
--          tables. One dedicated sequence per table.
--
-- EXECUTION ORDER IN PIPELINE:
--   01_create_schemas.sql             ← SA schemas
--   02_setup_file_fdw.sql             ← file_fdw extension + server
--   03_create_ext_tables.sql          ← EXT_ foreign tables
--   04_create_src_tables.sql          ← SRC_ staging tables
--   05_load_src_tables.sql            ← SA layer incremental load
--   06_create_bl3nf_schema.sql        ← BL_3NF schema
--   >>> 07_create_bl3nf_sequences.sql ← YOU ARE HERE
--   08_create_bl3nf_tables.sql
--   09_insert_bl3nf_default_rows.sql
--   10_load_bl3nf_tables.sql
--
-- RERUNNABLE: YES
--   Each sequence is guarded with DO $$ / IF NOT EXISTS block.
--   Safe to execute multiple times without errors or resets.
--
-- NAMING CONVENTION (per Naming_Conventions.docx):
--   Pattern  : SEQ_<TABLE_NAME_WITHOUT_PREFIX>
--   Prefix   : sequences stored in schema bl_3nf
--   Example  : bl_3nf.seq_ce_sales  →  used in CE_SALES.SALE_ID
--
-- KEY RULES (per Naming_Conventions.docx §column Naming Conventions):
--   • "Use only SEQUENCES to generate IDs."
--   • "Do not use the SERIAL type."
--   • New sequence for each table — sequences are NEVER shared.
--   • ID columns are always BIGINT NOT NULL.
--   • Default row (surrogate key = -1) is inserted MANUALLY
--     in 09_insert_bl3nf_default_rows.sql — sequences START
--     WITH 1 so they never collide with the -1 default row.
--
-- SEQUENCE INVENTORY (12 sequences – one per CE_ table):
--   ┌──────────────────────────────────────────┬──────────────────────────────────┐
--   │ Sequence name                            │ Used in table / column           │
--   ├──────────────────────────────────────────┼──────────────────────────────────┤
--   │ bl_3nf.seq_ce_dates                      │ CE_DATES.DATE_ID                 │
--   │ bl_3nf.seq_ce_store_zones                │ CE_STORE_ZONES.STORE_ZONE_ID     │
--   │ bl_3nf.seq_ce_payment_types              │ CE_PAYMENT_TYPES.PAYMENT_TYPE_ID │
--   │ bl_3nf.seq_ce_product_top_categories     │ CE_PRODUCT_TOP_CATEGORIES        │
--   │ bl_3nf.seq_ce_product_categories         │ CE_PRODUCT_CATEGORIES            │
--   │ bl_3nf.seq_ce_product_subcategories      │ CE_PRODUCT_SUBCATEGORIES         │
--   │ bl_3nf.seq_ce_locations                  │ CE_LOCATIONS.LOCATION_ID         │
--   │ bl_3nf.seq_ce_employees                  │ CE_EMPLOYEES.EMPLOYEE_ID         │
--   │ bl_3nf.seq_ce_stores                     │ CE_STORES.STORE_ID               │
--   │ bl_3nf.seq_ce_customers_scd              │ CE_CUSTOMERS_SCD.CUSTOMER_ID     │
--   │ bl_3nf.seq_ce_products_scd               │ CE_PRODUCTS_SCD.PRODUCT_ID       │
--   │ bl_3nf.seq_ce_sales                      │ CE_SALES.SALE_ID                 │
--   └──────────────────────────────────────────┴──────────────────────────────────┘
--
-- SCD NOTE:
--   SCD Type 2 tables (CE_CUSTOMERS_SCD, CE_PRODUCTS_SCD) use
--   composite PK (_ID + START_DT). Each new SCD2 version of a
--   row consumes a new surrogate key value from the sequence —
--   this is correct and expected behaviour.
--
-- AUTHOR:  DWH ETL Pipeline
-- CREATED: 2024-01-01
-- ============================================================


-- ============================================================
-- SEQUENCE GROUP 1: SCD Type 0 — Immutable reference tables
--   CE_DATES | CE_STORE_ZONES | CE_PAYMENT_TYPES
--   (rows never modified after insert — no UPDATE_DT column)
-- ============================================================

-- --------------------------------------------------------
-- seq_ce_dates
-- Used by: CE_DATES.DATE_ID
-- NK:      DATE_SRC_ID = TO_CHAR(transaction_date, 'YYYYMMDD')
-- Sources: sa_retail.src_retail_sales.transaction_date
--          sa_ecom.src_ecom_sales.transaction_date
-- --------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_sequences
        WHERE  schemaname = 'bl_3nf'
          AND  sequencename = 'seq_ce_dates'
    ) THEN
        CREATE SEQUENCE bl_3nf.seq_ce_dates
            START WITH 1
            INCREMENT BY 1
            NO MINVALUE
            NO MAXVALUE
            CACHE 1;

        RAISE NOTICE 'Sequence bl_3nf.seq_ce_dates created.';
    ELSE
        RAISE NOTICE 'Sequence bl_3nf.seq_ce_dates already exists – skipping.';
    END IF;
END;
$$;

-- --------------------------------------------------------
-- seq_ce_store_zones
-- Used by: CE_STORE_ZONES.STORE_ZONE_ID
-- NK:      STORE_ZONE_SRC_ID = UPPER(TRIM(zone_code))
-- Sources: sa_retail.src_retail_sales.zone_code
--          ecom → 'N/A' constant (no zone info in ecom source)
-- Values:  North / South / East / West / N/A
-- SCD:     Type 0 – fixed reference, never modified
-- --------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_sequences
        WHERE  schemaname = 'bl_3nf'
          AND  sequencename = 'seq_ce_store_zones'
    ) THEN
        CREATE SEQUENCE bl_3nf.seq_ce_store_zones
            START WITH 1
            INCREMENT BY 1
            NO MINVALUE
            NO MAXVALUE
            CACHE 1;

        RAISE NOTICE 'Sequence bl_3nf.seq_ce_store_zones created.';
    ELSE
        RAISE NOTICE 'Sequence bl_3nf.seq_ce_store_zones already exists – skipping.';
    END IF;
END;
$$;

-- --------------------------------------------------------
-- seq_ce_payment_types
-- Used by: CE_PAYMENT_TYPES.PAYMENT_TYPE_ID
-- NK:      PAYMENT_TYPE_SRC_ID = UPPER(TRIM(payment_method/type))
-- Sources: sa_retail.src_retail_sales.payment_method
--          sa_ecom.src_ecom_sales.payment_type
-- Values:  Cash / Credit Card / Debit Card
-- SCD:     Type 0 – immutable junk dimension labels
-- --------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_sequences
        WHERE  schemaname = 'bl_3nf'
          AND  sequencename = 'seq_ce_payment_types'
    ) THEN
        CREATE SEQUENCE bl_3nf.seq_ce_payment_types
            START WITH 1
            INCREMENT BY 1
            NO MINVALUE
            NO MAXVALUE
            CACHE 1;

        RAISE NOTICE 'Sequence bl_3nf.seq_ce_payment_types created.';
    ELSE
        RAISE NOTICE 'Sequence bl_3nf.seq_ce_payment_types already exists – skipping.';
    END IF;
END;
$$;


-- ============================================================
-- SEQUENCE GROUP 2: SCD Type 1 — Product category hierarchy
--   CE_PRODUCT_TOP_CATEGORIES → CE_PRODUCT_CATEGORIES
--   → CE_PRODUCT_SUBCATEGORIES
--   (created in hierarchy top-down order)
-- ============================================================

-- --------------------------------------------------------
-- seq_ce_product_top_categories
-- Used by: CE_PRODUCT_TOP_CATEGORIES.PRODUCT_TOP_CATEGORY_ID
-- NK:      PRODUCT_TOP_CATEGORY_SRC_ID = UPPER(TRIM(top_category))
-- Sources: sa_retail.src_retail_sales.top_category
--          ecom → no equivalent → FK defaults to -1 (default row)
-- SCD:     Type 1 – overwrite on correction
-- --------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_sequences
        WHERE  schemaname = 'bl_3nf'
          AND  sequencename = 'seq_ce_product_top_categories'
    ) THEN
        CREATE SEQUENCE bl_3nf.seq_ce_product_top_categories
            START WITH 1
            INCREMENT BY 1
            NO MINVALUE
            NO MAXVALUE
            CACHE 1;

        RAISE NOTICE 'Sequence bl_3nf.seq_ce_product_top_categories created.';
    ELSE
        RAISE NOTICE 'Sequence bl_3nf.seq_ce_product_top_categories already exists – skipping.';
    END IF;
END;
$$;

-- --------------------------------------------------------
-- seq_ce_product_categories
-- Used by: CE_PRODUCT_CATEGORIES.PRODUCT_CATEGORY_ID
-- NK:      PRODUCT_CATEGORY_SRC_ID = UPPER(TRIM(category/product_type))
-- Sources: sa_retail.src_retail_sales.category
--          sa_ecom.src_ecom_sales.product_type
-- FK:      PRODUCT_TOP_CATEGORY_ID → CE_PRODUCT_TOP_CATEGORIES
-- SCD:     Type 1
-- --------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_sequences
        WHERE  schemaname = 'bl_3nf'
          AND  sequencename = 'seq_ce_product_categories'
    ) THEN
        CREATE SEQUENCE bl_3nf.seq_ce_product_categories
            START WITH 1
            INCREMENT BY 1
            NO MINVALUE
            NO MAXVALUE
            CACHE 1;

        RAISE NOTICE 'Sequence bl_3nf.seq_ce_product_categories created.';
    ELSE
        RAISE NOTICE 'Sequence bl_3nf.seq_ce_product_categories already exists – skipping.';
    END IF;
END;
$$;

-- --------------------------------------------------------
-- seq_ce_product_subcategories
-- Used by: CE_PRODUCT_SUBCATEGORIES.PRODUCT_SUBCATEGORY_ID
-- NK:      PRODUCT_SUBCATEGORY_SRC_ID = UPPER(TRIM(subcategory/details))
-- Sources: sa_retail.src_retail_sales.subcategory
--          sa_ecom.src_ecom_sales.details
-- FK:      PRODUCT_CATEGORY_ID → CE_PRODUCT_CATEGORIES
-- SCD:     Type 1
-- --------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_sequences
        WHERE  schemaname = 'bl_3nf'
          AND  sequencename = 'seq_ce_product_subcategories'
    ) THEN
        CREATE SEQUENCE bl_3nf.seq_ce_product_subcategories
            START WITH 1
            INCREMENT BY 1
            NO MINVALUE
            NO MAXVALUE
            CACHE 1;

        RAISE NOTICE 'Sequence bl_3nf.seq_ce_product_subcategories created.';
    ELSE
        RAISE NOTICE 'Sequence bl_3nf.seq_ce_product_subcategories already exists – skipping.';
    END IF;
END;
$$;


-- ============================================================
-- SEQUENCE GROUP 3: SCD Type 1 — Location + Store chain
--   CE_LOCATIONS (must exist before CE_EMPLOYEES, CE_STORES)
--   CE_EMPLOYEES
--   CE_STORES
-- ============================================================

-- --------------------------------------------------------
-- seq_ce_locations
-- Used by: CE_LOCATIONS.LOCATION_ID
-- NK:      LOCATION_SRC_ID = generated from address components
--          COALESCE(address,'N/A') || '_' || COALESCE(postal_code,'N/A')
-- Sources: store addresses   (sa_retail only)
--          customer addresses (sa_retail + sa_ecom)
--          employee addresses (sa_retail + sa_ecom)
-- SCD:     Type 1 – city/state corrections overwrite
-- NOTE:    Single shared location table for all address types
--          (store, customer, employee) per Business_Template §2.3.2
-- --------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_sequences
        WHERE  schemaname = 'bl_3nf'
          AND  sequencename = 'seq_ce_locations'
    ) THEN
        CREATE SEQUENCE bl_3nf.seq_ce_locations
            START WITH 1
            INCREMENT BY 1
            NO MINVALUE
            NO MAXVALUE
            CACHE 1;

        RAISE NOTICE 'Sequence bl_3nf.seq_ce_locations created.';
    ELSE
        RAISE NOTICE 'Sequence bl_3nf.seq_ce_locations already exists – skipping.';
    END IF;
END;
$$;

-- --------------------------------------------------------
-- seq_ce_employees
-- Used by: CE_EMPLOYEES.EMPLOYEE_ID
-- NK:      EMPLOYEE_SRC_ID = employee_id (retail) / ee_id (ecom)
-- Sources: sa_retail.src_retail_sales.employee_id
--          sa_ecom.src_ecom_sales.ee_id
-- FK:      EMPLOYEE_LOCATION_ID → CE_LOCATIONS
-- SCD:     Type 1 – administrative corrections overwrite
-- --------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_sequences
        WHERE  schemaname = 'bl_3nf'
          AND  sequencename = 'seq_ce_employees'
    ) THEN
        CREATE SEQUENCE bl_3nf.seq_ce_employees
            START WITH 1
            INCREMENT BY 1
            NO MINVALUE
            NO MAXVALUE
            CACHE 1;

        RAISE NOTICE 'Sequence bl_3nf.seq_ce_employees created.';
    ELSE
        RAISE NOTICE 'Sequence bl_3nf.seq_ce_employees already exists – skipping.';
    END IF;
END;
$$;

-- --------------------------------------------------------
-- seq_ce_stores
-- Used by: CE_STORES.STORE_ID
-- NK:      STORE_SRC_ID = store_code (retail) / 'ECOMMERCE' (ecom)
-- Sources: sa_retail.src_retail_sales.store_code
--          ecom → single constant row 'ECOMMERCE' / STORE_CHANNEL='ECOMMERCE'
-- FK:      STORE_ZONE_ID → CE_STORE_ZONES
--          STORE_LOCATION_ID → CE_LOCATIONS
-- SCD:     Type 1 – address/zone corrections overwrite
-- --------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_sequences
        WHERE  schemaname = 'bl_3nf'
          AND  sequencename = 'seq_ce_stores'
    ) THEN
        CREATE SEQUENCE bl_3nf.seq_ce_stores
            START WITH 1
            INCREMENT BY 1
            NO MINVALUE
            NO MAXVALUE
            CACHE 1;

        RAISE NOTICE 'Sequence bl_3nf.seq_ce_stores created.';
    ELSE
        RAISE NOTICE 'Sequence bl_3nf.seq_ce_stores already exists – skipping.';
    END IF;
END;
$$;


-- ============================================================
-- SEQUENCE GROUP 4: SCD Type 2 — Historical dimension tables
--   CE_CUSTOMERS_SCD | CE_PRODUCTS_SCD
--
--   IMPORTANT: Each new SCD2 version of a row (when tracked
--   attributes change) consumes a NEW surrogate key value.
--   Composite PK = (_ID + START_DT).
--   FK from CE_SALES to these tables is LOGICAL ONLY —
--   no DB constraint (per Naming_Conventions.docx SCD2 rules).
-- ============================================================

-- --------------------------------------------------------
-- seq_ce_customers_scd
-- Used by: CE_CUSTOMERS_SCD.CUSTOMER_ID
-- NK:      CUSTOMER_SRC_ID = customer_id (retail) / user_id (ecom)
-- Sources: sa_retail.src_retail_sales.customer_id
--          sa_ecom.src_ecom_sales.user_id
-- FK:      CUSTOMER_LOCATION_ID → CE_LOCATIONS (logical only)
-- SCD:     Type 2 – address changes create new version
-- Tracked: CUSTOMER_LOCATION_ID (address changes)
-- PK:      COMPOSITE (CUSTOMER_ID, START_DT)
-- --------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_sequences
        WHERE  schemaname = 'bl_3nf'
          AND  sequencename = 'seq_ce_customers_scd'
    ) THEN
        CREATE SEQUENCE bl_3nf.seq_ce_customers_scd
            START WITH 1
            INCREMENT BY 1
            NO MINVALUE
            NO MAXVALUE
            CACHE 1;

        RAISE NOTICE 'Sequence bl_3nf.seq_ce_customers_scd created.';
    ELSE
        RAISE NOTICE 'Sequence bl_3nf.seq_ce_customers_scd already exists – skipping.';
    END IF;
END;
$$;

-- --------------------------------------------------------
-- seq_ce_products_scd
-- Used by: CE_PRODUCTS_SCD.PRODUCT_ID
-- NK:      PRODUCT_SRC_ID = product_code (both sources)
-- Sources: sa_retail.src_retail_sales.product_code
--          sa_ecom.src_ecom_sales.product_code
-- FK:      PRODUCT_SUBCATEGORY_ID → CE_PRODUCT_SUBCATEGORIES
-- SCD:     Type 2 – price/colour/size/description changes create
--          new version (per Business_Template.docx §2.3.11)
-- Tracked: PRODUCT_MIN_AMOUNT, PRODUCT_COLOUR, PRODUCT_SIZE,
--          PRODUCT_DESCRIPTION
-- PK:      COMPOSITE (PRODUCT_ID, START_DT)
-- --------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_sequences
        WHERE  schemaname = 'bl_3nf'
          AND  sequencename = 'seq_ce_products_scd'
    ) THEN
        CREATE SEQUENCE bl_3nf.seq_ce_products_scd
            START WITH 1
            INCREMENT BY 1
            NO MINVALUE
            NO MAXVALUE
            CACHE 1;

        RAISE NOTICE 'Sequence bl_3nf.seq_ce_products_scd created.';
    ELSE
        RAISE NOTICE 'Sequence bl_3nf.seq_ce_products_scd already exists – skipping.';
    END IF;
END;
$$;


-- ============================================================
-- SEQUENCE GROUP 5: Fact table
--   CE_SALES — append-only incremental load
--   No default row (fact tables excluded per Default-value.pptx)
-- ============================================================

-- --------------------------------------------------------
-- seq_ce_sales
-- Used by: CE_SALES.SALE_ID
-- NK:      SALE_SRC_ID = bill_id (retail) / payment_id (ecom)
-- Sources: sa_retail.src_retail_sales.bill_id
--          sa_ecom.src_ecom_sales.payment_id
-- NOTE:    No default row — fact tables are excluded from
--          default row policy per Default-value.pptx slide 3.
-- --------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_sequences
        WHERE  schemaname = 'bl_3nf'
          AND  sequencename = 'seq_ce_sales'
    ) THEN
        CREATE SEQUENCE bl_3nf.seq_ce_sales
            START WITH 1
            INCREMENT BY 1
            NO MINVALUE
            NO MAXVALUE
            CACHE 1;

        RAISE NOTICE 'Sequence bl_3nf.seq_ce_sales created.';
    ELSE
        RAISE NOTICE 'Sequence bl_3nf.seq_ce_sales already exists – skipping.';
    END IF;
END;
$$;


-- ============================================================
-- VERIFICATION — List all created sequences in bl_3nf schema
-- ============================================================

DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO   v_count
    FROM   pg_sequences
    WHERE  schemaname = 'bl_3nf';

    RAISE NOTICE '-------------------------------------------';
    RAISE NOTICE 'BL_3NF sequences present: % / 12 expected.', v_count;
    RAISE NOTICE '-------------------------------------------';

    IF v_count < 12 THEN
        RAISE WARNING 'Expected 12 sequences in bl_3nf, found %. '
                      'Check for creation errors above.', v_count;
    END IF;
END;
$$;