-- Tylko to co się zmienia przy każdym kolejnym ładowaniu:

-- 1. Odśwież SA (nowe CSV)
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/deduplication/05_load_src_tables.sql'

-- 2. Załaduj BL_3NF (incremental - procedury same wykryją co nowe)
-- (już wywołane wewnątrz 10_load_bl3nf_tables.sql przez CALL prc_master_load_bl3nf())
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/master_3NF/10_load_bl3nf_tables.sql'

-- 3. Załaduj BL_DM
\i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/etl_pipeline/master_dm/15_load_bldm_tables.sql'

-- 4. Sprawdź DQ
-- \i 'C:/Users/EmiliaSarna/Projects/Clothes-Shop/run_scripts/run_05_dq_tests.sql'