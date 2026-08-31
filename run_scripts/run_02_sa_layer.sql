-- ============================================================
-- MASTER SCRIPT 02 — Source Area (SA Layer)
-- External tables + typed source tables + load from CSV
--
-- Run ONCE for initial load.
-- For incremental: re-run from step 3 only (05_load_src_tables)
--
-- Usage:
--   \i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/run_scripts/run_02_sa_layer.sql'
-- ============================================================

\echo '================================================================='
\echo 'STEP 1/4 — SA schemas (idempotent)'
\echo '================================================================='
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/sa_ext_src/01_create_schemas.sql'

\echo '================================================================='
\echo 'STEP 2/4 — file_fdw extension + server setup'
\echo '================================================================='
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/sa_ext_src/02_setup_file_fdw.sql'

\echo '================================================================='
\echo 'STEP 3/4 — External tables (EXT_) over CSV files'
\echo '================================================================='
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/sa_ext_src/03_create_ext_tables.sql'

\echo '================================================================='
\echo 'STEP 4/4 — Typed source tables (SRC_) + load from EXT_'
\echo '================================================================='
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/sa_ext_src/04_create_src_tables.sql'
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/deduplication/05_load_src_tables.sql'

\echo '================================================================='
\echo 'run_02_sa_layer.sql COMPLETED'
\echo '================================================================='