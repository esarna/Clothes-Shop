-- DDL - Sequences (one per table, per naming convention)

-- ============================================================
-- Create all surrogate key sequences for BL_3NF CE_ tables.
-- One dedicated sequence per table.
--
--
-- SEQUENCES:
--   ┌──────────────────────────────────────────┬──────────────────────────────────┐
--   │ Sequence name                            │ Used in table / column           │
--   ├──────────────────────────────────────────┼──────────────────────────────────┤
--   │ bl_3nf.seq_ce_dates                      │ CE_DATES.DATE_ID                 │
--   │ bl_3nf.seq_ce_store_zones                │ CE_STORE_ZONES.STORE_ZONE_ID     │
--   │ bl_3nf.seq_ce_payment_types              │ CE_PAYMENT_TYPES.PAYMENT_TYPE_ID │
--   │ bl_3nf.seq_ce_product_top_categories     │ CE_PRODUCT_TOP_CATEGORIES        │
--   │ bl_3nf.seq_ce_product_categories         │ CE_PRODUCT_CATEGORIES            │
--   │ bl_3nf.seq_ce_product_subcategories      │ CE_PRODUCT_SUBCATEGORIES         │
--   │ bl_3nf.seq_ce_locations                  │ CE_LOCATIONS.LOCATION_ID         │
--   │ bl_3nf.seq_ce_employees                  │ CE_EMPLOYEES.EMPLOYEE_ID         │
--   │ bl_3nf.seq_ce_stores                     │ CE_STORES.STORE_ID               │
--   │ bl_3nf.seq_ce_customers_scd              │ CE_CUSTOMERS_SCD.CUSTOMER_ID     │
--   │ bl_3nf.seq_ce_products_scd               │ CE_PRODUCTS_SCD.PRODUCT_ID       │
--   │ bl_3nf.seq_ce_sales                      │ CE_SALES.SALE_ID                 │
--   └──────────────────────────────────────────┴──────────────────────────────────┘
--
-- SCD NOTE:
--   SCD Type 2 tables (CE_CUSTOMERS_SCD, CE_PRODUCTS_SCD) use
--   composite PK (_ID + START_DT). Each new SCD2 version of a
--   row consumes a new surrogate key value from the sequence -
--   this is correct and expected behaviour.
--
-- ============================================================


-- ============================================================
-- 1. CREATE THE SEQUENCES
-- ============================================================
DO $$
DECLARE
    v_seq RECORD;
BEGIN
    -- Definition of all the sequences
    FOR v_seq IN
        SELECT * FROM (VALUES
            ('seq_ce_store_zones'),
            ('seq_ce_payment_types'),
            ('seq_ce_product_top_categories'),
            ('seq_ce_product_categories'),
            ('seq_ce_product_subcategories'),
            ('seq_ce_locations'),
            ('seq_ce_employees'),
            ('seq_ce_stores'),
            ('seq_ce_customers_scd'),
            ('seq_ce_products_scd'),
            ('seq_ce_sales')
        ) AS t(seq_name)
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM   pg_sequences
            WHERE  schemaname  = 'bl_3nf'
              AND  sequencename = v_seq.seq_name
        ) THEN
            EXECUTE format(
                'CREATE SEQUENCE bl_3nf.%I
                     START WITH 1
                     INCREMENT BY 1
                     MINVALUE 1
                     NO MAXVALUE
                     CACHE 10',
                v_seq.seq_name
            );
            RAISE NOTICE '[CREATED] bl_3nf.%', v_seq.seq_name;
        ELSE
            RAISE NOTICE '[EXISTS]  bl_3nf.% – skipped.', v_seq.seq_name;
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
 
     -- Canonical list of all 11 expected sequences:
     v_expected    TEXT[]  := ARRAY[
         'seq_ce_store_zones',
         'seq_ce_payment_types',
         'seq_ce_product_top_categories',
         'seq_ce_product_categories',
         'seq_ce_product_subcategories',
         'seq_ce_locations',
         'seq_ce_employees',
         'seq_ce_stores',
         'seq_ce_customers_scd',
         'seq_ce_products_scd',
         'seq_ce_sales'
     ];
 BEGIN
     RAISE NOTICE '===========================================';
     RAISE NOTICE 'BL_3NF SEQUENCE VERIFICATION';
     RAISE NOTICE '===========================================';
 
     FOREACH v_seq IN ARRAY v_expected
     LOOP
         IF EXISTS (
             SELECT 1
             FROM   pg_sequences
             WHERE  schemaname   = 'bl_3nf'
               AND  sequencename = v_seq
         ) THEN
             v_found_count := v_found_count + 1;
             RAISE NOTICE '  [OK]      bl_3nf.%', v_seq;
         ELSE
             v_missing := v_missing || v_seq || ', ';
             RAISE WARNING '  [MISSING] bl_3nf.%', v_seq;
         END IF;
     END LOOP;
 
     RAISE NOTICE '-------------------------------------------';
     RAISE NOTICE '  Verified: % / % sequences present.',
                  v_found_count, array_length(v_expected, 1);
 
     IF v_missing <> '' THEN
         -- Trim trailing ', ' from the missing list
         v_missing := LEFT(v_missing, LENGTH(v_missing) - 2);
         RAISE WARNING 'MISSING sequences: [%]. Re-run Step 1.', v_missing;
     ELSE
         RAISE NOTICE '  All sequences verified OK.';
     END IF;
 
     RAISE NOTICE '===========================================';
 END;
 $$;