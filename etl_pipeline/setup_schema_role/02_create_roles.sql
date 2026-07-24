-- ============================================================
-- DDL - DWH Role Setup
--
-- PURPOSE:
--   Creates database roles that map to the DWH layer
--   access model. Each role grants the minimum privileges
--   required for its layer (principle of least privilege).
--
-- ROLE INVENTORY:
--   ┌──────────────────────┬──────────────────────────────────┐
--   │ Role                 │ Purpose                          │
--   ├──────────────────────┼──────────────────────────────────┤
--   │ dwh_sa_role          │ Read-only access to SA layer     │
--   │                      │ (sa_retail, sa_ecom schemas)     │
--   ├──────────────────────┼──────────────────────────────────┤
--   │ dwh_bl3nf_role       │ Read/write access to BL_3NF      │
--   │                      │ (bl_3nf schema — CE_ tables)     │
--   ├──────────────────────┼──────────────────────────────────┤
--   │ dwh_bldm_role        │ Read/write access to BL_DM       │
--   │                      │ (bl_dm schema — DIM_/FCT_ tables)│
--   ├──────────────────────┼──────────────────────────────────┤
--   │ dwh_bl_cl_role       │ ETL execution role — full access  │
--   │                      │ to bl_cl + read SA + write 3NF/DM│
--   ├──────────────────────┼──────────────────────────────────┤
--   │ dwh_readonly_role    │ BI / reporting — SELECT only on  │
--   │                      │ BL_3NF and BL_DM                 │
--   └──────────────────────┴──────────────────────────────────┘
--
-- ROLE HIERARCHY:
--   dwh_bl_cl_role INHERITS FROM:
--     dwh_sa_role      (needs to READ source tables)
--     dwh_bl3nf_role   (needs to WRITE CE_ tables)
--     dwh_bldm_role    (needs to WRITE DIM_/FCT_ tables)
-- ============================================================


DO $$
DECLARE
    v_role      TEXT;
    v_roles     TEXT[] := ARRAY[
        'dwh_sa_role',
        'dwh_bl3nf_role',
        'dwh_bldm_role',
        'dwh_bl_cl_role',
        'dwh_readonly_role'
    ];
BEGIN
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'DWH ROLE CREATION';
    RAISE NOTICE '==============================================';

    FOREACH v_role IN ARRAY v_roles
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM   pg_roles
            WHERE  rolname = v_role
        ) THEN
            EXECUTE format('CREATE ROLE %I NOLOGIN', v_role);
            RAISE NOTICE '  [CREATED] Role: %', v_role;
        ELSE
            RAISE NOTICE '  [EXISTS]  Role: % — skipped.', v_role;
        END IF;
    END LOOP;

    RAISE NOTICE '==============================================';
END;
$$;


-- ============================================================
-- ROLE COMMENTS
-- (stored in pg_description via COMMENT ON ROLE)
-- ============================================================

COMMENT ON ROLE dwh_sa_role IS
    'DWH Source Area role. '
    'SELECT access on sa_retail and sa_ecom schemas. '
    'Used by ETL processes that read from staging tables. '
    'No write access to any schema.';

COMMENT ON ROLE dwh_bl3nf_role IS
    'DWH Business Layer 3NF role. '
    'SELECT + INSERT + UPDATE on bl_3nf schema (CE_ tables). '
    'USAGE + SELECT on bl_3nf sequences. '
    'No DELETE — incremental load never deletes rows.';

COMMENT ON ROLE dwh_bldm_role IS
    'DWH Business Layer Dimensional Model role. '
    'SELECT + INSERT + UPDATE on bl_dm schema (DIM_/FCT_ tables). '
    'USAGE + SELECT on bl_dm sequences. '
    'No DELETE — incremental load never deletes rows.';

