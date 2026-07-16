-- DDL - Schema creation

-- ============================================================
-- Create the BL_3NF schema that holds all normalised 
-- Core Entity (CE_) tables for the Clothes Shop DWH.
--
-- SOURCES:  SA_RETAIL (sa_retail.src_retail_sales)
--           SA_ECOM   (sa_ecom.src_ecom_sales)
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
-- ============================================================


-- ============================================================
-- 1. Create BL_3NF schema
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bl_3nf;

COMMENT ON SCHEMA bl_3nf IS
    'Business Layer 3NF. '
    'Contains all Core Entity (CE_) tables integrated from '
    'SA_RETAIL (sa_retail.src_retail_sales) and '
    'SA_ECOM (sa_ecom.src_ecom_sales). '
    'Tables: CE_SALES (fact), CE_CUSTOMERS_SCD (SCD2), '
    'CE_PRODUCTS_SCD (SCD2), CE_EMPLOYEES (SCD1), CE_STORES (SCD1), '
    'CE_LOCATIONS (SCD1), CE_PRODUCT_SUBCATEGORIES (SCD1), '
    'CE_PRODUCT_CATEGORIES (SCD1), CE_PRODUCT_TOP_CATEGORIES (SCD1), '
    'CE_DATES (SCD0), CE_PAYMENT_TYPES (SCD0), CE_STORE_ZONES (SCD0). '
    'All dimension/reference tables contain a default row (ID = -1). '
    'SCD Type 2 tables use composite PK (_ID + START_DT). '
    'No DB-level FK constraints from CE_SALES to SCD2 tables.';


-- ============================================================
-- 2. VERIFICATION
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
        RAISE EXCEPTION 'Schema bl_3nf was NOT created.';
    END IF;
END;
$$;