-- ============================================================
-- MASTER SCRIPT — FULL DWH BUILD
-- Builds the entire Clothes Shop DWH from scratch.
--
-- EXECUTION ORDER (critical — do not change):
--
--   01  Infrastructure   (schemas, roles, privileges, BL_CL)
--   02  SA Layer         (file_fdw, EXT_, SRC_, load CSV)
--   03a BL_DM DDL only   (schema + dim_time_day MUST exist
--                          before BL_3NF tables are created
--                          due to FK: ce_sales → dim_time_day)
--   03b BL_3NF           (DDL + ETL load)
--   04  BL_DM ETL        (DIM_ + FCT_ load from BL_3NF)
--   05  DQ Tests         (verify data quality)
--
-- Usage:
--   \i 'h-to-project-/Clothes-Shop/run_scripts/run_ALL.sql'
--
-- Time estimate (initial load ~3000 rows):
--   Full run: < 2 minutes
-- ============================================================

\echo ''
\echo '####################################################################'
\echo '##  CLOTHES SHOP DWH — FULL BUILD START'
\echo '##  ' :CURRENT_TIMESTAMP
\echo '####################################################################'
\echo ''


-- ============================================================
-- PHASE 1 — Infrastructure
-- ============================================================
\echo '================================================================='
\echo 'PHASE 1 — Infrastructure: schemas, roles, privileges, BL_CL'
\echo '================================================================='

\i 'h-to-project-/Clothes-Shop/etl_pipeline/master_dm/00_create_and_populate_dim_time_day.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/master_3NF/00_create_and_populate_ce_dates.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/setup_schema_role/01_create_schemas.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/setup_schema_role/02_create_roles.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/setup_schema_role/03_grant_privileges.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/master_cl/01_create_bl_cl_schema.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/master_cl/02_mta_load_logs.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/master_cl/03_prc_log_procedure.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/master_cl/04_mta_load_dates.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/master_cl/05_create_test_profiling_tables.sql'

\echo 'PHASE 1 DONE'
\echo ''


-- ============================================================
-- PHASE 2 — Source Area (SA Layer)
-- ============================================================
\echo '================================================================='
\echo 'PHASE 2 — SA Layer: file_fdw, EXT_ tables, SRC_ tables, CSV load'
\echo '================================================================='

\i 'h-to-project-/Clothes-Shop/etl_pipeline/sa_ext_src/01_create_schemas.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/sa_ext_src/02_setup_file_fdw.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/sa_ext_src/03_create_ext_tables.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/sa_ext_src/04_create_src_tables.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/deduplication/05_load_src_tables.sql'

\echo 'PHASE 2 DONE'
\echo ''


-- ============================================================
-- PHASE 3 — BL_DM DDL + DIM_TIME_DAY
-- MUST run before BL_3NF tables (FK dependency!)
-- ============================================================
\echo '================================================================='
\echo 'PHASE 3 — BL_DM DDL'
\echo '================================================================='

\i 'h-to-project-/Clothes-Shop/etl_pipeline/master_dm/11_create_bldm_schema.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/master_dm/12_create_bldm_sequences.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/master_dm/13_create_bldm_tables.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/master_dm/14_insert_bldm_default_rows.sql'

\echo 'PHASE 3 DONE'
\echo ''


-- ============================================================
-- PHASE 4 — BL_3NF DDL + ETL Load
-- ============================================================
\echo '================================================================='
\echo 'PHASE 4 — BL_3NF: DDL + fn_get_* + prc_load_* + incremental load'
\echo '================================================================='

\i 'h-to-project-/Clothes-Shop/etl_pipeline/master_3NF/06_create_bl3nf_schema.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/master_3NF/07_create_bl3nf_sequences.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/master_3NF/08_create_bl3nf_tables.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/master_3NF/09_insert_bl3nf_default_rows.sql'
\i 'h-to-project-/Clothes-Shop/etl_pipeline/master_3NF/10_load_bl3nf_tables.sql'

\echo 'PHASE 4 DONE'
\echo ''


-- ============================================================
-- PHASE 5 — BL_DM ETL Load (from BL_3NF)
-- ============================================================
\echo '================================================================='
\echo 'PHASE 5 — BL_DM ETL: DIM_ + FCT_ load from BL_3NF'
\echo '================================================================='

\i 'h-to-project-/Clothes-Shop/etl_pipeline/master_dm/15_load_bldm_tables.sql'

\echo 'PHASE 5 DONE'
\echo ''


-- -- ============================================================
-- -- PHASE 6 — Data Quality Tests
-- -- ============================================================
-- \echo '================================================================='
-- \echo 'PHASE 6 — DQ Tests: DQ/ETL/schema/security/ad hoc suite (bl_cl.test_results)'
-- \echo '================================================================='

-- \i 'h-to-project-/Clothes-Shop/dq_checks/tests/10_tests_run_all.sql'

-- \echo 'PHASE 6 DONE'
-- \echo ''


-- -- ============================================================
-- -- PHASE 7 — Data Profiling
-- -- ============================================================
-- \echo '================================================================='
-- \echo 'PHASE 7 — Data Profiling: descriptive metrics (bl_cl.profiling_metrics)'
-- \echo '================================================================='

-- \i 'h-to-project-/Clothes-Shop/dq_checks/data_profiling/45_profiling_run_all.sql'

-- \echo 'PHASE 7 DONE'
-- \echo ''


\echo '####################################################################'
\echo '##  CLOTHES SHOP DWH — FULL BUILD COMPLETED SUCCESSFULLY'
\echo '####################################################################'