-- ============================================================
-- DDL - DWH Schema Setup
--
--
-- IDEMPOTENT: Yes — IF NOT EXISTS on all statements.
-- ============================================================


-- ============================================================
-- 1. SOURCE AREA SCHEMAS (SA layer)
--    Naming: SA_<SOURCE_SYSTEM_NAME>
-- ============================================================

CREATE SCHEMA IF NOT EXISTS sa_retail;

COMMENT ON SCHEMA sa_retail IS
    'Source Area – Retail channel. '
    'Contains: EXT_RETAIL_SALES (foreign table over CSV), '
    'SRC_RETAIL_SALES (typed, cleansed staging table). '
    'Load strategy: FULL REFRESH (TRUNCATE + INSERT on each run). '
    'Source file: retail-sample.csv (~1000 transactions). '
    'Sensitive columns excluded at ETL boundary: SSN, credit card, CVV.';

CREATE SCHEMA IF NOT EXISTS sa_ecom;

COMMENT ON SCHEMA sa_ecom IS
    'Source Area – E-Commerce channel. '
    'Contains: EXT_ECOM_SALES (foreign table over CSV), '
    'SRC_ECOM_SALES (typed, cleansed staging table). '
    'Load strategy: FULL REFRESH (TRUNCATE + INSERT on each run). '
    'Source file: ecom-sample.csv (~2000 transactions). '
    'Sensitive columns excluded at ETL boundary: SSN, IBAN, CVV, credit card.';


-- ============================================================
-- 2. BUSINESS LAYER 3NF SCHEMA
--    Naming: BL_3NF
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bl_3nf;

COMMENT ON SCHEMA bl_3nf IS
    'Business Layer 3NF (Inmon). '
    'Contains all normalised Core Entity (CE_) tables. '
    'Table naming: CE_<Name> (SCD0/1), CE_<Name>_SCD (SCD2). '
    'PKs: <Name>_ID (BIGINT, sequence-generated). '
    'SCD2 composite PK: (<Name>_ID + START_DT). '
    'Source triplet on every table: SOURCE_SYSTEM, SOURCE_ENTITY, <Name>_SRC_ID. '
    'FK to bl_dm.dim_time_day from ce_sales (date lookup). '
    'No DB-level FK constraints to SCD2 tables from ce_sales. '
    'Tables: CE_SALES, CE_CUSTOMERS_SCD, CE_PRODUCTS_SCD, '
    'CE_EMPLOYEES, CE_STORES, CE_LOCATIONS, '
    'CE_PRODUCT_SUBCATEGORIES, CE_PRODUCT_CATEGORIES, '
    'CE_PRODUCT_TOP_CATEGORIES, CE_PAYMENT_TYPES, CE_STORE_ZONES.';


-- ============================================================
-- 3. BUSINESS LAYER DIMENSIONAL MODEL SCHEMA
--    Naming: BL_DM
--
--    CRITICAL: Must be created BEFORE bl_3nf because
--    bl_3nf.ce_sales references bl_dm.dim_time_day via FK.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bl_dm;

COMMENT ON SCHEMA bl_dm IS
    'Business Layer Dimensional Model (Kimball). '
    'Contains star schema: DIM_ tables + FCT_ tables. '
    'Table naming: DIM_<Name> (SCD0/1), DIM_<Name>_SCD (SCD2), '
    'DIM_TIME_<Level> (calendar), FCT_<Name>_<Level> (facts). '
    'PKs: <Name>_SURR_ID (BIGINT, sequence-generated). '
    'SCD2 tables use single-column PK <Name>_SURR_ID (differs '
    'from composite PK in BL_3NF). '
    'DB-level FK constraints to SCD2 dimensions ARE enforced here '
    '(unlike BL_3NF layer). '
    'Tables: DIM_TIME_DAY, DIM_CUSTOMERS_SCD, DIM_PRODUCTS_SCD, '
    'DIM_EMPLOYEES, DIM_STORES, DIM_PAYMENT_TYPES, FCT_SALES_DD.';


-- ============================================================
-- 4. BUSINESS LAYER CLEANSING SCHEMA (ETL ENGINE)
--    Naming: BL_CL
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bl_cl;

COMMENT ON SCHEMA bl_cl IS
    'Business Layer Cleansing (BL_CL). '
    'ETL engine schema — contains all procedural ETL objects. '
    'Object types: '
    'MTA_ tables (metadata/audit), '
    'WRK_ tables (deduplication work tables), '
    'LKP_ tables (lookup reference tables), '
    'fn_get_*() functions (RETURNS TABLE — data extraction), '
    'prc_load_*() procedures (incremental load per CE_/DIM_ table), '
    'prc_master_load_*() procedures (orchestration). '
    'All procedures log to bl_cl.mta_load_logs via prc_log_procedure().';


-- ============================================================
-- 5. VERIFICATION — confirm all 5 schemas exist
-- ============================================================

DO $$
DECLARE
    v_schema      TEXT;
    v_missing     TEXT    := '';
    v_found_count INTEGER := 0;
    v_expected    TEXT[]  := ARRAY[
        'sa_retail',
        'sa_ecom',
        'bl_3nf',
        'bl_dm',
        'bl_cl'
    ];
BEGIN
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'DWH SCHEMA VERIFICATION';
    RAISE NOTICE '==============================================';

    FOREACH v_schema IN ARRAY v_expected
    LOOP
        IF EXISTS (
            SELECT 1
            FROM   information_schema.schemata
            WHERE  schema_name = v_schema
        ) THEN
            v_found_count := v_found_count + 1;
            RAISE NOTICE '  [OK]      Schema: %', v_schema;
        ELSE
            v_missing := v_missing || v_schema || ', ';
            RAISE WARNING '  [MISSING] Schema: %', v_schema;
        END IF;
    END LOOP;

    RAISE NOTICE '----------------------------------------------';
    RAISE NOTICE '  Verified: % / % schemas present.',
                 v_found_count, array_length(v_expected, 1);

    IF v_missing <> '' THEN
        v_missing := LEFT(v_missing, LENGTH(v_missing) - 2);
        RAISE EXCEPTION 'MISSING schemas: [%]. Check privileges and re-run.', v_missing;
    ELSE
        RAISE NOTICE '  All 5 DWH schemas verified OK.';
    END IF;

    RAISE NOTICE '==============================================';
END;
$$;