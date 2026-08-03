-- ============================================================
-- DDL - DWH Privilege Grants
--
-- PRIVILEGE MATRIX:
--
--   Schema       │ dwh_sa_role │ dwh_bl3nf │ dwh_bldm │ dwh_bl_cl │ dwh_readonly
--   ─────────────┼─────────────┼───────────┼──────────┼───────────┼─────────────
--   sa_retail    │ USAGE+SEL   │     —     │    —     │ (inherit) │     —
--   sa_ecom      │ USAGE+SEL   │     —     │    —     │ (inherit) │     —
--   bl_3nf       │     —       │ USAGE+    │    —     │ (inherit) │  USAGE+SEL
--                │             │ SEL+INS+  │          │           │
--                │             │ UPD+SEQ   │          │           │
--   bl_dm        │     —       │     —     │ USAGE+   │ (inherit) │  USAGE+SEL
--                │             │           │ SEL+INS+ │           │
--                │             │           │ UPD+SEQ  │           │
--   bl_cl        │     —       │     —     │    —     │   ALL     │     —
--
-- ============================================================


-- ============================================================
-- SECTION 1 — SA_RETAIL SCHEMA
--   dwh_sa_role : USAGE on schema + SELECT on all tables
--   Rationale   : ETL reads from src_retail_sales; no writes
--                 to SA layer from BL_CL (SA is full-refresh,
--                 loaded by a separate SA load script).
-- ============================================================

GRANT USAGE  ON SCHEMA sa_retail TO dwh_sa_role;
GRANT SELECT ON ALL TABLES IN SCHEMA sa_retail TO dwh_sa_role;

-- Ensures future tables created in sa_retail are also covered
ALTER DEFAULT PRIVILEGES IN SCHEMA sa_retail
    GRANT SELECT ON TABLES TO dwh_sa_role;


-- ============================================================
-- SECTION 2 — SA_ECOM SCHEMA
--   Same pattern as sa_retail.
-- ============================================================

GRANT USAGE  ON SCHEMA sa_ecom TO dwh_sa_role;
GRANT SELECT ON ALL TABLES IN SCHEMA sa_ecom TO dwh_sa_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA sa_ecom
    GRANT SELECT ON TABLES TO dwh_sa_role;


-- ============================================================
-- SECTION 3 — BL_3NF SCHEMA
--   dwh_bl3nf_role:
--     USAGE on schema
--     SELECT + INSERT + UPDATE on all tables
--     USAGE + SELECT on all sequences
-- ============================================================

GRANT USAGE  ON SCHEMA bl_3nf TO dwh_bl3nf_role;

GRANT SELECT, INSERT, UPDATE
    ON ALL TABLES IN SCHEMA bl_3nf
    TO dwh_bl3nf_role;

GRANT USAGE, SELECT
    ON ALL SEQUENCES IN SCHEMA bl_3nf
    TO dwh_bl3nf_role;

-- Future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA bl_3nf
    GRANT SELECT, INSERT, UPDATE ON TABLES TO dwh_bl3nf_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA bl_3nf
    GRANT USAGE, SELECT ON SEQUENCES TO dwh_bl3nf_role;

-- ============================================================
-- SECTION 4 — BL_DM SCHEMA
--   dwh_bldm_role:
--     Same pattern as bl_3nf.
--     Includes dim_time_day which is read by bl_3nf.ce_sales
--     FK lookups — so dwh_bl3nf_role also needs SELECT on
--     bl_dm.dim_time_day (granted via inheritance through
--     dwh_bl_cl_role, or explicitly below).
-- ============================================================

GRANT USAGE  ON SCHEMA bl_dm TO dwh_bldm_role;

GRANT SELECT, INSERT, UPDATE
    ON ALL TABLES IN SCHEMA bl_dm
    TO dwh_bldm_role;

GRANT USAGE, SELECT
    ON ALL SEQUENCES IN SCHEMA bl_dm
    TO dwh_bldm_role;

-- Future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA bl_dm
    GRANT SELECT, INSERT, UPDATE ON TABLES TO dwh_bldm_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA bl_dm
    GRANT USAGE, SELECT ON SEQUENCES TO dwh_bldm_role;

-- ── BL_3NF needs SELECT on dim_time_day for CE_SALES FK lookup ──
-- ce_sales.date_id references bl_dm.dim_time_day.date_surr_id.
-- The ETL role (dwh_bl_cl_role) inherits dwh_bldm_role so this
-- is already covered. This explicit grant handles the edge case
-- where dwh_bl3nf_role is used standalone.
GRANT USAGE  ON SCHEMA bl_dm TO dwh_bl3nf_role;
GRANT SELECT ON bl_dm.dim_time_day TO dwh_bl3nf_role;


-- ============================================================
-- SECTION 5 — BL_CL SCHEMA
--   dwh_bl_cl_role : ALL PRIVILEGES
--     Owns all ETL objects: functions, procedures, tables,
--     sequences in bl_cl. The ETL service account needs full
--     control to CREATE OR REPLACE its own objects.
--
--   Note: dwh_bl_cl_role already INHERITS dwh_sa_role,
--   dwh_bl3nf_role, dwh_bldm_role (set in 02_create_roles.sql)
--   so no additional grants to those schemas are needed here.
-- ============================================================

GRANT ALL PRIVILEGES ON SCHEMA bl_cl TO dwh_bl_cl_role;

