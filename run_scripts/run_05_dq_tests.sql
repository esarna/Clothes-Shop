-- ============================================================
-- MASTER SCRIPT 05 — Data Quality Tests
-- Run AFTER full load to verify data integrity.
-- All results are persisted to bl_cl.test_results.
--
-- Usage:
--   \i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/run_scripts/run_05_dq_tests.sql'
-- ============================================================

\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/dq_checks/tests/10_tests_run_all.sql'

\echo '================================================================='
\echo 'run_05_dq_tests.sql COMPLETED — see bl_cl.test_results for detail'
\echo '================================================================='