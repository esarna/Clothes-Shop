-- DDL — Schema creation

-- CREATE SCHEMA IF NOT EXISTS bl_3nf;
-- COMMENT ON SCHEMA bl_3nf

-- ============================================================
-- FILE:    06_create_bl3nf_schema.sql
-- LAYER:   BL_3NF (Business Layer – Third Normal Form)
-- PURPOSE: Create the BL_3NF schema that holds all normalised
--          Core Entity (CE_) tables for the Clothes Shop DWH.
--
-- SOURCES:  SA_RETAIL (sa_retail.src_retail_sales)
--           SA_ECOM   (sa_ecom.src_ecom_sales)
--
-- EXECUTION ORDER IN PIPELINE:
--   01_create_schemas.sql          ← SA schemas
--   02_setup_file_fdw.sql          ← file_fdw extension + server
--   03_create_ext_tables.sql       ← EXT_ foreign tables
--   04_create_src_tables.sql       ← SRC_ staging tables
--   05_load_src_tables.sql         ← SA layer incremental load
--   >>> 06_create_bl3nf_schema.sql ← YOU ARE HERE
--   07_create_bl3nf_sequences.sql
--   08_create_bl3nf_tables.sql
--   09_insert_bl3nf_default_rows.sql
--   10_load_bl3nf_tables.sql
--
-- RERUNNABLE: YES — uses CREATE SCHEMA IF NOT EXISTS
-- IDEMPOTENT: YES — safe to execute multiple times
--
-- NAMING CONVENTION (per Naming_Conventions.docx):
--   Schema  : BL_3NF
--   Tables  : CE_<Name in Plural>        (SCD Type 0 / 1)
--             CE_<Name in Plural>_SCD    (SCD Type 2)
--   Fact    : CE_SALES                   (CE_ prefix, 3NF layer)
--
-- ARCHITECTURE NOTE (per Knowledge_Base.docx):
--   This DWH uses a HYBRID architecture:
--     CSV files
--       └─ SA layer     (sa_retail, sa_ecom)
--           └─ BL_3NF   (this schema – Inmon 3NF normalised)
--               └─ BL_DM (Star schema – Kimball dimensional)
--   BL_3NF sits between the staging area (SA) and the
--   dimensional model (BL_DM). It serves as the single
--   source of truth, integrating data from both source
--   systems into conformed, normalised Core Entity tables.
--
-- SCD TYPE SUMMARY (per Business_Template.docx §2.2):
--   SCD Type 0 : CE_DATES, CE_PAYMENT_TYPES, CE_STORE_ZONES
--                → immutable reference data, never modified
--   SCD Type 1 : CE_LOCATIONS, CE_PRODUCT_TOP_CATEGORIES,
--                CE_PRODUCT_CATEGORIES, CE_PRODUCT_SUBCATEGORIES,
--                CE_EMPLOYEES, CE_STORES
--                → overwrite on change (administrative corrections)
--   SCD Type 2 : CE_CUSTOMERS_SCD, CE_PRODUCTS_SCD
--                → full history tracking (composite PK: _ID + START_DT)
--   Fact table : CE_SALES
--                → no SCD, append-only incremental load
--
-- DEFAULT ROW POLICY (per Default-value.pptx):
--   Every CE_ table (EXCEPT CE_SALES fact table) must contain
--   a default row with surrogate key = -1 and text values = 'n/a'.
--   This prevents NULL FK values in CE_SALES.
--
-- AUTHOR:  DWH ETL Pipeline
-- CREATED: 2024-01-01
-- ============================================================


-- ============================================================
-- STEP 1: Create BL_3NF schema
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bl_3nf;

COMMENT ON SCHEMA bl_3nf IS
    'Business Layer 3NF (Inmon normalised model). '
    'Contains all Core Entity (CE_) tables integrated from '
    'SA_RETAIL (sa_retail.src_retail_sales) and '
    'SA_ECOM (sa_ecom.src_ecom_sales). '
    'Serves as the single source of truth for the BL_DM Star schema. '
    'Tables: CE_SALES (fact), CE_CUSTOMERS_SCD (SCD2), '
    'CE_PRODUCTS_SCD (SCD2), CE_EMPLOYEES (SCD1), CE_STORES (SCD1), '
    'CE_LOCATIONS (SCD1), CE_PRODUCT_SUBCATEGORIES (SCD1), '
    'CE_PRODUCT_CATEGORIES (SCD1), CE_PRODUCT_TOP_CATEGORIES (SCD1), '
    'CE_DATES (SCD0), CE_PAYMENT_TYPES (SCD0), CE_STORE_ZONES (SCD0). '
    'All dimension/reference tables contain a default row (ID = -1). '
    'SCD Type 2 tables use composite PK (_ID + START_DT). '
    'No DB-level FK constraints from CE_SALES to SCD2 tables.';


-- ============================================================
-- VERIFICATION (optional – informational notice)
-- ============================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM   information_schema.schemata
        WHERE  schema_name = 'bl_3nf'
    ) THEN
        RAISE NOTICE 'Schema bl_3nf is present and ready.';
    ELSE
        RAISE EXCEPTION 'Schema bl_3nf was NOT created – check permissions.';
    END IF;
END;
$$;