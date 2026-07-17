-- ============================================================
-- Install file_fdw extension and create foreign server
-- ============================================================

-- Step 1: Install file_fdw extension
CREATE EXTENSION IF NOT EXISTS file_fdw;

-- Step 2: Create foreign server
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_foreign_server WHERE srvname = 'file_server'
    ) THEN
        CREATE SERVER file_server
            FOREIGN DATA WRAPPER file_fdw;
        RAISE NOTICE 'Foreign server file_server created.';
    ELSE
        RAISE NOTICE 'Foreign server file_server already exists - skipping.';
    END IF;
END;
$$;