-- ============================================================
-- DQ TEST SUITE - MASTER ORCHESTRATOR
-- Runs all DQ/ETL/schema/security/ad-hoc test groups in order.
-- Results are persisted to bl_cl.test_results by every test group.
-- ============================================================

\i 'h-to-project-/Clothes-Shop/dq_checks/tests/01_test_no_duplicates_bl3nf.sql'
\i 'h-to-project-/Clothes-Shop/dq_checks/tests/02_test_sa_coverage_bl3nf.sql'
\i 'h-to-project-/Clothes-Shop/dq_checks/tests/03_test_no_duplicates_bldm.sql'
\i 'h-to-project-/Clothes-Shop/dq_checks/tests/04_test_3nf_coverage_bldm.sql'
\i 'h-to-project-/Clothes-Shop/dq_checks/tests/05_test_restartability.sql'
\i 'h-to-project-/Clothes-Shop/dq_checks/tests/06_tests_source_sa.sql'
\i 'h-to-project-/Clothes-Shop/dq_checks/tests/07_tests_bl3nf.sql'
\i 'h-to-project-/Clothes-Shop/dq_checks/tests/08_tests_bldm.sql'
\i 'h-to-project-/Clothes-Shop/dq_checks/tests/09_tests_schema_security_adhoc.sql'

SELECT
    status,
    COUNT(*) AS test_count
FROM   bl_cl.test_results
WHERE  executed_at >= CURRENT_DATE
GROUP BY status;
