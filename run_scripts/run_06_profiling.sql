-- ============================================================
-- MASTER SCRIPT 06 — Data Profiling
-- Run AFTER full load to collect descriptive profiling metrics.
-- All metrics are persisted to bl_cl.profiling_metrics.
--
-- Usage:
--   \i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/run_scripts/run_06_profiling.sql'
-- ============================================================

\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/dq_checks/data_profiling/45_profiling_run_all.sql'

\echo '================================================================='
\echo 'run_06_profiling.sql COMPLETED — see bl_cl.profiling_metrics for detail'
\echo '================================================================='
