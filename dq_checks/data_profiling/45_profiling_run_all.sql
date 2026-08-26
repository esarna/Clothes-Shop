-- ============================================================
-- PROFILING SUITE - MASTER ORCHESTRATOR
-- Runs all profiling groups in order. Results are persisted to
-- bl_cl.profiling_metrics; no pass/fail concept, no exceptions bubble up
-- (each metric is wrapped by bl_cl.fn_log_profile_safe).
-- ============================================================

\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/dq_checks/data_profiling/40_profiling_source.sql'
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/dq_checks/data_profiling/41_profiling_sa.sql'
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/dq_checks/data_profiling/42_profiling_bl3nf.sql'
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/dq_checks/data_profiling/43_profiling_bldm.sql'
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/dq_checks/data_profiling/44_profiling_cross_layer.sql'

SELECT layer, COUNT(*) AS metric_count
FROM   bl_cl.profiling_metrics
WHERE  executed_at >= CURRENT_DATE
GROUP BY layer
ORDER BY layer;
