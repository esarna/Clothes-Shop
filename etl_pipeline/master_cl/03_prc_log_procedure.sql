-- ============================================================
-- DDL - BL_CL: ETL Execution Logging Procedure
--
-- PARAMETERS:
--   p_procedure_name  VARCHAR  — name of the calling procedure
--   p_rows_inserted   INTEGER  — rows inserted this execution
--   p_rows_updated    INTEGER  — rows updated this execution
--   p_status          VARCHAR  — 'SUCCESS' or 'ERROR'
--   p_message         TEXT     — NULL on success / SQLERRM on error
--   p_source_system   VARCHAR  — source system context (optional)
--   p_source_entity   VARCHAR  — source entity context (optional)
--
-- ============================================================


CREATE OR REPLACE PROCEDURE bl_cl.prc_log_procedure(
    p_procedure_name    VARCHAR(200),
    p_rows_inserted     INTEGER     DEFAULT 0,
    p_rows_updated      INTEGER     DEFAULT 0,
    p_status            VARCHAR(10) DEFAULT 'SUCCESS',
    p_message           TEXT        DEFAULT NULL,
    p_source_system     VARCHAR(100) DEFAULT 'n/a',
    p_source_entity     VARCHAR(100) DEFAULT 'n/a'
)
LANGUAGE plpgsql
AS $$
-- ============================================================
-- DESCRIPTION:
--   Inserts one audit row into bl_cl.mta_load_logs.
--   Wraps the INSERT in its own EXCEPTION block so that a
--   logging failure never propagates to the caller.
--
-- USAGE EXAMPLES:
--
--   -- On SUCCESS (end of normal procedure flow):
--   CALL bl_cl.prc_log_procedure(
--       p_procedure_name => 'prc_load_ce_store_zones',
--       p_rows_inserted  => v_rows_inserted,
--       p_rows_updated   => v_rows_updated,
--       p_status         => 'SUCCESS'
--   );
--
--   -- On ERROR (inside EXCEPTION WHEN OTHERS block):
--   CALL bl_cl.prc_log_procedure(
--       p_procedure_name => 'prc_load_ce_store_zones',
--       p_rows_inserted  => 0,
--       p_rows_updated   => 0,
--       p_status         => 'ERROR',
--       p_message        => SQLERRM
--   );
-- ============================================================
BEGIN

    INSERT INTO bl_cl.mta_load_logs (
        log_id,
        ta_log_dt,
        procedure_name,
        rows_inserted,
        rows_updated,
        status,
        message,
        source_system,
        source_entity
    )
    VALUES (
        nextval('bl_cl.seq_mta_load_logs'),
        CURRENT_TIMESTAMP,
        p_procedure_name,
        COALESCE(p_rows_inserted, 0),
        COALESCE(p_rows_updated,  0),
        p_status,
        p_message,
        COALESCE(p_source_system, 'n/a'),
        COALESCE(p_source_entity, 'n/a')
    );

EXCEPTION
    -- ── Logging must NEVER fail silently or mask ETL errors ──
    -- If the INSERT above fails (e.g. table missing, sequence
    -- exhausted), emit a WARNING and return gracefully.
    -- The caller's EXCEPTION block will still re-raise the
    -- original ETL error — the log failure is secondary.
    WHEN OTHERS THEN
        RAISE WARNING
            '[prc_log_procedure] Failed to write log row for procedure [%]. '
            'Status attempted: [%]. Log error: [%].',
            p_procedure_name,
            p_status,
            SQLERRM;
END;
$$;


-- ============================================================
-- OBJECT COMMENT
-- ============================================================

COMMENT ON PROCEDURE bl_cl.prc_log_procedure(
    VARCHAR, INTEGER, INTEGER, VARCHAR, TEXT, VARCHAR, VARCHAR
) IS
    'Central ETL audit logging procedure. '
    'Inserts one row into bl_cl.mta_load_logs per call. '
    'Called by every prc_load_* and prc_master_load_* procedure '
    'on both SUCCESS and ERROR paths. '
    'Never raises — logging failures are emitted as WARNING only '
    'so they do not mask original ETL errors. '
    'All parameters except p_procedure_name have DEFAULT values.';