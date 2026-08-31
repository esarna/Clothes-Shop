-- ============================================================
-- MASTER SCRIPT 03 — BL_3NF Layer
-- DDL (schema, sequences, tables, default rows) +
-- ETL functions/procedures + incremental load execution
--
-- CRITICAL dependency:
--   BL_DM schema + dim_time_day MUST exist before this script
--   because ce_sales has FK → bl_dm.dim_time_day.
--   Run run_04_bldm_ddl_only.sql first on fresh environment,
--   OR run run_ALL.sql which handles correct order.
--
-- Usage:
--   \i '-path-to-project-/Clothes-Shop/run_scripts/run_03_bl3nf.sql'
-- ============================================================
\i '-path-to-project-/Clothes-Shop/etl_pipeline/master_dm/00_create_and_populate_dim_time_day.sql'
\echo '================================================================='
\echo 'STEP 1/5 — BL_3NF schema'
\echo '================================================================='
\i '-path-to-project-/Clothes-Shop/etl_pipeline/master_3NF/06_create_bl3nf_schema.sql'

\echo '================================================================='
\echo 'STEP 2/5 — BL_3NF sequences'
\echo '================================================================='
\i '-path-to-project-/Clothes-Shop/etl_pipeline/master_3NF/07_create_bl3nf_sequences.sql'

\echo '================================================================='
\echo 'STEP 3/5 — BL_3NF tables DDL'
\echo '================================================================='
\i '-path-to-project-/Clothes-Shop/etl_pipeline/master_3NF/08_create_bl3nf_tables.sql'

\echo '================================================================='
\echo 'STEP 4/5 — BL_3NF default rows (-1)'
\echo '================================================================='
\i '-path-to-project-/Clothes-Shop/etl_pipeline/master_3NF/09_insert_bl3nf_default_rows.sql'

\echo '================================================================='
\echo 'STEP 5/5 — BL_3NF ETL: create fn_get_* + prc_load_* + EXECUTE LOAD'
\echo '           (calls prc_master_load_bl3nf() at end of script)'
\echo '================================================================='
\i '-path-to-project-/Clothes-Shop/etl_pipeline/master_3NF/10_load_bl3nf_tables.sql'

\echo '================================================================='
\echo 'run_03_bl3nf.sql COMPLETED'
\echo '================================================================='