-- ============================================================
-- DDL - BL_CL: Incremental Load Date Table
-- Naming: MTA_ prefix per naming convention (metadata table in BL_CL)
-- ============================================================


-- ============================================================
-- 1. SEQUENCE
-- ============================================================

CREATE SEQUENCE IF NOT EXISTS bl_cl.seq_mta_load_dates
    START WITH 1
    INCREMENT BY 1
    MINVALUE 1
    NO MAXVALUE
    CACHE 1;

COMMENT ON SEQUENCE bl_cl.seq_mta_load_dates IS
    'Surrogate key generator for bl_cl.mta_load_dates.';


-- ============================================================
-- 2. TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS bl_cl.mta_load_dates (
    load_date_id        BIGINT          NOT NULL
                            DEFAULT nextval('bl_cl.seq_mta_load_dates'),
    table_name          VARCHAR(100)    NOT NULL,
    schema_name         VARCHAR(50)     NOT NULL,
    last_load_dt      TIMESTAMP       NOT NULL
                            DEFAULT TIMESTAMP '1900-01-01 00:00:00',
    ta_insert_dt        TIMESTAMP       NOT NULL
                            DEFAULT CURRENT_TIMESTAMP,
    ta_update_dt        TIMESTAMP       NOT NULL
                            DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_mta_load_dates
        PRIMARY KEY (load_date_id),
    CONSTRAINT uq_mta_load_dates_table
        UNIQUE (table_name, schema_name)
);

COMMENT ON TABLE bl_cl.mta_load_dates IS
    'Incremental load meta table. Stores last successful load timestamp '
    'per target table. Used by prc_load_ce_sales and '
    'prc_load_ce_customers_scd to limit source scan to new rows only. '
    'Updated atomically at the end of each successful load procedure.';

COMMENT ON COLUMN bl_cl.mta_load_dates.table_name     IS 'Target table name (e.g. ce_sales, ce_customers_scd).';
COMMENT ON COLUMN bl_cl.mta_load_dates.schema_name    IS 'Target schema name (e.g. bl_3nf).';
COMMENT ON COLUMN bl_cl.mta_load_dates.last_load_dt IS 'Max ta_insert_dt of source rows processed in last successful run. Initial value: 1900-01-01.';
COMMENT ON COLUMN bl_cl.mta_load_dates.ta_insert_dt   IS 'Technical: row creation timestamp.';
COMMENT ON COLUMN bl_cl.mta_load_dates.ta_update_dt   IS 'Technical: timestamp of last load date update.';


-- ============================================================
-- 3. PROCEDURE: prc_update_load_date
--    Updates last_load_dt for a given table.
--    Called at end of each successful incremental load procedure.
-- ============================================================

CREATE OR REPLACE PROCEDURE bl_cl.prc_update_load_date(
    p_table_name    VARCHAR(100),
    p_schema_name   VARCHAR(50),
    p_last_load_dt     TIMESTAMP
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO bl_cl.mta_load_dates (
        table_name,
        schema_name,
        last_load_dt,
        ta_insert_dt,
        ta_update_dt
    )
    VALUES (
        p_table_name,
        p_schema_name,
        p_last_load_dt,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    )
    ON CONFLICT (table_name, schema_name)
    DO UPDATE SET
        last_load_dt = EXCLUDED.last_load_dt,
        ta_update_dt   = CURRENT_TIMESTAMP;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING
            '[prc_update_load_date] Failed to update load date for [%.%]. Error: [%].',
            p_schema_name, p_table_name, SQLERRM;
END;
$$;

COMMENT ON PROCEDURE bl_cl.prc_update_load_date(VARCHAR, VARCHAR, TIMESTAMP) IS
    'Upserts last_load_dt for a target table in mta_load_dates. '
    'Called at end of prc_load_ce_sales and prc_load_ce_customers_scd. '
    'Uses ON CONFLICT (upsert) — safe for initial run (no prior row).';


-- ============================================================
-- 4. FUNCTION: fn_get_last_load_date
--    Returns last_load_dt for a given table.
--    Returns 1900-01-01 if no load date row exists yet.
-- ============================================================

CREATE OR REPLACE FUNCTION bl_cl.fn_get_last_load_date(
    p_table_name    VARCHAR(100),
    p_schema_name   VARCHAR(50)
)
RETURNS TIMESTAMP
LANGUAGE plpgsql AS $$
DECLARE
    v_last_load_dt TIMESTAMP;
BEGIN
    SELECT last_load_dt
    INTO   v_last_load_dt
    FROM   bl_cl.mta_load_dates
    WHERE  table_name  = p_table_name
      AND  schema_name = p_schema_name;

    RETURN COALESCE(v_last_load_dt, TIMESTAMP '1900-01-01 00:00:00');
END;
$$;

COMMENT ON FUNCTION bl_cl.fn_get_last_load_date(VARCHAR, VARCHAR) IS
    'Returns last_load_dt from mta_load_dates for p_table_name/p_schema_name. '
    'Returns 1900-01-01 if no row exists (first run). '
    'Used by prc_load_ce_sales and prc_load_ce_customers_scd.';


-- ============================================================
-- 5. VERIFICATION
-- ============================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'bl_cl'
          AND table_name   = 'mta_load_dates'
    ) THEN
        RAISE NOTICE '[OK] bl_cl.mta_load_dates created.';
    ELSE
        RAISE EXCEPTION '[FAIL] bl_cl.mta_load_dates NOT found.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'bl_cl' AND p.proname = 'prc_update_load_date'
    ) THEN
        RAISE NOTICE '[OK] bl_cl.prc_update_load_date created.';
    ELSE
        RAISE EXCEPTION '[FAIL] bl_cl.prc_update_load_date NOT found.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'bl_cl' AND p.proname = 'fn_get_last_load_date'
    ) THEN
        RAISE NOTICE '[OK] bl_cl.fn_get_last_load_date created.';
    ELSE
        RAISE EXCEPTION '[FAIL] bl_cl.fn_get_last_load_date NOT found.';
    END IF;
END;
$$;