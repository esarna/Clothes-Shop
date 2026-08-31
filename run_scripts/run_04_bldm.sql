-- ============================================================
-- MASTER SCRIPT 04 — BL_DM Layer
-- DDL (schema, sequences, tables, default rows) +
-- DIM_TIME_DAY population + ETL load
--
-- Usage:
--   \i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/run_scripts/run_04_bldm.sql'
-- ============================================================
\echo '================================================================='
\echo 'STEP 5/6 — DIM_TIME_DAY population (GENERATE_SERIES 2010-2040)'
\echo '           Idempotent — safe to re-run (NOT EXISTS guard)'
\echo '================================================================='
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/master_dm/00_create_and_populate_dim_time_day.sql'

\echo '================================================================='
\echo 'STEP 1/6 — BL_DM schema'
\echo '================================================================='
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/master_dm/11_create_bldm_schema.sql'

\echo '================================================================='
\echo 'STEP 2/6 — BL_DM sequences'
\echo '================================================================='
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/master_dm/12_create_bldm_sequences.sql'

\echo '================================================================='
\echo 'STEP 3/6 — BL_DM tables DDL'
\echo '================================================================='
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/master_dm/13_create_bldm_tables.sql'

\echo '================================================================='
\echo 'STEP 4/6 — BL_DM default rows (-1)'
\echo '================================================================='
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/master_dm/14_insert_bldm_default_rows.sql'

\echo '================================================================='
\echo 'STEP 6/6 — BL_DM ETL load (15_load_bldm_tables.sql)'
\echo '================================================================='
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/master_dm/15_load_bldm_tables.sql'

\echo '================================================================='
\echo 'run_04_bldm.sql COMPLETED'
\echo '================================================================='