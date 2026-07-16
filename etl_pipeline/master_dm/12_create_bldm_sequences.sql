-- DDL - Sequences (one per table)

-- ============================================================
-- Create all surrogate key sequences for BL_DM DIM_ and FCT_ tables.
-- One dedicated sequence per table.
--
-- SEQUENCES:
--   ┌────────────────────────────────────────────┬──────────────────────────────────────────┐
--   │ Sequence name                              │ Used in table / column                   │
--   ├────────────────────────────────────────────┼──────────────────────────────────────────┤
--   │ bl_dm.seq_dim_time_day                     │ DIM_TIME_DAY.DATE_SURR_ID                │
--   │ bl_dm.seq_dim_payment_types                │ DIM_PAYMENT_TYPES.PAYMENT_TYPE_SURR_ID   │
--   │ bl_dm.seq_dim_employees                    │ DIM_EMPLOYEES.EMPLOYEE_SURR_ID           │
--   │ bl_dm.seq_dim_customers_scd                │ DIM_CUSTOMERS_SCD.CUSTOMER_SURR_ID       │
--   │ bl_dm.seq_dim_products_scd                 │ DIM_PRODUCTS_SCD.PRODUCT_SURR_ID         │
--   │ bl_dm.seq_dim_stores                       │ DIM_STORES.STORE_SURR_ID                 │
--   │ bl_dm.seq_fct_sales_dd                     │ FCT_SALES_DD.SALES_SURR_ID               │
--   └────────────────────────────────────────────┴──────────────────────────────────────────┘
--
-- ============================================================


-- ============================================================
-- 1. CREATE THE SEQUENCES
-- ============================================================

DO $$
DECLARE
    v_seq RECORD;
BEGIN
    FOR v_seq IN
        SELECT * FROM (VALUES
            ('seq_dim_time_day'),
            ('seq_dim_payment_types'),
            ('seq_dim_employees'),
            ('seq_dim_customers_scd'),
            ('seq_dim_products_scd'),
            ('seq_dim_stores'),
            ('seq_fct_sales_dd')
        ) AS t(seq_name)
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM   pg_sequences
            WHERE  schemaname   = 'bl_dm'
              AND  sequencename = v_seq.seq_name
        ) THEN
            EXECUTE format(
                'CREATE SEQUENCE bl_dm.%I
                     START WITH 1
                     INCREMENT BY 1
                     MINVALUE 1
                     NO MAXVALUE
                     CACHE 10',
                v_seq.seq_name
            );
            RAISE NOTICE '[CREATED] bl_dm.%', v_seq.seq_name;
        ELSE
            RAISE NOTICE '[EXISTS] bl_dm.% – skipped.', v_seq.seq_name;
        END IF;
    END LOOP;
END;
$$;


-- ============================================================
-- 2. VERIFICATION
-- ============================================================

DO $$
DECLARE
    v_seq         TEXT;
    v_missing     TEXT    := '';
    v_found_count INTEGER := 0;

    v_expected    TEXT[]  := ARRAY[
        'seq_dim_time_day',
        'seq_dim_payment_types',
        'seq_dim_employees',
        'seq_dim_customers_scd',
        'seq_dim_products_scd',
        'seq_dim_stores',
        'seq_fct_sales_dd'
    ];
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'BL_DM SEQUENCE VERIFICATION';
    RAISE NOTICE '===========================================';

    FOREACH v_seq IN ARRAY v_expected
    LOOP
        IF EXISTS (
            SELECT 1
            FROM   pg_sequences
            WHERE  schemaname   = 'bl_dm'
              AND  sequencename = v_seq
        ) THEN
            v_found_count := v_found_count + 1;
            RAISE NOTICE '  [OK]      bl_dm.%', v_seq;
        ELSE
            v_missing := v_missing || v_seq || ', ';
            RAISE WARNING '  [MISSING] bl_dm.%', v_seq;
        END IF;
    END LOOP;

    RAISE NOTICE '-------------------------------------------';
    RAISE NOTICE '  Verified: % / % sequences present.',
                 v_found_count, array_length(v_expected, 1);

    IF v_missing <> '' THEN
        v_missing := LEFT(v_missing, LENGTH(v_missing) - 2);
        RAISE WARNING 'MISSING sequences: [%]. Re-run Step 1.', v_missing;
    ELSE
        RAISE NOTICE '  All sequences verified OK.';
    END IF;

    RAISE NOTICE '===========================================';
END;
$$;