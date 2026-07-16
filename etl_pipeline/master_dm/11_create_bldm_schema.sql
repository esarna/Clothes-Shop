-- DDL - Schema creation
-- ============================================================
-- Create the BL_DM schema that holds all Dimensional Model
-- tables for the Clothes Shop DWH.
-- SOURCE:  BL_3NF (bl_3nf.ce_* tables)
--
--
-- GRAIN:
--   One product line item per one sales transaction
--   (bill_id / payment_id + product_code).
--
-- SCD TYPE SUMMARY:
--   SCD Type 0 : DIM_TIME_DAY, DIM_PAYMENT_TYPES
--                → immutable reference data, never modified
--                → no TA_UPDATE_DT column
--   SCD Type 1 : DIM_EMPLOYEES, DIM_STORES
--                → overwrite on change (administrative corrections)
--                → TA_INSERT_DT + TA_UPDATE_DT
--   SCD Type 2 : DIM_CUSTOMERS_SCD, DIM_PRODUCTS_SCD
--                → full history tracking
--                → single-column PK (_SURR_ID) on DM layer
--                  (differs from composite PK on BL_3NF layer!)
--                → TA_INSERT_DT + TA_UPDATE_DT
--   Fact table : FCT_SALES_DD
--                → append-only incremental load
--                → no default row
--                → grain: one product line item per transaction
--
-- FK CONSTRAINT RULES:
--   DB-level FK enforced:
--     FCT_SALES_DD → DIM_TIME_DAY       (DATE_SURR_ID)
--     FCT_SALES_DD → DIM_EMPLOYEES      (EMPLOYEE_SURR_ID)
--     FCT_SALES_DD → DIM_STORES         (STORE_SURR_ID)
--     FCT_SALES_DD → DIM_PAYMENT_TYPES  (PAYMENT_TYPE_SURR_ID)
--   Logical FK only (no DB constraint) per Business Template:
--     FCT_SALES_DD → DIM_CUSTOMERS_SCD  (CUSTOMER_SURR_ID)
--     FCT_SALES_DD → DIM_PRODUCTS_SCD   (PRODUCT_SURR_ID)
-- ============================================================


-- ============================================================
-- 1. CREATE BL_DM SCHEMA
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bl_dm;

COMMENT ON SCHEMA bl_dm IS
    'Business Layer Dimensional Model (Star Schema / Kimball). '
    'Contains all DIM_ and FCT_ tables for the Clothes Shop DWH. '
    'Data source: BL_3NF layer (bl_3nf.ce_* tables). '
    'Tables: '
    'FCT_SALES_DD (fact, grain: one product line item per transaction), '
    'DIM_TIME_DAY (SCD0 - calendar), '
    'DIM_PAYMENT_TYPES (SCD0 - junk dimension), '
    'DIM_EMPLOYEES (SCD1 - flattened address from CE_LOCATIONS), '
    'DIM_STORES (SCD1 - flattened zone + address), '
    'DIM_CUSTOMERS_SCD (SCD2 - flattened address from CE_LOCATIONS), '
    'DIM_PRODUCTS_SCD (SCD2 - flattened product hierarchy). '
    'All DIM_ tables contain a default row (SURR_ID = -1). '
    'SCD Type 2 tables use single-column PK (_SURR_ID) on DM layer. '
    'FK constraints from FCT_SALES_DD to DIM_CUSTOMERS_SCD and '
    'DIM_PRODUCTS_SCD are LOGICAL ONLY (no DB constraint) per '
    'Business_Template.docx §3.1.7. '
    'Sequences: bl_dm.seq_dim_* and bl_dm.seq_fct_*.';


-- ============================================================
-- 2. VERIFICATION
-- ============================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM   information_schema.schemata
        WHERE  schema_name = 'bl_dm'
    ) THEN
        RAISE NOTICE 'Schema bl_dm is present and ready.';
    ELSE
        RAISE EXCEPTION 'Schema bl_dm was NOT created.';
    END IF;
END;
$$;