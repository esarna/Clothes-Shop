-- ============================================================
-- MASTER SCRIPT 01 — Infrastructure Setup
-- Schemas, roles, privileges, BL_CL ETL engine
--
-- Run ONCE on fresh environment.
-- Idempotent — safe to re-run (IF NOT EXISTS guards).
--
-- Usage:
--   \i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/run_scripts/run_01_setup.sql'
-- ============================================================

\echo '================================================================='
\echo 'STEP 1/3 — Creating DWH schemas'
\echo '================================================================='
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/master_dm/00_create_and_populate_dim_time_day.sql'
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/master_3NF/00_create_and_populate_ce_dates.sql'
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/setup_schema_role/01_create_schemas.sql'

\echo '================================================================='
\echo 'STEP 2/3 — Creating DWH roles'
\echo '================================================================='
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/setup_schema_role/02_create_roles.sql'

\echo '================================================================='
\echo 'STEP 3/3 — Granting privileges'
\echo '================================================================='
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/setup_schema_role/03_grant_privileges.sql'

\echo '================================================================='
\echo 'STEP 4/4 — BL_CL schema + logging infrastructure'
\echo '================================================================='
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/master_cl/01_create_bl_cl_schema.sql'
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/master_cl/02_mta_load_logs.sql'
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/master_cl/03_prc_log_procedure.sql'
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/master_cl/04_mta_load_dates.sql'

\echo '================================================================='
\echo 'run_01_setup.sql COMPLETED'
\echo '================================================================='