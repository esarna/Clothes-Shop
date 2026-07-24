-- ============================================================
-- DDL - BL_CL Schema Creation
-- ============================================================


-- ============================================================
-- 1. CREATE SCHEMA
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bl_cl;

COMMENT ON SCHEMA bl_cl IS
    'Business Layer Cleansing (BL_CL). '
    'ETL engine schema for the Clothes Shop DWH. '
    'Contains all ETL objects: metadata tables (MTA_), '
    'work tables (WRK_), lookup tables (LKP_), '
    'extraction functions (fn_get_*), '
    'load procedures (prc_load_*), '
    'and master orchestration procedures (prc_master_load_*). '
    'All procedures write execution logs to bl_cl.mta_load_logs. '
    'Source systems: SA_RETAIL, SA_ECOM. '
    'Targets: BL_3NF (CE_ tables), BL_DM (DIM_ and FCT_ tables).';


-- ============================================================
-- 2. VERIFICATION
-- ============================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM   information_schema.schemata
        WHERE  schema_name = 'bl_cl'
    ) THEN
        RAISE NOTICE '[OK] Schema bl_cl is present and ready.';
    ELSE
        RAISE EXCEPTION '[FAIL] Schema bl_cl was NOT created — check privileges.';
    END IF;
END;
$$;