COMMENT ON ROLE dwh_bl_cl_role IS
    'DWH ETL Engine role (Business Layer Cleansing). '
    'Full owner of bl_cl schema objects. '
    'Inherits: dwh_sa_role + dwh_bl3nf_role + dwh_bldm_role. '
    'This is the role used by ETL service accounts '
    'that execute prc_master_load_bl3nf() and prc_master_load_bldm().';

COMMENT ON ROLE dwh_readonly_role IS
    'DWH Read-Only role for BI and reporting tools. '
    'SELECT only on bl_3nf and bl_dm schemas. '
    'No access to bl_cl, sa_retail, sa_ecom '
    '(source and ETL layers are not exposed to BI layer).';


-- ============================================================
-- ROLE HIERARCHY — grant member roles to ETL role
-- dwh_bl_cl_role is the composite ETL role that needs
-- all layer permissions bundled together.
-- ============================================================

DO $$
BEGIN
    -- dwh_bl_cl_role needs SA read access
    IF NOT pg_has_role('dwh_bl_cl_role', 'dwh_sa_role', 'member') THEN
        GRANT dwh_sa_role    TO dwh_bl_cl_role;
        RAISE NOTICE '  [GRANTED] dwh_sa_role    → dwh_bl_cl_role';
    ELSE
        RAISE NOTICE '  [EXISTS]  dwh_sa_role    already member of dwh_bl_cl_role';
    END IF;

    -- dwh_bl_cl_role needs BL_3NF write access
    IF NOT pg_has_role('dwh_bl_cl_role', 'dwh_bl3nf_role', 'member') THEN
        GRANT dwh_bl3nf_role TO dwh_bl_cl_role;
        RAISE NOTICE '  [GRANTED] dwh_bl3nf_role → dwh_bl_cl_role';
    ELSE
        RAISE NOTICE '  [EXISTS]  dwh_bl3nf_role already member of dwh_bl_cl_role';
    END IF;

    -- dwh_bl_cl_role needs BL_DM write access
    IF NOT pg_has_role('dwh_bl_cl_role', 'dwh_bldm_role', 'member') THEN
        GRANT dwh_bldm_role  TO dwh_bl_cl_role;
        RAISE NOTICE '  [GRANTED] dwh_bldm_role  → dwh_bl_cl_role';
    ELSE
        RAISE NOTICE '  [EXISTS]  dwh_bldm_role  already member of dwh_bl_cl_role';
    END IF;
END;
$$;


-- ============================================================
-- VERIFICATION
-- ============================================================

DO $$
DECLARE
    v_role        TEXT;
    v_missing     TEXT    := '';
    v_found_count INTEGER := 0;
    v_expected    TEXT[]  := ARRAY[
        'dwh_sa_role',
        'dwh_bl3nf_role',
        'dwh_bldm_role',
        'dwh_bl_cl_role',
        'dwh_readonly_role'
    ];
BEGIN
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'DWH ROLE VERIFICATION';
    RAISE NOTICE '==============================================';

    FOREACH v_role IN ARRAY v_expected
    LOOP
        IF EXISTS (
            SELECT 1 FROM pg_roles WHERE rolname = v_role
        ) THEN
            v_found_count := v_found_count + 1;
            RAISE NOTICE '  [OK]      Role: %', v_role;
        ELSE
            v_missing := v_missing || v_role || ', ';
            RAISE WARNING '  [MISSING] Role: %', v_role;
        END IF;
    END LOOP;

    RAISE NOTICE '----------------------------------------------';
    RAISE NOTICE '  Verified: % / % roles present.',
                 v_found_count, array_length(v_expected, 1);

    IF v_missing <> '' THEN
        v_missing := LEFT(v_missing, LENGTH(v_missing) - 2);
        RAISE EXCEPTION 'MISSING roles: [%]. Check superuser privileges.', v_missing;
    ELSE
        RAISE NOTICE '  All 5 DWH roles verified OK.';
    END IF;

    RAISE NOTICE '==============================================';
END;
$$;