GRANT ALL PRIVILEGES
    ON ALL TABLES IN SCHEMA bl_cl
    TO dwh_bl_cl_role;

GRANT ALL PRIVILEGES
    ON ALL SEQUENCES IN SCHEMA bl_cl
    TO dwh_bl_cl_role;

GRANT ALL PRIVILEGES
    ON ALL FUNCTIONS IN SCHEMA bl_cl
    TO dwh_bl_cl_role;

GRANT ALL PRIVILEGES
    ON ALL PROCEDURES IN SCHEMA bl_cl
    TO dwh_bl_cl_role;

-- Future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA bl_cl
    GRANT ALL PRIVILEGES ON TABLES    TO dwh_bl_cl_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA bl_cl
    GRANT ALL PRIVILEGES ON SEQUENCES TO dwh_bl_cl_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA bl_cl
    GRANT ALL PRIVILEGES ON FUNCTIONS TO dwh_bl_cl_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA bl_cl
    GRANT ALL PRIVILEGES ON ROUTINES  TO dwh_bl_cl_role;


-- ============================================================
-- SECTION 6 — READ-ONLY ROLE (BI / Reporting)
--   dwh_readonly_role : SELECT only on bl_3nf + bl_dm
--   No access to: bl_cl (ETL internals), sa_* (raw source data)
-- ============================================================

GRANT USAGE  ON SCHEMA bl_3nf TO dwh_readonly_role;
GRANT SELECT ON ALL TABLES IN SCHEMA bl_3nf TO dwh_readonly_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA bl_3nf
    GRANT SELECT ON TABLES TO dwh_readonly_role;

GRANT USAGE  ON SCHEMA bl_dm TO dwh_readonly_role;
GRANT SELECT ON ALL TABLES IN SCHEMA bl_dm TO dwh_readonly_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA bl_dm
    GRANT SELECT ON TABLES TO dwh_readonly_role;


-- ============================================================
-- VERIFICATION
-- ============================================================

DO $$
DECLARE
    v_errors  TEXT := '';
    v_ok BOOLEAN;
BEGIN
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'DWH PRIVILEGE VERIFICATION';
    RAISE NOTICE '==============================================';

    -- ── SA schemas readable by dwh_sa_role ───────────────────
    SELECT has_schema_privilege('dwh_sa_role', 'sa_retail', 'USAGE')
        INTO v_ok;
    IF v_ok THEN RAISE NOTICE '  [OK] sa_retail  USAGE  → dwh_sa_role';
    ELSE v_errors := v_errors || 'sa_retail USAGE dwh_sa_role | '; END IF;

    SELECT has_schema_privilege('dwh_sa_role', 'sa_ecom', 'USAGE')
        INTO v_ok;
    IF v_ok THEN RAISE NOTICE '  [OK] sa_ecom    USAGE  → dwh_sa_role';
    ELSE v_errors := v_errors || 'sa_ecom USAGE dwh_sa_role | '; END IF;

    -- ── BL_3NF writable by dwh_bl3nf_role ────────────────────
    SELECT has_schema_privilege('dwh_bl3nf_role', 'bl_3nf', 'USAGE')
        INTO v_ok;
    IF v_ok THEN RAISE NOTICE '  [OK] bl_3nf     USAGE  → dwh_bl3nf_role';
    ELSE v_errors := v_errors || 'bl_3nf USAGE dwh_bl3nf_role | '; END IF;

    -- ── BL_DM writable by dwh_bldm_role ──────────────────────
    SELECT has_schema_privilege('dwh_bldm_role', 'bl_dm', 'USAGE')
        INTO v_ok;
    IF v_ok THEN RAISE NOTICE '  [OK] bl_dm      USAGE  → dwh_bldm_role';
    ELSE v_errors := v_errors || 'bl_dm USAGE dwh_bldm_role | '; END IF;

    -- ── BL_CL owned by dwh_bl_cl_role ────────────────────────
    SELECT has_schema_privilege('dwh_bl_cl_role', 'bl_cl', 'CREATE')
        INTO v_ok;
    IF v_ok THEN RAISE NOTICE '  [OK] bl_cl      CREATE → dwh_bl_cl_role';
    ELSE v_errors := v_errors || 'bl_cl CREATE dwh_bl_cl_role | '; END IF;

    -- ── BL_3NF readable by dwh_readonly_role ─────────────────
    SELECT has_schema_privilege('dwh_readonly_role', 'bl_3nf', 'USAGE')
        INTO v_ok;
    IF v_ok THEN RAISE NOTICE '  [OK] bl_3nf     USAGE  → dwh_readonly_role';
    ELSE v_errors := v_errors || 'bl_3nf USAGE dwh_readonly_role | '; END IF;

    -- ── BL_DM readable by dwh_readonly_role ──────────────────
    SELECT has_schema_privilege('dwh_readonly_role', 'bl_dm', 'USAGE')
        INTO v_ok;
    IF v_ok THEN RAISE NOTICE '  [OK] bl_dm      USAGE  → dwh_readonly_role';
    ELSE v_errors := v_errors || 'bl_dm USAGE dwh_readonly_role | '; END IF;

    RAISE NOTICE '----------------------------------------------';

    IF v_errors <> '' THEN
        RAISE EXCEPTION 'Privilege verification FAILED. Missing grants: [%]', v_errors;
    ELSE
        RAISE NOTICE '  All privilege checks passed OK.';
    END IF;

    RAISE NOTICE '==============================================';
END;
$$;