-- DML - ETL: BL_3NF Incremental Load — all CE_ tables
-- Load order (respects FK dependencies):
-- CE_PAYMENT_TYPES - from UNION of both src_ tables (payment_method / payment_type)
-- CE_STORE_ZONES - from sa_retail.src_retail_sales (zone_code) + manual 'N/A' for ecom
-- CE_PRODUCT_TOP_CATEGORIES - from sa_retail.src_retail_sales (top_category); 'N/A' for ecom
-- CE_PRODUCT_CATEGORIES - from both src_ tables (category / product_type)
-- CE_PRODUCT_SUBCATEGORIES - from both src_ tables (subcategory / details)
-- CE_LOCATIONS - from all address sources (store, customer, employee from both src_ tables)
-- CE_STORES - from sa_retail.src_retail_sales (store_code) + single 'ECOMMERCE' row for ecom
-- CE_EMPLOYEES - from both src_ tables (employee_id / ee_id)
-- CE_CUSTOMERS_SCD - from both src_ tables (customer_id / user_id) SCD2 logic
-- CE_PRODUCTS_SCD - from both src_ tables (product_code) SCD2 logic
-- CE_SALES - from both src_ tables, Last - depends on all dimensions
-- ===========================================
--
--
-- SOURCES:
--   SA_RETAIL  →  sa_retail.src_retail_sales
--   SA_ECOM    →  sa_ecom.src_ecom_sales
--
-- KEY DESIGN RULES:
--
--   1. LEFT JOIN for all dimension lookups in CE_SALES
--      (never INNER JOIN - must preserve all source rows).
--
--   2. COALESCE(fk_lookup_result, -1) for every FK column
--      in CE_SALES → maps unresolved lookups to default row.
--
--   3. COALESCE(src_value, 'n/a') for all NOT NULL text columns
--      in dimension tables → prevents NOT NULL violations.
--
--   4. NOT EXISTS guard on every INSERT → zero duplicates.
--
--   5. FK to SCD2 tables (CE_CUSTOMERS_SCD, CE_PRODUCTS_SCD)
--      in CE_SALES: LOGICAL ONLY - COALESCE to -1 when no
--      active row found for the transaction date.
--
--   6. SCD2 logic:
--      a. Detect changed rows (current active version exists
--         but tracked attributes differ from source).
--      b. Close previous version:
--         SET end_dt = CURRENT_DATE - 1, is_active = 'N'
--      c. Insert new version:
--         new surrogate key from sequence, start_dt = CURRENT_DATE
--         end_dt = DATE '9999-12-31', is_active = 'Y'
--      d. Insert brand-new rows (NK not yet in target at all).
--
--   7. COST (KPI) handling:
--      cost is monetary → loaded into CE_SALES.cost
--
--   8. NET_AMOUNT calculation (for reference - computed in
--      BL_DM FCT layer, not stored in CE_SALES):
--      RETAIL: line_item_amount – bill_discount
--      ECOM:   sales_amount directly (discount already applied)
--
--   9. STRUCTURE: each table has:
--      • bl_cl.fn_get_ce_<table>()    RETURNS TABLE — data extraction
--      • bl_cl.prc_load_ce_<table>()  PROCEDURE     — FOR LOOP + logging
--
-- ============================================================


-- ============================================================
-- GROUP 1 - SCD TYPE 0: Immutable reference tables
--           Append-only: INSERT new NKs, never UPDATE.
--           No TA_UPDATE_DT column on these tables.
-- ============================================================

-- ------------------------------------------------------------
-- 1.2  CE_STORE_ZONES
--      Sources: zone_code from SA_RETAIL only
--               ecom has no zone → 'N/A' inserted as reference
--      NK:      UPPER(TRIM(zone_code))
--      Guard:   NOT EXISTS on store_zone_src_id
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION bl_cl.fn_get_ce_store_zones()
RETURNS TABLE (
    store_zone_src_id   VARCHAR,
    store_zone_name     VARCHAR,
    source_system       VARCHAR,
    source_entity       VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        UPPER(TRIM(zone_code))::VARCHAR,
        INITCAP(TRIM(zone_code))::VARCHAR,
        'SA_RETAIL'::VARCHAR,
        'SRC_RETAIL_SALES'::VARCHAR
    FROM sa_retail.src_retail_sales
    WHERE zone_code IS NOT NULL
      AND TRIM(zone_code) <> ''

    UNION

    SELECT
        'n/a'::VARCHAR,
        'n/a'::VARCHAR,
        'SA_ECOM'::VARCHAR,
        'SRC_ECOM_SALES'::VARCHAR;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_store_zones()
LANGUAGE plpgsql AS $$
DECLARE
    v_rec           RECORD;
    v_rows_inserted INTEGER := 0;
    v_rows_updated  INTEGER := 0;
    v_delta         INTEGER := 0;
BEGIN
    FOR v_rec IN (SELECT * FROM bl_cl.fn_get_ce_store_zones())
    LOOP
        INSERT INTO bl_3nf.ce_store_zones (
            store_zone_id,
            store_zone_src_id,
            store_zone_name,
            ta_insert_dt,
            source_system,
            source_entity
        )
        SELECT
            nextval('bl_3nf.seq_ce_store_zones'),
            v_rec.store_zone_src_id,
            v_rec.store_zone_name,
            CURRENT_TIMESTAMP,
            v_rec.source_system,
            v_rec.source_entity
        WHERE NOT EXISTS (
            SELECT 1
            FROM   bl_3nf.ce_store_zones tgt
            WHERE  tgt.store_zone_src_id = v_rec.store_zone_src_id
        );
        GET DIAGNOSTICS v_delta = ROW_COUNT;
        v_rows_inserted := v_rows_inserted + v_delta;
    END LOOP;

    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_store_zones',
        p_rows_inserted  => v_rows_inserted,
        p_rows_updated   => v_rows_updated,
        p_status         => 'SUCCESS',
        p_source_system  => 'SA_RETAIL/SA_ECOM',
        p_source_entity  => 'SRC_RETAIL_SALES/SRC_ECOM_SALES'
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_store_zones',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'ERROR',
        p_message        => SQLERRM
    );
    RAISE;
END;
$$;


-- ------------------------------------------------------------
-- 1.3  CE_PAYMENT_TYPES
--      Sources: payment_method (SA_RETAIL) + payment_type (SA_ECOM)
--      NK:      UPPER(TRIM(payment_method / payment_type))
--      Guard:   NOT EXISTS on payment_type_src_id
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION bl_cl.fn_get_ce_payment_types()
RETURNS TABLE (
    payment_type_src_id VARCHAR,
    payment_type_name   VARCHAR,
    source_system       VARCHAR,
    source_entity       VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ON (payment_type_src_id)
        combined.payment_type_src_id,
        combined.payment_type_name,
        combined.source_system,
        combined.source_entity
    FROM (
        SELECT DISTINCT
            UPPER(TRIM(payment_method))::VARCHAR     AS payment_type_src_id,
            INITCAP(TRIM(payment_method))::VARCHAR   AS payment_type_name,
            'SA_RETAIL'::VARCHAR                     AS source_system,
            'SRC_RETAIL_SALES'::VARCHAR              AS source_entity
        FROM sa_retail.src_retail_sales
        WHERE payment_method IS NOT NULL
          AND TRIM(payment_method) <> ''

        UNION ALL

        SELECT DISTINCT
            UPPER(TRIM(payment_type))::VARCHAR       AS payment_type_src_id,
            INITCAP(TRIM(payment_type))::VARCHAR     AS payment_type_name,
            'SA_ECOM'::VARCHAR                       AS source_system,
            'SRC_ECOM_SALES'::VARCHAR                AS source_entity
        FROM sa_ecom.src_ecom_sales
        WHERE payment_type IS NOT NULL
          AND TRIM(payment_type) <> ''
    ) combined
    ORDER BY payment_type_src_id, source_system;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_payment_types()
LANGUAGE plpgsql AS $$
DECLARE
    v_rec           RECORD;
    v_rows_inserted INTEGER := 0;
    v_rows_updated  INTEGER := 0;
    v_delta         INTEGER := 0;
BEGIN
    FOR v_rec IN (SELECT * FROM bl_cl.fn_get_ce_payment_types())
    LOOP
        INSERT INTO bl_3nf.ce_payment_types (
            payment_type_id,
            payment_type_src_id,
            payment_type_name,
            ta_insert_dt,
            source_system,
            source_entity
        )
        SELECT
            nextval('bl_3nf.seq_ce_payment_types'),
            v_rec.payment_type_src_id,
            v_rec.payment_type_name,
            CURRENT_TIMESTAMP,
            v_rec.source_system,
            v_rec.source_entity
        WHERE NOT EXISTS (
            SELECT 1
            FROM   bl_3nf.ce_payment_types tgt
            WHERE  tgt.payment_type_src_id = v_rec.payment_type_src_id
        );
        GET DIAGNOSTICS v_delta = ROW_COUNT;
        v_rows_inserted := v_rows_inserted + v_delta;
    END LOOP;

    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_payment_types',
        p_rows_inserted  => v_rows_inserted,
        p_rows_updated   => v_rows_updated,
        p_status         => 'SUCCESS',
        p_source_system  => 'SA_RETAIL/SA_ECOM',
        p_source_entity  => 'SRC_RETAIL_SALES/SRC_ECOM_SALES'
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_payment_types',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'ERROR',
        p_message        => SQLERRM
    );
    RAISE;
END;
$$;


-- ============================================================
-- GROUP 2 - SCD TYPE 1: Product category hierarchy
--           INSERT new rows + UPDATE existing rows on change.
--           Load order: top-down (parent before child).
-- ============================================================

-- ------------------------------------------------------------
-- 2.1  CE_PRODUCT_TOP_CATEGORIES
--      Sources: top_category from SA_RETAIL only
--               ecom has no top_category → ecom products get
--               FK = -1 (default row) in CE_PRODUCTS_SCD
--      NK:      UPPER(TRIM(top_category))
--      SCD1:    UPDATE product_top_category_name on change
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION bl_cl.fn_get_ce_product_top_categories()
RETURNS TABLE (
    product_top_category_src_id VARCHAR,
    product_top_category_name   VARCHAR,
    source_system               VARCHAR,
    source_entity               VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        UPPER(TRIM(top_category))::VARCHAR,
        INITCAP(TRIM(top_category))::VARCHAR,
        'SA_RETAIL'::VARCHAR,
        'SRC_RETAIL_SALES'::VARCHAR
    FROM sa_retail.src_retail_sales
    WHERE top_category IS NOT NULL
      AND TRIM(top_category) <> '';
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_product_top_categories()
LANGUAGE plpgsql AS $$
DECLARE
    v_rec           RECORD;
    v_rows_inserted INTEGER := 0;
    v_rows_updated  INTEGER := 0;
    v_delta         INTEGER := 0;
BEGIN
    -- INSERT new top categories not yet in target
    FOR v_rec IN (SELECT * FROM bl_cl.fn_get_ce_product_top_categories())
    LOOP
        INSERT INTO bl_3nf.ce_product_top_categories (
            product_top_category_id,
            product_top_category_src_id,
            product_top_category_name,
            ta_insert_dt,
            ta_update_dt,
            source_system,
            source_entity
        )
        SELECT
            nextval('bl_3nf.seq_ce_product_top_categories'),
            v_rec.product_top_category_src_id,
            v_rec.product_top_category_name,
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP,
            v_rec.source_system,
            v_rec.source_entity
        WHERE NOT EXISTS (
            SELECT 1
            FROM   bl_3nf.ce_product_top_categories tgt
            WHERE  tgt.product_top_category_src_id = v_rec.product_top_category_src_id
            AND tgt.source_system = v_rec.source_system
        );
        GET DIAGNOSTICS v_delta = ROW_COUNT;
        v_rows_inserted := v_rows_inserted + v_delta;
    END LOOP;

    -- UPDATE existing top categories if name changed (SCD Type 1)
    UPDATE bl_3nf.ce_product_top_categories tgt
    SET
        product_top_category_name = src.product_top_category_name,
        ta_update_dt              = CURRENT_TIMESTAMP,
        source_system             = src.source_system,
        source_entity             = src.source_entity
    FROM (
        SELECT DISTINCT
            UPPER(TRIM(top_category))       AS product_top_category_src_id,
            INITCAP(TRIM(top_category))     AS product_top_category_name,
            'SA_RETAIL'                     AS source_system,
            'SRC_RETAIL_SALES'              AS source_entity
        FROM sa_retail.src_retail_sales
        WHERE top_category IS NOT NULL
          AND TRIM(top_category) <> ''
    ) src
    WHERE tgt.product_top_category_src_id = src.product_top_category_src_id
        AND tgt.source_system = src.source_system
        AND tgt.product_top_category_id    > 0   -- never update default row
        AND tgt.product_top_category_name  <> src.product_top_category_name;
    GET DIAGNOSTICS v_delta = ROW_COUNT;
    v_rows_updated := v_rows_updated + v_delta;

    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_product_top_categories',
        p_rows_inserted  => v_rows_inserted,
        p_rows_updated   => v_rows_updated,
        p_status         => 'SUCCESS',
        p_source_system  => 'SA_RETAIL',
        p_source_entity  => 'SRC_RETAIL_SALES'
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_product_top_categories',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'ERROR',
        p_message        => SQLERRM
    );
    RAISE;
END;
$$;


-- ------------------------------------------------------------
-- 2.2  CE_PRODUCT_CATEGORIES
--      Sources: category (SA_RETAIL) + product_type (SA_ECOM)
--      NK:      UPPER(TRIM(category / product_type))
--      FK:      product_top_category_id → CE_PRODUCT_TOP_CATEGORIES
--               COALESCE to -1 for ecom (no top_category in source)
--      SCD1:    UPDATE name + FK on change
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION bl_cl.fn_get_ce_product_categories()
RETURNS TABLE (
    product_category_src_id VARCHAR,
    product_category_name   VARCHAR,
    top_category_src_id     VARCHAR,
    source_system           VARCHAR,
    source_entity           VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
        -- Retail categories (with top_category)
        SELECT DISTINCT
            UPPER(TRIM(r.category))::VARCHAR         AS product_category_src_id,
            INITCAP(TRIM(r.category))::VARCHAR       AS product_category_name,
            UPPER(TRIM(r.top_category))::VARCHAR     AS top_category_src_id,
            'SA_RETAIL'::VARCHAR                     AS source_system,
            'SRC_RETAIL_SALES'::VARCHAR              AS source_entity
        FROM sa_retail.src_retail_sales r
        WHERE r.category IS NOT NULL
        AND TRIM(r.category) <> ''
    
        UNION ALL
    
        -- Ecom categories (no top_category)
        SELECT DISTINCT
            UPPER(TRIM(e.product_type))::VARCHAR     AS product_category_src_id,
            INITCAP(TRIM(e.product_type))::VARCHAR   AS product_category_name,
            NULL::VARCHAR                            AS top_category_src_id,
            'SA_ECOM'::VARCHAR                       AS source_system,
            'SRC_ECOM_SALES'::VARCHAR                AS source_entity
        FROM sa_ecom.src_ecom_sales e
        WHERE e.product_type IS NOT NULL
        AND TRIM(e.product_type) <> '';
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_product_categories()
LANGUAGE plpgsql AS $$
DECLARE
    v_rec           RECORD;
    v_rows_inserted INTEGER := 0;
    v_rows_updated  INTEGER := 0;
    v_delta         INTEGER := 0;
BEGIN
    -- INSERT new categories not yet in target
    FOR v_rec IN (SELECT * FROM bl_cl.fn_get_ce_product_categories())
    LOOP
        INSERT INTO bl_3nf.ce_product_categories (
            product_category_id,
            product_category_src_id,
            product_category_name,
            product_top_category_id,
            ta_insert_dt,
            ta_update_dt,
            source_system,
            source_entity
        )
        SELECT
            nextval('bl_3nf.seq_ce_product_categories'),
            v_rec.product_category_src_id,
            v_rec.product_category_name,
            COALESCE(top.product_top_category_id, -1),
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP,
            v_rec.source_system,
            v_rec.source_entity
        FROM (SELECT 1) dummy
        -- LEFT JOIN to resolve parent FK (ecom → NULL → COALESCE -1)
        LEFT JOIN bl_3nf.ce_product_top_categories top
               ON top.product_top_category_src_id = v_rec.top_category_src_id
        WHERE NOT EXISTS (
            SELECT 1
            FROM   bl_3nf.ce_product_categories tgt
            WHERE  tgt.product_category_src_id = v_rec.product_category_src_id
            AND  tgt.source_system            = v_rec.source_system
         );
        GET DIAGNOSTICS v_delta = ROW_COUNT;
        v_rows_inserted := v_rows_inserted + v_delta;
    END LOOP;

    -- UPDATE existing categories if name or parent FK changed (SCD Type 1)
    UPDATE bl_3nf.ce_product_categories tgt
    SET
        product_category_name       = src.product_category_name,
        product_top_category_id     = COALESCE(top.product_top_category_id, -1),
        ta_update_dt                = CURRENT_TIMESTAMP,
        source_system               = src.source_system,
        source_entity               = src.source_entity
     FROM (
            SELECT DISTINCT
                UPPER(TRIM(r.category))         AS product_category_src_id,
                INITCAP(TRIM(r.category))       AS product_category_name,
                UPPER(TRIM(r.top_category))     AS top_category_src_id,
                'SA_RETAIL'                     AS source_system,
                'SRC_RETAIL_SALES'              AS source_entity
            FROM sa_retail.src_retail_sales r
            WHERE r.category IS NOT NULL AND TRIM(r.category) <> ''
    
            UNION ALL
    
            SELECT DISTINCT
                UPPER(TRIM(e.product_type))     AS product_category_src_id,
                INITCAP(TRIM(e.product_type))   AS product_category_name,
                NULL                            AS top_category_src_id,
                'SA_ECOM'                       AS source_system,
                'SRC_ECOM_SALES'                AS source_entity
            FROM sa_ecom.src_ecom_sales e
            WHERE e.product_type IS NOT NULL AND TRIM(e.product_type) <> ''
     ) src
    LEFT JOIN bl_3nf.ce_product_top_categories top
           ON top.product_top_category_src_id = src.top_category_src_id
    WHERE tgt.product_category_src_id = src.product_category_src_id
        AND tgt.source_system            = src.source_system
        AND tgt.product_category_id    > 0
        AND (
                tgt.product_category_name   <> src.product_category_name
            OR tgt.product_top_category_id <> COALESCE(top.product_top_category_id, -1)
        );
    GET DIAGNOSTICS v_delta = ROW_COUNT;
    v_rows_updated := v_rows_updated + v_delta;

    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_product_categories',
        p_rows_inserted  => v_rows_inserted,
        p_rows_updated   => v_rows_updated,
        p_status         => 'SUCCESS',
        p_source_system  => 'SA_RETAIL/SA_ECOM',
        p_source_entity  => 'SRC_RETAIL_SALES/SRC_ECOM_SALES'
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_product_categories',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'ERROR',
        p_message        => SQLERRM
    );
    RAISE;
END;
$$;


-- ------------------------------------------------------------
-- 2.3  CE_PRODUCT_SUBCATEGORIES
--      Sources: subcategory (SA_RETAIL) + details (SA_ECOM)
--      NK:      UPPER(TRIM(subcategory / details))
--      FK:      product_category_id → CE_PRODUCT_CATEGORIES
--               resolved via category NK; COALESCE to -1 if missing
--      SCD1:    UPDATE name + FK on change
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION bl_cl.fn_get_ce_product_subcategories()
RETURNS TABLE (
    product_subcategory_src_id  VARCHAR,
    product_subcategory_name    VARCHAR,
    category_src_id             VARCHAR,
    source_system               VARCHAR,
    source_entity               VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
        SELECT DISTINCT
            UPPER(TRIM(r.subcategory))::VARCHAR      AS product_subcategory_src_id,
            INITCAP(TRIM(r.subcategory))::VARCHAR    AS product_subcategory_name,
            UPPER(TRIM(r.category))::VARCHAR         AS category_src_id,
            'SA_RETAIL'::VARCHAR                     AS source_system,
            'SRC_RETAIL_SALES'::VARCHAR              AS source_entity
        FROM sa_retail.src_retail_sales r
        WHERE r.subcategory IS NOT NULL
        AND TRIM(r.subcategory) <> ''
    
        UNION ALL
    
        SELECT DISTINCT
            UPPER(TRIM(e.details))::VARCHAR          AS product_subcategory_src_id,
            INITCAP(TRIM(e.details))::VARCHAR        AS product_subcategory_name,
            UPPER(TRIM(e.product_type))::VARCHAR     AS category_src_id,
            'SA_ECOM'::VARCHAR                       AS source_system,
            'SRC_ECOM_SALES'::VARCHAR                AS source_entity
        FROM sa_ecom.src_ecom_sales e
        WHERE e.details IS NOT NULL
        AND TRIM(e.details) <> '';
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_product_subcategories()
LANGUAGE plpgsql AS $$
DECLARE
    v_rec           RECORD;
    v_rows_inserted INTEGER := 0;
    v_rows_updated  INTEGER := 0;
    v_delta         INTEGER := 0;
BEGIN
    -- INSERT new subcategories not yet in target
    FOR v_rec IN (SELECT * FROM bl_cl.fn_get_ce_product_subcategories())
    LOOP
        INSERT INTO bl_3nf.ce_product_subcategories (
            product_subcategory_id,
            product_subcategory_src_id,
            product_subcategory_name,
            product_category_id,
            ta_insert_dt,
            ta_update_dt,
            source_system,
            source_entity
        )
        SELECT
            nextval('bl_3nf.seq_ce_product_subcategories'),
            v_rec.product_subcategory_src_id,
            v_rec.product_subcategory_name,
            COALESCE(cat.product_category_id, -1),
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP,
            v_rec.source_system,
            v_rec.source_entity
        FROM (SELECT 1) dummy
        -- LEFT JOIN to resolve parent FK (COALESCE to -1 if not found)
        LEFT JOIN bl_3nf.ce_product_categories cat
                ON cat.product_category_src_id = v_rec.category_src_id
                AND cat.source_system            = v_rec.source_system
        WHERE NOT EXISTS (
            SELECT 1
            FROM   bl_3nf.ce_product_subcategories tgt
            WHERE  tgt.product_subcategory_src_id = v_rec.product_subcategory_src_id
            AND  tgt.source_system                = v_rec.source_system
        );
        GET DIAGNOSTICS v_delta = ROW_COUNT;
        v_rows_inserted := v_rows_inserted + v_delta;
    END LOOP;

    -- UPDATE existing subcategories if name or parent FK changed (SCD Type 1)
    UPDATE bl_3nf.ce_product_subcategories tgt
    SET
        product_subcategory_name    = src.product_subcategory_name,
        product_category_id         = COALESCE(cat.product_category_id, -1),
        ta_update_dt                = CURRENT_TIMESTAMP,
        source_system               = src.source_system,
        source_entity               = src.source_entity
    FROM (
        SELECT DISTINCT
            UPPER(TRIM(r.subcategory))      AS product_subcategory_src_id,
            INITCAP(TRIM(r.subcategory))    AS product_subcategory_name,
            UPPER(TRIM(r.category))         AS category_src_id,
            'SA_RETAIL'                     AS source_system,
            'SRC_RETAIL_SALES'              AS source_entity
        FROM sa_retail.src_retail_sales r
        WHERE r.subcategory IS NOT NULL AND TRIM(r.subcategory) <> ''

        UNION ALL

        SELECT DISTINCT
            UPPER(TRIM(e.details))          AS product_subcategory_src_id,
            INITCAP(TRIM(e.details))        AS product_subcategory_name,
            UPPER(TRIM(e.product_type))     AS category_src_id,
            'SA_ECOM'                       AS source_system,
            'SRC_ECOM_SALES'                AS source_entity
        FROM sa_ecom.src_ecom_sales e
        WHERE e.details IS NOT NULL AND TRIM(e.details) <> ''
    ) src
    LEFT JOIN bl_3nf.ce_product_categories cat
            ON cat.product_category_src_id = src.category_src_id
            AND cat.source_system          = src.source_system

    WHERE tgt.product_subcategory_src_id = src.product_subcategory_src_id
        AND tgt.source_system               = src.source_system
        AND tgt.product_subcategory_id    > 0
        AND (
                tgt.product_subcategory_name <> src.product_subcategory_name
            OR tgt.product_category_id      <> COALESCE(cat.product_category_id, -1)
        );
    GET DIAGNOSTICS v_delta = ROW_COUNT;
    v_rows_updated := v_rows_updated + v_delta;

    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_product_subcategories',
        p_rows_inserted  => v_rows_inserted,
        p_rows_updated   => v_rows_updated,
        p_status         => 'SUCCESS',
        p_source_system  => 'SA_RETAIL/SA_ECOM',
        p_source_entity  => 'SRC_RETAIL_SALES/SRC_ECOM_SALES'
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_product_subcategories',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'ERROR',
        p_message        => SQLERRM
    );
    RAISE;
END;
$$;


-- ============================================================
-- GROUP 3 - SCD TYPE 1: Address and store chain
--           CE_LOCATIONS must be loaded before CE_EMPLOYEES
--           and CE_STORES (both reference it via FK).
-- ============================================================

-- ------------------------------------------------------------
-- 3.1  CE_LOCATIONS
--      Sources: ALL address columns from BOTH source systems
--               (store addresses, customer addresses,
--                employee addresses)
--      NK:      COALESCE(TRIM(address),'n/a')
--               || '_' || COALESCE(TRIM(postal_code),'n/a')
--      SCD1:    UPDATE city / state on change (postal code = key)
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION bl_cl.fn_get_ce_locations()
RETURNS TABLE (
    location_src_id      VARCHAR,
    location_address     VARCHAR,
    location_postal_code VARCHAR,
    location_city        VARCHAR,
    location_state       VARCHAR,
    source_system        VARCHAR,
    source_entity        VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ON (location_src_id)
        combined.location_src_id,
        combined.location_address,
        combined.location_postal_code,
        combined.location_city,
        combined.location_state,
        combined.source_system,
        combined.source_entity
    FROM (
        -- STORE addresses (retail only)
        SELECT DISTINCT
            (COALESCE(TRIM(store_address),      'n/a') || '_' ||
             COALESCE(TRIM(store_postal_code),  'n/a'))::VARCHAR  AS location_src_id,
            COALESCE(TRIM(store_address),      'n/a')::VARCHAR    AS location_address,
            COALESCE(TRIM(store_postal_code),  'n/a')::VARCHAR    AS location_postal_code,
            COALESCE(TRIM(store_city),         'n/a')::VARCHAR    AS location_city,
            COALESCE(UPPER(TRIM(store_state)), 'n/a')::VARCHAR     AS location_state,
            'SA_RETAIL'::VARCHAR                                   AS source_system,
            'SRC_RETAIL_SALES'::VARCHAR                            AS source_entity
        FROM sa_retail.src_retail_sales
        WHERE store_address IS NOT NULL AND TRIM(store_address) <> ''

        UNION ALL

        -- CUSTOMER addresses (retail)
        SELECT DISTINCT
            (COALESCE(TRIM(customer_address),      'n/a') || '_' ||
             COALESCE(TRIM(customer_postal_code),  'n/a'))::VARCHAR AS location_src_id,
            COALESCE(TRIM(customer_address),      'n/a')::VARCHAR   AS location_address,
            COALESCE(TRIM(customer_postal_code),  'n/a')::VARCHAR   AS location_postal_code,
            COALESCE(TRIM(customer_city),         'n/a')::VARCHAR   AS location_city,
            COALESCE(UPPER(TRIM(customer_state)), 'n/a')::VARCHAR    AS location_state,
            'SA_RETAIL'::VARCHAR                                     AS source_system,
            'SRC_RETAIL_SALES'::VARCHAR                              AS source_entity
        FROM sa_retail.src_retail_sales
        WHERE customer_address IS NOT NULL AND TRIM(customer_address) <> ''

        UNION ALL

        -- CUSTOMER addresses (ecom)
        SELECT DISTINCT
            (COALESCE(TRIM(user_address),      'n/a') || '_' ||
             COALESCE(TRIM(user_postal_code),  'n/a'))::VARCHAR   AS location_src_id,
            COALESCE(TRIM(user_address),      'n/a')::VARCHAR     AS location_address,
            COALESCE(TRIM(user_postal_code),  'n/a')::VARCHAR     AS location_postal_code,
            COALESCE(TRIM(user_city),         'n/a')::VARCHAR     AS location_city,
            COALESCE(UPPER(TRIM(user_state)), 'n/a')::VARCHAR      AS location_state,
            'SA_ECOM'::VARCHAR                                     AS source_system,
            'SRC_ECOM_SALES'::VARCHAR                              AS source_entity
        FROM sa_ecom.src_ecom_sales
        WHERE user_address IS NOT NULL AND TRIM(user_address) <> ''

        UNION ALL

        -- EMPLOYEE addresses (retail)
        SELECT DISTINCT
            (COALESCE(TRIM(employee_address),      'n/a') || '_' ||
             COALESCE(TRIM(employee_postal_code),  'n/a'))::VARCHAR AS location_src_id,
            COALESCE(TRIM(employee_address),      'n/a')::VARCHAR   AS location_address,
            COALESCE(TRIM(employee_postal_code),  'n/a')::VARCHAR   AS location_postal_code,
            COALESCE(TRIM(employee_city),         'n/a')::VARCHAR   AS location_city,
            COALESCE(UPPER(TRIM(employee_state)), 'n/a')::VARCHAR    AS location_state,
            'SA_RETAIL'::VARCHAR                                     AS source_system,
            'SRC_RETAIL_SALES'::VARCHAR                              AS source_entity
        FROM sa_retail.src_retail_sales
        WHERE employee_address IS NOT NULL AND TRIM(employee_address) <> ''

        UNION ALL

        -- EMPLOYEE addresses (ecom)
        SELECT DISTINCT
            (COALESCE(TRIM(ee_address),      'n/a') || '_' ||
             COALESCE(TRIM(ee_postal_code),  'n/a'))::VARCHAR  AS location_src_id,
            COALESCE(TRIM(ee_address),      'n/a')::VARCHAR    AS location_address,
            COALESCE(TRIM(ee_postal_code),  'n/a')::VARCHAR    AS location_postal_code,
            COALESCE(TRIM(ee_city),         'n/a')::VARCHAR    AS location_city,
            COALESCE(UPPER(TRIM(ee_state)), 'n/a')::VARCHAR     AS location_state,
            'SA_ECOM'::VARCHAR                                  AS source_system,
            'SRC_ECOM_SALES'::VARCHAR                           AS source_entity
        FROM sa_ecom.src_ecom_sales
        WHERE ee_address IS NOT NULL AND TRIM(ee_address) <> ''
    ) combined
    ORDER BY location_src_id, source_system;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_locations()
LANGUAGE plpgsql AS $$
DECLARE
    v_rec           RECORD;
    v_rows_inserted INTEGER := 0;
    v_rows_updated  INTEGER := 0;
    v_delta         INTEGER := 0;
BEGIN
    -- INSERT new locations not yet in target
    FOR v_rec IN (SELECT * FROM bl_cl.fn_get_ce_locations())
    LOOP
        INSERT INTO bl_3nf.ce_locations (
            location_id,
            location_src_id,
            location_address,
            location_postal_code,
            location_city,
            location_state,
            ta_insert_dt,
            ta_update_dt,
            source_system,
            source_entity
        )
        SELECT
            nextval('bl_3nf.seq_ce_locations'),
            v_rec.location_src_id,
            v_rec.location_address,
            v_rec.location_postal_code,
            v_rec.location_city,
            v_rec.location_state,
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP,
            v_rec.source_system,
            v_rec.source_entity
        WHERE NOT EXISTS (
            SELECT 1
            FROM   bl_3nf.ce_locations tgt
            WHERE  tgt.location_src_id = v_rec.location_src_id
                AND tgt.source_system = v_rec.source_system
        );
        GET DIAGNOSTICS v_delta = ROW_COUNT;
        v_rows_inserted := v_rows_inserted + v_delta;
    END LOOP;

    -- UPDATE existing locations if city / state changed (SCD Type 1)
    UPDATE bl_3nf.ce_locations tgt
    SET
        location_city        = src.location_city,
        location_state       = src.location_state,
        ta_update_dt         = CURRENT_TIMESTAMP
    FROM (
        SELECT DISTINCT
            COALESCE(TRIM(store_address),      'n/a')
                || '_' || COALESCE(TRIM(store_postal_code), 'n/a')
                                                AS location_src_id,
            COALESCE(TRIM(store_city),         'n/a') AS location_city,
            COALESCE(UPPER(TRIM(store_state)), 'n/a')  AS location_state
        FROM sa_retail.src_retail_sales
        WHERE store_address IS NOT NULL AND TRIM(store_address) <> ''

        UNION

        SELECT DISTINCT
            COALESCE(TRIM(customer_address),      'n/a')
                || '_' || COALESCE(TRIM(customer_postal_code), 'n/a')
                                                AS location_src_id,
            COALESCE(TRIM(customer_city),         'n/a') AS location_city,
            COALESCE(UPPER(TRIM(customer_state)), 'n/a')  AS location_state
        FROM sa_retail.src_retail_sales
        WHERE customer_address IS NOT NULL AND TRIM(customer_address) <> ''

        UNION

        SELECT DISTINCT
            COALESCE(TRIM(employee_address),      'n/a')
                || '_' || COALESCE(TRIM(employee_postal_code), 'n/a')
                                                AS location_src_id,
            COALESCE(TRIM(employee_city),         'n/a') AS location_city,
            COALESCE(UPPER(TRIM(employee_state)), 'n/a')  AS location_state
        FROM sa_retail.src_retail_sales
        WHERE employee_address IS NOT NULL AND TRIM(employee_address) <> ''

        UNION

        SELECT DISTINCT
            COALESCE(TRIM(user_address),      'n/a')
                || '_' || COALESCE(TRIM(user_postal_code), 'n/a')
                                                AS location_src_id,
            COALESCE(TRIM(user_city),         'n/a') AS location_city,
            COALESCE(UPPER(TRIM(user_state)), 'n/a')  AS location_state
        FROM sa_ecom.src_ecom_sales
        WHERE user_address IS NOT NULL AND TRIM(user_address) <> ''

        UNION

        SELECT DISTINCT
            COALESCE(TRIM(ee_address),      'n/a')
                || '_' || COALESCE(TRIM(ee_postal_code), 'n/a')
                                                AS location_src_id,
            COALESCE(TRIM(ee_city),         'n/a') AS location_city,
            COALESCE(UPPER(TRIM(ee_state)), 'n/a')  AS location_state
        FROM sa_ecom.src_ecom_sales
        WHERE ee_address IS NOT NULL AND TRIM(ee_address) <> ''
    ) src
    WHERE tgt.location_src_id = src.location_src_id
        AND tgt.location_id    > 0
        AND (
                tgt.location_city  <> src.location_city
            OR tgt.location_state <> src.location_state
        );
    GET DIAGNOSTICS v_delta = ROW_COUNT;
    v_rows_updated := v_rows_updated + v_delta;

    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_locations',
        p_rows_inserted  => v_rows_inserted,
        p_rows_updated   => v_rows_updated,
        p_status         => 'SUCCESS',
        p_source_system  => 'SA_RETAIL/SA_ECOM',
        p_source_entity  => 'SRC_RETAIL_SALES/SRC_ECOM_SALES'
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_locations',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'ERROR',
        p_message        => SQLERRM
    );
    RAISE;
END;
$$;


-- ------------------------------------------------------------
-- 3.2  CE_EMPLOYEES
--      Sources: employee_* (SA_RETAIL) + ee_* (SA_ECOM)
--      NK:      COALESCE(TRIM(employee_id/ee_id), 'n/a')
--      FK:      employee_location_id → CE_LOCATIONS (via NK)
--               COALESCE to -1 if address not resolvable
--      SCD1:    UPDATE all attributes on change
--      NOTE:    SSN excluded at SA layer already
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION bl_cl.fn_get_ce_employees()
RETURNS TABLE (
    employee_src_id       VARCHAR,
    employee_name         VARCHAR,
    employee_gender       VARCHAR,
    employee_email        VARCHAR,
    employee_phone_number VARCHAR,
    location_src_id       VARCHAR,
    source_system         VARCHAR,
    source_entity         VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
        -- SA_RETAIL employees
        SELECT * FROM (
            SELECT DISTINCT ON (TRIM(r.employee_id))
                TRIM(r.employee_id)::VARCHAR                              AS employee_src_id,
                COALESCE(TRIM(r.employee_name),         'n/a')::VARCHAR   AS employee_name,
                COALESCE(UPPER(LEFT(TRIM(
                    r.employee_gender),1)),             'n/a')::VARCHAR     AS employee_gender,
                COALESCE(TRIM(r.employee_email),        'n/a')::VARCHAR   AS employee_email,
                COALESCE(TRIM(r.employee_phone_number), 'n/a')::VARCHAR   AS employee_phone_number,
                (COALESCE(TRIM(r.employee_address),      'n/a')
                    || '_' || COALESCE(TRIM(r.employee_postal_code), 'n/a'))::VARCHAR
                                                                        AS location_src_id,
                'SA_RETAIL'::VARCHAR                                      AS source_system,
                'SRC_RETAIL_SALES'::VARCHAR                               AS source_entity
            FROM sa_retail.src_retail_sales r
            WHERE r.employee_id IS NOT NULL
            AND TRIM(r.employee_id) <> ''
            ORDER BY TRIM(r.employee_id), r.ta_insert_dt DESC, r.transaction_date DESC
        ) retail

        UNION ALL

        -- SA_ECOM employees
        SELECT * FROM (
            SELECT DISTINCT ON (TRIM(e.ee_id))
                TRIM(e.ee_id)::VARCHAR                                    AS employee_src_id,
                COALESCE(TRIM(e.ee_name),           'n/a')::VARCHAR       AS employee_name,
                COALESCE(UPPER(LEFT(TRIM(
                    e.ee_gender),1)),               'n/a')::VARCHAR         AS employee_gender,
                COALESCE(TRIM(e.ee_email),          'n/a')::VARCHAR       AS employee_email,
                COALESCE(TRIM(e.ee_phone_number),   'n/a')::VARCHAR       AS employee_phone_number,
                (COALESCE(TRIM(e.ee_address),        'n/a')
                    || '_' || COALESCE(TRIM(e.ee_postal_code), 'n/a'))::VARCHAR
                                                                        AS location_src_id,
                'SA_ECOM'::VARCHAR                                        AS source_system,
                'SRC_ECOM_SALES'::VARCHAR                                 AS source_entity
            FROM sa_ecom.src_ecom_sales e
            WHERE e.ee_id IS NOT NULL
            AND TRIM(e.ee_id) <> ''
            ORDER BY TRIM(e.ee_id), e.ta_insert_dt DESC, e.transaction_date DESC
        ) ecom;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_employees()
LANGUAGE plpgsql AS $$
DECLARE
    v_rec           RECORD;
    v_rows_inserted INTEGER := 0;
    v_rows_updated  INTEGER := 0;
    v_delta         INTEGER := 0;
BEGIN
    -- INSERT new employees not yet in target
    FOR v_rec IN (SELECT * FROM bl_cl.fn_get_ce_employees())
    LOOP
        INSERT INTO bl_3nf.ce_employees (
            employee_id,
            employee_src_id,
            employee_name,
            employee_gender,
            employee_email,
            employee_phone_number,
            employee_location_id,
            ta_insert_dt,
            ta_update_dt,
            source_system,
            source_entity
        )
        SELECT
            nextval('bl_3nf.seq_ce_employees'),
            v_rec.employee_src_id,
            v_rec.employee_name,
            v_rec.employee_gender,
            v_rec.employee_email,
            v_rec.employee_phone_number,
            COALESCE(loc.location_id, -1),
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP,
            v_rec.source_system,
            v_rec.source_entity
        FROM (SELECT 1) dummy
        -- LEFT JOIN to resolve location FK
        LEFT JOIN bl_3nf.ce_locations loc
               ON loc.location_src_id = v_rec.location_src_id
        WHERE NOT EXISTS (
            SELECT 1
            FROM   bl_3nf.ce_employees tgt
            WHERE  tgt.employee_src_id = v_rec.employee_src_id
            AND tgt.source_system = v_rec.source_system
        );
        GET DIAGNOSTICS v_delta = ROW_COUNT;
        v_rows_inserted := v_rows_inserted + v_delta;
    END LOOP;

    -- UPDATE existing employees on attribute change (SCD Type 1)
    UPDATE bl_3nf.ce_employees tgt
    SET
        employee_name           = src.employee_name,
        employee_gender         = src.employee_gender,
        employee_email          = src.employee_email,
        employee_phone_number   = src.employee_phone_number,
        employee_location_id    = COALESCE(loc.location_id, -1),
        ta_update_dt            = CURRENT_TIMESTAMP,
        source_system           = src.source_system,
        source_entity           = src.source_entity
    FROM (
        SELECT * FROM (
            SELECT DISTINCT ON (TRIM(employee_id))
                TRIM(employee_id)                               AS employee_src_id,
                COALESCE(TRIM(employee_name),         'n/a')    AS employee_name,
                COALESCE(UPPER(LEFT(TRIM(
                    employee_gender),1)),             'n/a')      AS employee_gender,
                COALESCE(TRIM(employee_email),        'n/a')    AS employee_email,
                COALESCE(TRIM(employee_phone_number), 'n/a')    AS employee_phone_number,
                COALESCE(TRIM(employee_address),      'n/a')
                    || '_' || COALESCE(TRIM(employee_postal_code), 'n/a')
                                                                AS location_src_id,
                'SA_RETAIL'                                     AS source_system,
                'SRC_RETAIL_SALES'                              AS source_entity
            FROM sa_retail.src_retail_sales
            WHERE employee_id IS NOT NULL AND TRIM(employee_id) <> ''
            ORDER BY TRIM(employee_id), ta_insert_dt DESC, transaction_date DESC
        ) retail

        UNION ALL

        SELECT * FROM (
            SELECT DISTINCT ON (TRIM(ee_id))
                TRIM(ee_id)                                     AS employee_src_id,
                COALESCE(TRIM(ee_name),           'n/a')        AS employee_name,
                COALESCE(UPPER(LEFT(TRIM(
                    ee_gender),1)),               'n/a')          AS employee_gender,
                COALESCE(TRIM(ee_email),          'n/a')        AS employee_email,
                COALESCE(TRIM(ee_phone_number),   'n/a')        AS employee_phone_number,
                COALESCE(TRIM(ee_address),        'n/a')
                    || '_' || COALESCE(TRIM(ee_postal_code),    'n/a')
                                                                AS location_src_id,
                'SA_ECOM'                                       AS source_system,
                'SRC_ECOM_SALES'                                AS source_entity
            FROM sa_ecom.src_ecom_sales
            WHERE ee_id IS NOT NULL AND TRIM(ee_id) <> ''
            ORDER BY TRIM(ee_id), ta_insert_dt DESC, transaction_date DESC
        ) ecom
    ) src
    LEFT JOIN bl_3nf.ce_locations loc
           ON loc.location_src_id = src.location_src_id
    WHERE tgt.employee_src_id = src.employee_src_id
        AND tgt.source_system = src.source_system
        AND tgt.employee_id    > 0
        AND (
                tgt.employee_name         <> src.employee_name
            OR tgt.employee_gender       <> src.employee_gender
            OR tgt.employee_email        <> src.employee_email
            OR tgt.employee_phone_number <> src.employee_phone_number
            OR tgt.employee_location_id  <> COALESCE(loc.location_id, -1)
        );
    GET DIAGNOSTICS v_delta = ROW_COUNT;
    v_rows_updated := v_rows_updated + v_delta;

    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_employees',
        p_rows_inserted  => v_rows_inserted,
        p_rows_updated   => v_rows_updated,
        p_status         => 'SUCCESS',
        p_source_system  => 'SA_RETAIL/SA_ECOM',
        p_source_entity  => 'SRC_RETAIL_SALES/SRC_ECOM_SALES'
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_employees',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'ERROR',
        p_message        => SQLERRM
    );
    RAISE;
END;
$$;


-- ------------------------------------------------------------
-- 3.3  CE_STORES
--      Sources: store_* (SA_RETAIL) + constant 'ECOMMERCE' (SA_ECOM)
--      NK:      store_code (retail) / 'ECOMMERCE' (ecom)
--      FK:      store_zone_id     → CE_STORE_ZONES (COALESCE -1)
--               store_location_id → CE_LOCATIONS   (COALESCE -1)
--      SCD1:    UPDATE zone + location on change
--      NOTE:    Ecom has one constant row; store address = 'n/a'
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION bl_cl.fn_get_ce_stores()
RETURNS TABLE (
    store_src_id    VARCHAR,
    store_channel   VARCHAR,
    zone_src_id     VARCHAR,
    location_src_id VARCHAR,
    source_system   VARCHAR,
    source_entity   VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    -- SA_RETAIL: distinct physical stores
    SELECT * FROM (
        SELECT DISTINCT ON (TRIM(store_code))
            TRIM(store_code)::VARCHAR                               AS store_src_id,
            'RETAIL'::VARCHAR                                       AS store_channel,
            UPPER(TRIM(zone_code))::VARCHAR                         AS zone_src_id,
            (COALESCE(TRIM(store_address),      'n/a')
                || '_' || COALESCE(TRIM(store_postal_code), 'n/a'))::VARCHAR
                                                                    AS location_src_id,
            'SA_RETAIL'::VARCHAR                                    AS source_system,
            'SRC_RETAIL_SALES'::VARCHAR                             AS source_entity
        FROM sa_retail.src_retail_sales
        WHERE store_code IS NOT NULL
          AND TRIM(store_code) <> ''
        ORDER BY TRIM(store_code), ta_insert_dt DESC, transaction_date DESC
    ) retail

    UNION ALL

    -- SA_ECOM: single constant ecommerce channel row
    SELECT
        'ECOMMERCE'::VARCHAR,
        'ECOMMERCE'::VARCHAR,
        'n/a'::VARCHAR,
        'n/a_n/a'::VARCHAR,
        'SA_ECOM'::VARCHAR,
        'SRC_ECOM_SALES'::VARCHAR;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_stores()
LANGUAGE plpgsql AS $$
DECLARE
    v_rec           RECORD;
    v_rows_inserted INTEGER := 0;
    v_rows_updated  INTEGER := 0;
    v_delta         INTEGER := 0;
BEGIN
    -- INSERT new stores not yet in target
    FOR v_rec IN (SELECT * FROM bl_cl.fn_get_ce_stores())
    LOOP
        INSERT INTO bl_3nf.ce_stores (
            store_id,
            store_src_id,
            store_channel,
            store_zone_id,
            store_location_id,
            ta_insert_dt,
            ta_update_dt,
            source_system,
            source_entity
        )
        SELECT
            nextval('bl_3nf.seq_ce_stores'),
            v_rec.store_src_id,
            v_rec.store_channel,
            COALESCE(zon.store_zone_id,  -1),
            COALESCE(loc.location_id,    -1),
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP,
            v_rec.source_system,
            v_rec.source_entity
        FROM (SELECT 1) dummy
        -- LEFT JOIN zone FK
        LEFT JOIN bl_3nf.ce_store_zones zon
               ON zon.store_zone_src_id = v_rec.zone_src_id
        -- LEFT JOIN location FK
        LEFT JOIN bl_3nf.ce_locations loc
               ON loc.location_src_id   = v_rec.location_src_id
        WHERE NOT EXISTS (
            SELECT 1
            FROM   bl_3nf.ce_stores tgt
            WHERE  tgt.store_src_id = v_rec.store_src_id
            AND tgt.source_system = v_rec.source_system
        );
        GET DIAGNOSTICS v_delta = ROW_COUNT;
        v_rows_inserted := v_rows_inserted + v_delta;
    END LOOP;

    -- UPDATE existing stores on zone / location change (SCD Type 1)
    UPDATE bl_3nf.ce_stores tgt
    SET
        store_zone_id       = COALESCE(zon.store_zone_id, -1),
        store_location_id   = COALESCE(loc.location_id,   -1),
        ta_update_dt        = CURRENT_TIMESTAMP,
        source_system       = src.source_system,
        source_entity       = src.source_entity
    FROM (
        SELECT DISTINCT ON (TRIM(store_code))
            TRIM(store_code)                                AS store_src_id,
            UPPER(TRIM(zone_code))                          AS zone_src_id,
            COALESCE(TRIM(store_address),      'n/a')
                || '_' || COALESCE(TRIM(store_postal_code), 'n/a')
                                                            AS location_src_id,
            'SA_RETAIL'                                     AS source_system,
            'SRC_RETAIL_SALES'                              AS source_entity
        FROM sa_retail.src_retail_sales
        WHERE store_code IS NOT NULL AND TRIM(store_code) <> ''
        ORDER BY TRIM(store_code), ta_insert_dt DESC, transaction_date DESC
    ) src
    LEFT JOIN bl_3nf.ce_store_zones zon ON zon.store_zone_src_id = src.zone_src_id
    LEFT JOIN bl_3nf.ce_locations   loc ON loc.location_src_id   = src.location_src_id
    WHERE tgt.store_src_id   = src.store_src_id
        AND tgt.source_system = src.source_system
        AND tgt.store_id      > 0
        AND (
                tgt.store_zone_id     <> COALESCE(zon.store_zone_id, -1)
            OR tgt.store_location_id <> COALESCE(loc.location_id,   -1)
        );
    GET DIAGNOSTICS v_delta = ROW_COUNT;
    v_rows_updated := v_rows_updated + v_delta;

    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_stores',
        p_rows_inserted  => v_rows_inserted,
        p_rows_updated   => v_rows_updated,
        p_status         => 'SUCCESS',
        p_source_system  => 'SA_RETAIL/SA_ECOM',
        p_source_entity  => 'SRC_RETAIL_SALES/SRC_ECOM_SALES'
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_stores',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'ERROR',
        p_message        => SQLERRM
    );
    RAISE;
END;
$$;

-- ============================================================
-- GROUP 4 - SCD TYPE 2: Historical dimension tables
--
-- SCD2 LOGIC:
--   STEP A – Close previous active version:
--     For rows where NK exists in target with IS_ACTIVE = 'Y'
--     AND any tracked attribute differs from source:
--       SET end_dt = CURRENT_DATE - 1
--           is_active = 'N'
--   STEP B – Insert new version (changed existing rows):
--     For same rows detected in Step A:
--       INSERT new row with new surrogate key from sequence,
--       start_dt = CURRENT_DATE, end_dt = '9999-12-31',
--       is_active = 'Y'
--   STEP C – Insert brand-new rows (NK not in target at all):
--     For rows whose NK does not yet exist in target:
--       INSERT with start_dt = CURRENT_DATE,
--       end_dt = '9999-12-31', is_active = 'Y'
--
-- FK to SCD2 from CE_SALES: LOGICAL ONLY - no DB constraint.
-- ============================================================

-- ------------------------------------------------------------
-- 4.1  CE_CUSTOMERS_SCD
--      Sources: customer_* (SA_RETAIL) + user_* (SA_ECOM)
--      NK:      customer_id (retail) / user_id (ecom)
--      Tracked: customer_location_id (address changes)
--      PK:      COMPOSITE (customer_id + start_dt)
--      NOTE:    customer_email = 'n/a' for retail (field absent)
--               SSN + card data excluded at SA layer already
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION bl_cl.fn_get_ce_customers_scd()
RETURNS TABLE (
    customer_src_id       VARCHAR,
    customer_name         VARCHAR,
    customer_gender       VARCHAR,
    customer_email        VARCHAR,
    customer_phone_number VARCHAR,
    location_src_id       VARCHAR,
    source_system         VARCHAR,
    source_entity         VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
        SELECT * FROM (
            SELECT DISTINCT ON (TRIM(r.customer_id))
                TRIM(r.customer_id)::VARCHAR                              AS customer_src_id,
                COALESCE(TRIM(r.customer_name),         'n/a')::VARCHAR   AS customer_name,
                COALESCE(UPPER(LEFT(TRIM(
                    r.customer_gender),1)),             'n/a')::VARCHAR     AS customer_gender,
                'n/a'::VARCHAR                                            AS customer_email,
                COALESCE(TRIM(r.customer_phone_number), 'n/a')::VARCHAR   AS customer_phone_number,
                (COALESCE(TRIM(r.customer_address),      'n/a')
                    || '_' || COALESCE(TRIM(r.customer_postal_code), 'n/a'))::VARCHAR
                                                                        AS location_src_id,
                'SA_RETAIL'::VARCHAR                                      AS source_system,
                'SRC_RETAIL_SALES'::VARCHAR                               AS source_entity
            FROM sa_retail.src_retail_sales r
            WHERE r.customer_id IS NOT NULL AND TRIM(r.customer_id) <> ''
            ORDER BY TRIM(r.customer_id), r.ta_insert_dt DESC, r.transaction_date DESC
        ) retail
    
        UNION ALL
    
        SELECT * FROM (
            SELECT DISTINCT ON (TRIM(e.user_id))
                TRIM(e.user_id)::VARCHAR                                  AS customer_src_id,
                COALESCE(TRIM(e.user_name),             'n/a')::VARCHAR   AS customer_name,
                COALESCE(UPPER(LEFT(TRIM(
                    e.user_gender),1)),                 'n/a')::VARCHAR     AS customer_gender,
                COALESCE(TRIM(e.user_email),            'n/a')::VARCHAR   AS customer_email,
                COALESCE(TRIM(e.user_phone_number),     'n/a')::VARCHAR   AS customer_phone_number,
                (COALESCE(TRIM(e.user_address),          'n/a')
                    || '_' || COALESCE(TRIM(e.user_postal_code),  'n/a'))::VARCHAR
                                                                        AS location_src_id,
                'SA_ECOM'::VARCHAR                                        AS source_system,
                'SRC_ECOM_SALES'::VARCHAR                                 AS source_entity
            FROM sa_ecom.src_ecom_sales e
            WHERE e.user_id IS NOT NULL AND TRIM(e.user_id) <> ''
            ORDER BY TRIM(e.user_id), e.ta_insert_dt DESC, e.transaction_date DESC
        ) ecom;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_customers_scd()
LANGUAGE plpgsql AS $$
DECLARE
    v_rows_inserted INTEGER := 0;
    v_rows_updated  INTEGER := 0;
    v_delta         INTEGER := 0;
BEGIN
    -- ── STEP A: Close previous active version when location changed ─
    UPDATE bl_3nf.ce_customers_scd tgt
    SET
        end_dt      = CURRENT_DATE - 1,
        is_active   = 'N',
        ta_update_dt = CURRENT_TIMESTAMP
    FROM (
        SELECT * FROM (
            SELECT DISTINCT ON (TRIM(r.customer_id))
                TRIM(r.customer_id)                                     AS customer_src_id,
                COALESCE(TRIM(r.customer_name),         'n/a')          AS customer_name,
                COALESCE(UPPER(LEFT(TRIM(
                    r.customer_gender),1)),             'n/a')            AS customer_gender,
                'n/a'                                                   AS customer_email,
                COALESCE(TRIM(r.customer_phone_number), 'n/a')          AS customer_phone_number,
                COALESCE(TRIM(r.customer_address),      'n/a')
                    || '_' || COALESCE(TRIM(r.customer_postal_code), 'n/a')
                                                                        AS location_src_id,
                'SA_RETAIL'                                             AS source_system
            FROM sa_retail.src_retail_sales r
            WHERE r.customer_id IS NOT NULL AND TRIM(r.customer_id) <> ''
            ORDER BY TRIM(r.customer_id), r.ta_insert_dt DESC, r.transaction_date DESC
        ) retail

        UNION ALL

        SELECT * FROM (
            SELECT DISTINCT ON (TRIM(e.user_id))
                TRIM(e.user_id)                                         AS customer_src_id,
                COALESCE(TRIM(e.user_name),             'n/a')          AS customer_name,
                COALESCE(UPPER(LEFT(TRIM(
                    e.user_gender),1)),                 'n/a')            AS customer_gender,
                COALESCE(TRIM(e.user_email),            'n/a')          AS customer_email,
                COALESCE(TRIM(e.user_phone_number),     'n/a')          AS customer_phone_number,
                COALESCE(TRIM(e.user_address),          'n/a')
                    || '_' || COALESCE(TRIM(e.user_postal_code),  'n/a')
                                                                        AS location_src_id,
                'SA_ECOM'                                               AS source_system
            FROM sa_ecom.src_ecom_sales e
            WHERE e.user_id IS NOT NULL AND TRIM(e.user_id) <> ''
            ORDER BY TRIM(e.user_id), e.ta_insert_dt DESC, e.transaction_date DESC
        ) ecom
    ) src
    LEFT JOIN bl_3nf.ce_locations loc
           ON loc.location_src_id = src.location_src_id
           AND loc.source_system = src.source_system
    WHERE tgt.customer_src_id  = src.customer_src_id
        AND tgt.source_system = src.source_system
        AND tgt.is_active        = 'Y'
        AND tgt.customer_id     > 0
        AND tgt.end_dt                 = DATE '9999-12-31'
        AND (
            tgt.customer_location_id  <> COALESCE(loc.location_id, -1)
            OR tgt.customer_name         <> src.customer_name
            OR tgt.customer_phone_number <> src.customer_phone_number
            OR tgt.customer_email        <> src.customer_email
            OR tgt.customer_gender       <> src.customer_gender
       );
    GET DIAGNOSTICS v_delta = ROW_COUNT;
    v_rows_updated := v_rows_updated + v_delta;

    -- ── STEP B: Insert new version for rows that were just closed ───
    INSERT INTO bl_3nf.ce_customers_scd (
        customer_id,
        customer_src_id,
        customer_name,
        customer_gender,
        customer_email,
        customer_phone_number,
        customer_location_id,
        start_dt,
        end_dt,
        is_active,
        ta_insert_dt,
        ta_update_dt,
        source_system,
        source_entity
    )
    SELECT
        nextval('bl_3nf.seq_ce_customers_scd'),
        src.customer_src_id,
        src.customer_name,
        src.customer_gender,
        src.customer_email,
        src.customer_phone_number,
        COALESCE(loc.location_id, -1),
        CURRENT_DATE,
        DATE '9999-12-31',
        'Y',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        src.source_system,
        src.source_entity
    FROM bl_cl.fn_get_ce_customers_scd() src
    LEFT JOIN bl_3nf.ce_locations loc
            ON loc.location_src_id = src.location_src_id
            AND loc.source_system = src.source_system
    -- Only insert new version for customers whose previous row was just closed today
    WHERE EXISTS (
        SELECT 1
        FROM   bl_3nf.ce_customers_scd closed
        WHERE  closed.customer_src_id = src.customer_src_id
            AND closed.source_system = src.source_system
            AND  closed.is_active       = 'N'
            AND  closed.end_dt          = CURRENT_DATE - 1
    )
    AND NOT EXISTS (
        SELECT 1
        FROM   bl_3nf.ce_customers_scd active
        WHERE  active.customer_src_id = src.customer_src_id
            AND active.source_system = src.source_system
            AND  active.is_active       = 'Y'
            AND  active.start_dt        = CURRENT_DATE
    );
    GET DIAGNOSTICS v_delta = ROW_COUNT;
    v_rows_inserted := v_rows_inserted + v_delta;

    -- ── STEP C: Insert brand-new customers (NK not in target yet) ───
    INSERT INTO bl_3nf.ce_customers_scd (
        customer_id,
        customer_src_id,
        customer_name,
        customer_gender,
        customer_email,
        customer_phone_number,
        customer_location_id,
        start_dt,
        end_dt,
        is_active,
        ta_insert_dt,
        ta_update_dt,
        source_system,
        source_entity
    )
    SELECT
        nextval('bl_3nf.seq_ce_customers_scd'),
        src.customer_src_id,
        src.customer_name,
        src.customer_gender,
        src.customer_email,
        src.customer_phone_number,
        COALESCE(loc.location_id, -1),
        CURRENT_DATE,
        DATE '9999-12-31',
        'Y',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        src.source_system,
        src.source_entity
    FROM bl_cl.fn_get_ce_customers_scd() src
    LEFT JOIN bl_3nf.ce_locations loc
        ON loc.location_src_id = src.location_src_id
        AND loc.source_system = src.source_system
    -- Only brand-new customers: NK has never appeared in target
    WHERE NOT EXISTS (
        SELECT 1
        FROM   bl_3nf.ce_customers_scd tgt
        WHERE  tgt.customer_src_id = src.customer_src_id
            AND tgt.source_system = src.source_system
    );
    GET DIAGNOSTICS v_delta = ROW_COUNT;
    v_rows_inserted := v_rows_inserted + v_delta;

    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_customers_scd',
        p_rows_inserted  => v_rows_inserted,
        p_rows_updated   => v_rows_updated,
        p_status         => 'SUCCESS',
        p_source_system  => 'SA_RETAIL/SA_ECOM',
        p_source_entity  => 'SRC_RETAIL_SALES/SRC_ECOM_SALES'
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_customers_scd',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'ERROR',
        p_message        => SQLERRM
    );
    RAISE;
END;
$$;


-- ------------------------------------------------------------
-- 4.2  CE_PRODUCTS_SCD
--      Sources: product attributes from SA_RETAIL + SA_ECOM
--      NK:      product_code (same column name in both sources)
--      Tracked SCD2 attributes:
--        product_description  (retail: description / ecom: n/a)
--        product_colour       (retail: colour       / ecom: n/a)
--        product_size         (retail: size         / ecom: n/a)
--        product_min_amount   (retail: min_amount   / ecom: NULL)
--      FK: product_subcategory_id → CE_PRODUCT_SUBCATEGORIES
--          resolved via subcategory/details NK; COALESCE to -1
--      PK: COMPOSITE (product_id + start_dt)
--      NOTE: PRODUCT_COST is a KPI → stored in CE_SALES, NOT here.
--            Ecom products: colour/size/description unavailable
--            → stored as 'n/a'
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION bl_cl.fn_get_ce_products_scd()
RETURNS TABLE (
    product_src_id      VARCHAR,
    subcategory_src_id  VARCHAR,
    product_description VARCHAR,
    product_colour      VARCHAR,
    product_size        VARCHAR,
    product_min_amount  DECIMAL(18,8),
    source_system       VARCHAR,
    source_entity       VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    -- SA_RETAIL: all tracked attributes available
    SELECT * FROM (
        SELECT DISTINCT ON (TRIM(r.product_code))
            TRIM(r.product_code)::VARCHAR                                AS product_src_id,
            UPPER(TRIM(r.subcategory))::VARCHAR                          AS subcategory_src_id,
            CASE WHEN TRIM(r.description) IN ('NOT-CAPTURED', '') OR r.description IS NULL
                  THEN 'n/a' ELSE TRIM(r.description) END::VARCHAR       AS product_description,
            CASE WHEN TRIM(r.colour)      IN ('NOT-CAPTURED', '') OR r.colour      IS NULL
                THEN 'n/a' ELSE TRIM(r.colour)      END::VARCHAR         AS product_colour,
            CASE WHEN TRIM(r.size)        IN ('NOT-CAPTURED', '') OR r.size        IS NULL
                THEN 'n/a' ELSE TRIM(r.size)        END::VARCHAR         AS product_size,
            r.min_amount::DECIMAL(18,8)                                  AS product_min_amount,
            'SA_RETAIL'::VARCHAR                                         AS source_system,
            'SRC_RETAIL_SALES'::VARCHAR                                  AS source_entity
        FROM sa_retail.src_retail_sales r
        WHERE r.product_code IS NOT NULL
          AND TRIM(r.product_code) <> ''
        ORDER BY TRIM(r.product_code), r.ta_insert_dt DESC, r.transaction_date DESC
    ) retail

    UNION ALL

    -- SA_ECOM: tracked attributes not captured in this source
    SELECT * FROM (
        SELECT DISTINCT ON (TRIM(e.product_code))
            TRIM(e.product_code)::VARCHAR    AS product_src_id,
            UPPER(TRIM(e.details))::VARCHAR  AS subcategory_src_id,
            'n/a'::VARCHAR                   AS product_description,
            'n/a'::VARCHAR                   AS product_colour,
            'n/a'::VARCHAR                   AS product_size,
            NULL::DECIMAL(18,8)              AS product_min_amount,
            'SA_ECOM'::VARCHAR               AS source_system,
            'SRC_ECOM_SALES'::VARCHAR        AS source_entity
        FROM sa_ecom.src_ecom_sales e
        WHERE e.product_code IS NOT NULL
          AND TRIM(e.product_code) <> ''
        ORDER BY TRIM(e.product_code), e.ta_insert_dt DESC, e.transaction_date DESC
    ) ecom;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_products_scd()
LANGUAGE plpgsql AS $$
DECLARE
    v_rows_inserted INTEGER := 0;
    v_rows_updated  INTEGER := 0;
    v_delta         INTEGER := 0;
BEGIN
    -- ── STEP A: Close previous active version when tracked attrs changed ─
    UPDATE bl_3nf.ce_products_scd tgt
    SET
        end_dt      = CURRENT_DATE - 1,
        is_active   = 'N',
        ta_update_dt = CURRENT_TIMESTAMP
    FROM bl_cl.fn_get_ce_products_scd() src
    LEFT JOIN bl_3nf.ce_product_subcategories sub
            ON sub.product_subcategory_src_id = src.subcategory_src_id
            AND sub.source_system               = src.source_system
    WHERE tgt.product_src_id = src.product_src_id
        AND tgt.source_system = src.source_system
        AND tgt.is_active       = 'Y'
        AND tgt.end_dt          = DATE '9999-12-31'
        AND tgt.product_id      > 0   -- never touch default row
        AND (
                tgt.product_description <> src.product_description
            OR tgt.product_colour      <> src.product_colour
            OR tgt.product_size        <> src.product_size
            -- IS DISTINCT FROM handles NULL vs NULL correctly:
            OR tgt.product_min_amount  IS DISTINCT FROM src.product_min_amount
      );
    GET DIAGNOSTICS v_delta = ROW_COUNT;
    v_rows_updated := v_rows_updated + v_delta;

    -- ── STEP B: Insert new version for products just closed in STEP A ─
    INSERT INTO bl_3nf.ce_products_scd (
        product_id,
        product_src_id,
        product_subcategory_id,
        product_description,
        product_colour,
        product_size,
        product_min_amount,
        start_dt,
        end_dt,
        is_active,
        ta_insert_dt,
        ta_update_dt,
        source_system,
        source_entity
    )
    SELECT
        nextval('bl_3nf.seq_ce_products_scd'),
        src.product_src_id,
        COALESCE(sub.product_subcategory_id, -1),
        src.product_description,
        src.product_colour,
        src.product_size,
        src.product_min_amount,
        CURRENT_DATE,
        DATE '9999-12-31',
        'Y',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        src.source_system,
        src.source_entity
    FROM bl_cl.fn_get_ce_products_scd() src
    LEFT JOIN bl_3nf.ce_product_subcategories sub
            ON sub.product_subcategory_src_id = src.subcategory_src_id
            AND sub.source_system               = src.source_system
    -- Insert only for products whose active row was just expired today (STEP A)
    WHERE EXISTS (
        SELECT 1
        FROM   bl_3nf.ce_products_scd closed
        WHERE  closed.product_src_id = src.product_src_id
            AND closed.source_system = src.source_system
            AND  closed.is_active      = 'N'
            AND  closed.end_dt         = CURRENT_DATE - 1
    )
    -- And no active version opened today yet
    AND NOT EXISTS (
        SELECT 1
        FROM   bl_3nf.ce_products_scd active
        WHERE  active.product_src_id = src.product_src_id
            AND active.source_system = src.source_system
            AND  active.is_active      = 'Y'
            AND  active.start_dt       = CURRENT_DATE
    );
    GET DIAGNOSTICS v_delta = ROW_COUNT;
    v_rows_inserted := v_rows_inserted + v_delta;

    -- ── STEP C: Insert brand-new products (NK not in target yet) ────
    MERGE INTO bl_3nf.ce_products_scd AS tgt
    USING (
        SELECT
            src.product_src_id,
            COALESCE(sub.product_subcategory_id, -1) AS product_subcategory_id,
            src.product_description,
            src.product_colour,
            src.product_size,
            src.product_min_amount,
            src.source_system,
            src.source_entity
        FROM bl_cl.fn_get_ce_products_scd() src
        LEFT JOIN bl_3nf.ce_product_subcategories sub
            ON sub.product_subcategory_src_id = src.subcategory_src_id
            AND sub.source_system               = src.source_system
    ) AS src
    ON tgt.product_src_id = src.product_src_id
        AND tgt.source_system = src.source_system
        AND tgt.is_active   = 'Y'
    WHEN NOT MATCHED THEN
        INSERT (
            product_id,
            product_src_id,
            product_subcategory_id,
            product_description,
            product_colour,
            product_size,
            product_min_amount,
            start_dt,
            end_dt,
            is_active,
            ta_insert_dt,
            ta_update_dt,
            source_system,
            source_entity
        )
        VALUES (
            nextval('bl_3nf.seq_ce_products_scd'),
            src.product_src_id,
            src.product_subcategory_id,
            src.product_description,
            src.product_colour,
            src.product_size,
            src.product_min_amount,
            CURRENT_DATE,
            DATE '9999-12-31',
            'Y',
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP,
            src.source_system,
            src.source_entity
        );
    GET DIAGNOSTICS v_delta = ROW_COUNT;
    v_rows_inserted := v_rows_inserted + v_delta;

    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_products_scd',
        p_rows_inserted  => v_rows_inserted,
        p_rows_updated   => v_rows_updated,
        p_status         => 'SUCCESS',
        p_source_system  => 'SA_RETAIL/SA_ECOM',
        p_source_entity  => 'SRC_RETAIL_SALES/SRC_ECOM_SALES'
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_products_scd',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'ERROR',
        p_message        => SQLERRM
    );
    RAISE;
END;
$$;


-- ============================================================
-- GROUP 5 - FACT TABLE: CE_SALES
--
-- SOURCE FIELD MAPPING:
--   SA_RETAIL:
--     sale_src_id   ← bill_id
--     date_id       ← transaction_date → lookup CE_DATES
--     customer_id   ← customer_id      → lookup CE_CUSTOMERS_SCD
--     employee_id   ← employee_id      → lookup CE_EMPLOYEES
--     product_id    ← product_code     → lookup CE_PRODUCTS_SCD
--     store_id      ← store_code       → lookup CE_STORES
--     payment_type_id ← payment_method → lookup CE_PAYMENT_TYPES
--     sales_amount  ← line_item_amount
--     discount      ← bill_discount
--     cost          ← cost             (monetary)
--     quantity      ← quantity_sold
--
--   SA_ECOM:
--     sale_src_id   ← payment_id
--     date_id       ← transaction_date → lookup CE_DATES
--     customer_id   ← user_id          → lookup CE_CUSTOMERS_SCD
--     employee_id   ← ee_id            → lookup CE_EMPLOYEES
--     product_id    ← product_code     → lookup CE_PRODUCTS_SCD
--     store_id      ← 'ECOMMERCE'      → lookup CE_STORES
--     payment_type_id ← payment_type   → lookup CE_PAYMENT_TYPES
--     sales_amount  ← sales_amount
--     discount      ← discount
--     cost          ← cost             (monetary)
--     quantity      ← quantity
-- ============================================================

-- ------------------------------------------------------------
-- 5.1 + 5.2  CE_SALES — fn_get + prc_load for both sources
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION bl_cl.fn_get_ce_sales_retail()
RETURNS TABLE (
    sale_src_id     VARCHAR,
    event_dt        DATE,
    customer_src_id VARCHAR,
    employee_src_id VARCHAR,
    product_src_id  VARCHAR,
    store_src_id    VARCHAR,
    payment_src_id  VARCHAR,
    sales_amount    DECIMAL(18,8),
    discount        DECIMAL(18,8),
    cost            DECIMAL(18,8),
    quantity        INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ON (TRIM(s.bill_id), TRIM(s.product_code))
        TRIM(s.bill_id)::VARCHAR               AS sale_src_id,
        s.transaction_date::DATE               AS event_dt,
        TRIM(s.customer_id)::VARCHAR           AS customer_src_id,
        TRIM(s.employee_id)::VARCHAR           AS employee_src_id,
        TRIM(s.product_code)::VARCHAR          AS product_src_id,
        TRIM(s.store_code)::VARCHAR            AS store_src_id,
        UPPER(TRIM(s.payment_method))::VARCHAR AS payment_src_id,
        s.line_item_amount::DECIMAL(18,8),
        s.bill_discount::DECIMAL(18,8),
        s.cost::DECIMAL(18,8),
        s.quantity_sold::INTEGER
    FROM sa_retail.src_retail_sales s
    WHERE s.bill_id IS NOT NULL
    AND TRIM(s.bill_id)      <> ''
    AND s.product_code IS NOT NULL
    AND TRIM(s.product_code) <> ''
    ORDER BY TRIM(s.bill_id), TRIM(s.product_code), s.ta_insert_dt DESC, s.transaction_date DESC;
END;
$$;

CREATE OR REPLACE FUNCTION bl_cl.fn_get_ce_sales_ecom()
RETURNS TABLE (
    sale_src_id     VARCHAR,
    event_dt        DATE,
    customer_src_id VARCHAR,
    employee_src_id VARCHAR,
    product_src_id  VARCHAR,
    store_src_id    VARCHAR,
    payment_src_id  VARCHAR,
    sales_amount    DECIMAL(18,8),
    discount        DECIMAL(18,8),
    cost            DECIMAL(18,8),
    quantity        INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
     SELECT
        TRIM(s.payment_id)::VARCHAR            AS sale_src_id,
        s.transaction_date::DATE               AS event_dt,
        TRIM(s.user_id)::VARCHAR               AS customer_src_id,
        TRIM(s.ee_id)::VARCHAR                 AS employee_src_id,
        TRIM(s.product_code)::VARCHAR          AS product_src_id,
        'ECOMMERCE'::VARCHAR                   AS store_src_id,
        UPPER(TRIM(s.payment_type))::VARCHAR   AS payment_src_id,
        CASE
            WHEN COUNT(DISTINCT s.sales_amount) = 1
            THEN MAX(s.sales_amount)
            ELSE SUM(s.sales_amount)
        END::DECIMAL(18,8)                     AS sales_amount,
        MAX(s.discount)::DECIMAL(18,8)         AS discount,
        MAX(s.cost)::DECIMAL(18,8)             AS cost,
        MAX(s.quantity)::INTEGER               AS quantity
    FROM sa_ecom.src_ecom_sales s
    WHERE s.payment_id IS NOT NULL
    AND TRIM(s.payment_id)   <> ''
    AND s.product_code IS NOT NULL
    AND TRIM(s.product_code) <> ''
    GROUP BY
        TRIM(s.payment_id),
        s.transaction_date,
        TRIM(s.user_id),
        TRIM(s.ee_id),
        TRIM(s.product_code),
        UPPER(TRIM(s.payment_type));
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_sales()
LANGUAGE plpgsql AS $$
DECLARE
    v_rec           RECORD;
    v_rows_inserted INTEGER := 0;
    v_delta         INTEGER := 0;
BEGIN
    -- ------------------------------------------------------------
    -- 5.1  CE_SALES - Load from SA_RETAIL via FOR LOOP
    --      NK grain: (bill_id, product_src_id, 'SA_RETAIL')
    -- ------------------------------------------------------------
    FOR v_rec IN (SELECT * FROM bl_cl.fn_get_ce_sales_retail())
    LOOP
        INSERT INTO bl_3nf.ce_sales (
            sale_id,
            sale_src_id,
            event_dt,
            date_id,
            customer_id,
            employee_id,
            product_id,
            store_id,
            payment_type_id,
            sales_amount,
            discount,
            cost,
            quantity,
            ta_insert_dt,
            ta_update_dt,
            source_system,
            source_entity
        )
        SELECT
            nextval('bl_3nf.seq_ce_sales'),
            v_rec.sale_src_id,
            -- DATE FK: lookup by NK = TO_CHAR(transaction_date,'YYYYMMDD')
            v_rec.event_dt,
            COALESCE(d.date_surr_id, -1)  AS date_id,
            -- CUSTOMER FK (SCD2 logical): current active row for this NK
            COALESCE(cust.customer_id,   -1),
            -- EMPLOYEE FK (SCD1 hard):
            COALESCE(emp.employee_id,    -1),
            -- PRODUCT FK (SCD2 logical): current active row for this NK
            COALESCE(prod.product_id,    -1),
            -- STORE FK (SCD1 hard):
            COALESCE(st.store_id,        -1),
            -- PAYMENT TYPE FK (SCD0 hard):
            COALESCE(pt.payment_type_id, -1),
            -- KPI columns - nullable, no COALESCE
            v_rec.sales_amount,
            v_rec.discount,
            v_rec.cost,             -- monetary cost from retail source
            v_rec.quantity,
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP,
            'SA_RETAIL',
            'SRC_RETAIL_SALES'
        FROM (SELECT 1) dummy
        -- ── Dimension lookups (all LEFT JOIN) ───────
        LEFT JOIN bl_3nf.ce_dates d
                ON d.date_src_id = TO_CHAR(v_rec.event_dt, 'YYYYMMDD')
        -- SCD2 customer lookup: match by source attributes (not is_active)
        LEFT JOIN bl_3nf.ce_customers_scd cust
            ON cust.customer_src_id       = v_rec.customer_src_id
            AND cust.source_system          = 'SA_RETAIL'
            AND cust.customer_name          = COALESCE((
                    SELECT COALESCE(TRIM(r.customer_name), 'n/a')
                    FROM   sa_retail.src_retail_sales r
                    WHERE  TRIM(r.bill_id) = v_rec.sale_src_id
                    AND  r.customer_id   IS NOT NULL
                    ORDER BY r.ta_insert_dt DESC, r.transaction_date DESC
                    LIMIT  1), 'n/a')
            AND cust.customer_gender        = COALESCE((
                    SELECT COALESCE(UPPER(LEFT(TRIM(r.customer_gender),1)), 'n/a')
                    FROM   sa_retail.src_retail_sales r
                    WHERE  TRIM(r.bill_id) = v_rec.sale_src_id
                    AND  r.customer_id   IS NOT NULL
                    ORDER BY r.ta_insert_dt DESC, r.transaction_date DESC
                    LIMIT  1), 'n/a')
            AND cust.customer_email         = 'n/a'
            AND cust.customer_phone_number  = COALESCE((
                    SELECT COALESCE(TRIM(r.customer_phone_number), 'n/a')
                    FROM   sa_retail.src_retail_sales r
                    WHERE  TRIM(r.bill_id) = v_rec.sale_src_id
                    AND  r.customer_id   IS NOT NULL
                    ORDER BY r.ta_insert_dt DESC, r.transaction_date DESC
                    LIMIT  1), 'n/a')
            AND cust.customer_location_id   = COALESCE((
                    SELECT loc.location_id
                    FROM   sa_retail.src_retail_sales r
                    LEFT JOIN bl_3nf.ce_locations loc
                        ON loc.location_src_id = COALESCE(TRIM(r.customer_address),'n/a')
                            || '_' || COALESCE(TRIM(r.customer_postal_code),'n/a')
                    WHERE  TRIM(r.bill_id) = v_rec.sale_src_id
                    AND  r.customer_id   IS NOT NULL
                    ORDER BY r.ta_insert_dt DESC, r.transaction_date DESC
                    LIMIT  1), -1)
        LEFT JOIN bl_3nf.ce_employees emp
            ON emp.employee_src_id  = v_rec.employee_src_id
        -- SCD2 product lookup: match by source attributes (not is_active)
        LEFT JOIN bl_3nf.ce_products_scd prod
            ON prod.product_src_id    = v_rec.product_src_id
            AND prod.source_system      = 'SA_RETAIL'
            AND prod.product_description = COALESCE((
                    SELECT CASE WHEN TRIM(r.description) IN ('NOT-CAPTURED','') OR r.description IS NULL
                                THEN 'n/a' ELSE TRIM(r.description) END
                    FROM   sa_retail.src_retail_sales r
                    WHERE  TRIM(r.bill_id)      = v_rec.sale_src_id
                    AND  TRIM(r.product_code) = v_rec.product_src_id
                    ORDER BY r.ta_insert_dt DESC, r.transaction_date DESC
                    LIMIT  1), 'n/a')
            AND prod.product_colour      = COALESCE((
                    SELECT CASE WHEN TRIM(r.colour) IN ('NOT-CAPTURED','') OR r.colour IS NULL
                                THEN 'n/a' ELSE TRIM(r.colour) END
                    FROM   sa_retail.src_retail_sales r
                    WHERE  TRIM(r.bill_id)      = v_rec.sale_src_id
                    AND  TRIM(r.product_code) = v_rec.product_src_id
                    ORDER BY r.ta_insert_dt DESC, r.transaction_date DESC
                    LIMIT  1), 'n/a')
            AND prod.product_size        = COALESCE((
                    SELECT CASE WHEN TRIM(r.size) IN ('NOT-CAPTURED','') OR r.size IS NULL
                                THEN 'n/a' ELSE TRIM(r.size) END
                    FROM   sa_retail.src_retail_sales r
                    WHERE  TRIM(r.bill_id)      = v_rec.sale_src_id
                    AND  TRIM(r.product_code) = v_rec.product_src_id
                    ORDER BY r.ta_insert_dt DESC, r.transaction_date DESC
                    LIMIT  1), 'n/a')
            AND prod.product_min_amount  IS NOT DISTINCT FROM (
                    SELECT r.min_amount
                    FROM   sa_retail.src_retail_sales r
                    WHERE  TRIM(r.bill_id)      = v_rec.sale_src_id
                    AND  TRIM(r.product_code) = v_rec.product_src_id
                    ORDER BY r.ta_insert_dt DESC, r.transaction_date DESC
                    LIMIT  1)
        LEFT JOIN bl_3nf.ce_stores st
            ON st.store_src_id      = v_rec.store_src_id
        LEFT JOIN bl_3nf.ce_payment_types pt
            ON pt.payment_type_src_id = v_rec.payment_src_id
        -- Dedup guard: sale_src_id is unique per source — never re-insert same transaction
        WHERE NOT EXISTS (
            SELECT 1
            FROM   bl_3nf.ce_sales tgt
            WHERE  tgt.sale_src_id   = v_rec.sale_src_id
            AND  tgt.source_system = 'SA_RETAIL'
        );
        GET DIAGNOSTICS v_delta = ROW_COUNT;
        v_rows_inserted := v_rows_inserted + v_delta;
    END LOOP;

    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_sales (SA_RETAIL)',
        p_rows_inserted  => v_rows_inserted,
        p_rows_updated   => 0,
        p_status         => 'SUCCESS',
        p_source_system  => 'SA_RETAIL',
        p_source_entity  => 'SRC_RETAIL_SALES'
    );

    -- Reset counter for ECOM
    v_rows_inserted := 0;

    -- ------------------------------------------------------------
    -- 5.2  CE_SALES - Load from SA_ECOM via FOR LOOP
    --      NK grain: (payment_id, product_src_id, 'SA_ECOM')
    -- ------------------------------------------------------------
    FOR v_rec IN (SELECT * FROM bl_cl.fn_get_ce_sales_ecom())
    LOOP
        INSERT INTO bl_3nf.ce_sales (
            sale_id,
            sale_src_id,
            event_dt,
            date_id,
            customer_id,
            employee_id,
            product_id,
            store_id,
            payment_type_id,
            sales_amount,
            discount,
            cost,
            quantity,
            ta_insert_dt,
            ta_update_dt,
            source_system,
            source_entity
        )
        SELECT
            nextval('bl_3nf.seq_ce_sales'),
            v_rec.sale_src_id,
            v_rec.event_dt,
            -- DATE FK
            COALESCE(d.date_surr_id, -1)  AS date_id,
            -- CUSTOMER FK (SCD2 logical): user_id → current active version
            COALESCE(cust.customer_id,   -1),
            -- EMPLOYEE FK (SCD1 hard): ee_id
            COALESCE(emp.employee_id,    -1),
            -- PRODUCT FK (SCD2 logical): product_code → current active version
            COALESCE(prod.product_id,    -1),
            -- STORE FK: single constant 'ECOMMERCE' row
            COALESCE(st.store_id,        -1),
            -- PAYMENT TYPE FK
            COALESCE(pt.payment_type_id, -1),
            -- KPI columns
            v_rec.sales_amount,
            v_rec.discount,
            v_rec.cost,
            v_rec.quantity,
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP,
            'SA_ECOM',
            'SRC_ECOM_SALES'
        FROM (SELECT 1) dummy
        -- ── Dimension lookups (all LEFT JOIN) ────────────────────────
        LEFT JOIN bl_3nf.ce_dates d
                ON d.date_src_id = TO_CHAR(v_rec.event_dt, 'YYYYMMDD')
        -- SCD2 customer lookup: match by source attributes (not is_active)
        LEFT JOIN bl_3nf.ce_customers_scd cust
            ON cust.customer_src_id       = v_rec.customer_src_id
            AND cust.source_system          = 'SA_ECOM'
            AND cust.customer_name          = COALESCE((
                    SELECT COALESCE(TRIM(e.user_name), 'n/a')
                    FROM   sa_ecom.src_ecom_sales e
                    WHERE  TRIM(e.payment_id) = v_rec.sale_src_id
                    AND  e.user_id          IS NOT NULL
                    ORDER BY e.ta_insert_dt DESC, e.transaction_date DESC
                    LIMIT  1), 'n/a')
            AND cust.customer_gender        = COALESCE((
                    SELECT COALESCE(UPPER(LEFT(TRIM(e.user_gender),1)), 'n/a')
                    FROM   sa_ecom.src_ecom_sales e
                    WHERE  TRIM(e.payment_id) = v_rec.sale_src_id
                    AND  e.user_id          IS NOT NULL
                    ORDER BY e.ta_insert_dt DESC, e.transaction_date DESC
                    LIMIT  1), 'n/a')
            AND cust.customer_email         = COALESCE((
                    SELECT COALESCE(TRIM(e.user_email), 'n/a')
                    FROM   sa_ecom.src_ecom_sales e
                    WHERE  TRIM(e.payment_id) = v_rec.sale_src_id
                    AND  e.user_id          IS NOT NULL
                    ORDER BY e.ta_insert_dt DESC, e.transaction_date DESC
                    LIMIT  1), 'n/a')
            AND cust.customer_phone_number  = COALESCE((
                    SELECT COALESCE(TRIM(e.user_phone_number), 'n/a')
                    FROM   sa_ecom.src_ecom_sales e
                    WHERE  TRIM(e.payment_id) = v_rec.sale_src_id
                    AND  e.user_id          IS NOT NULL
                    ORDER BY e.ta_insert_dt DESC, e.transaction_date DESC
                    LIMIT  1), 'n/a')
            AND cust.customer_location_id   = COALESCE((
                    SELECT loc.location_id
                    FROM   sa_ecom.src_ecom_sales e
                    LEFT JOIN bl_3nf.ce_locations loc
                        ON loc.location_src_id = COALESCE(TRIM(e.user_address),'n/a')
                            || '_' || COALESCE(TRIM(e.user_postal_code),'n/a')
                    WHERE  TRIM(e.payment_id) = v_rec.sale_src_id
                    AND  e.user_id          IS NOT NULL
                    ORDER BY e.ta_insert_dt DESC, e.transaction_date DESC
                    LIMIT  1), -1)
        -- Employee lookup
        LEFT JOIN bl_3nf.ce_employees emp
            ON emp.employee_src_id  = v_rec.employee_src_id
        -- SCD2 product lookup: ecom products always have n/a attrs and NULL min_amount
        LEFT JOIN bl_3nf.ce_products_scd prod
            ON prod.product_src_id    = v_rec.product_src_id
            AND prod.source_system      = 'SA_ECOM'
            AND prod.product_description = 'n/a'
            AND prod.product_colour      = 'n/a'
            AND prod.product_size        = 'n/a'
            AND prod.product_min_amount  IS NULL
        -- Store lookup: always resolves to the single ECOMMERCE row
        LEFT JOIN bl_3nf.ce_stores st
            ON st.store_src_id      = 'ECOMMERCE'
        -- Payment type lookup
        LEFT JOIN bl_3nf.ce_payment_types pt
            ON pt.payment_type_src_id = v_rec.payment_src_id
        -- Dedup guard: sale_src_id is unique per source — never re-insert same transaction
        WHERE NOT EXISTS (
            SELECT 1
            FROM   bl_3nf.ce_sales tgt
            WHERE  tgt.sale_src_id   = v_rec.sale_src_id
            AND  tgt.source_system = 'SA_ECOM'
        );
        GET DIAGNOSTICS v_delta = ROW_COUNT;
        v_rows_inserted := v_rows_inserted + v_delta;
    END LOOP;

    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_sales (SA_ECOM)',
        p_rows_inserted  => v_rows_inserted,
        p_rows_updated   => 0,
        p_status         => 'SUCCESS',
        p_source_system  => 'SA_ECOM',
        p_source_entity  => 'SRC_ECOM_SALES'
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_ce_sales',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'ERROR',
        p_message        => SQLERRM
    );
    RAISE;
END;
$$;


-- ============================================================
-- ORCHESTRATOR — prc_master_load_bl3nf
-- Calls all prc_load_* in FK order using EXECUTE (dynamic SQL)
-- ============================================================

CREATE OR REPLACE PROCEDURE bl_cl.prc_master_load_bl3nf()
LANGUAGE plpgsql AS $$
DECLARE
    v_proc  TEXT;
    -- Array of procedure names in FK-safe load order
    v_procs TEXT[] := ARRAY[
        'bl_cl.prc_load_ce_store_zones',
        'bl_cl.prc_load_ce_payment_types',
        'bl_cl.prc_load_ce_product_top_categories',
        'bl_cl.prc_load_ce_product_categories',
        'bl_cl.prc_load_ce_product_subcategories',
        'bl_cl.prc_load_ce_locations',
        'bl_cl.prc_load_ce_employees',
        'bl_cl.prc_load_ce_stores',
        'bl_cl.prc_load_ce_customers_scd',
        'bl_cl.prc_load_ce_products_scd',
        'bl_cl.prc_load_ce_sales'
    ];
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE ' prc_master_load_bl3nf — START: %', CURRENT_TIMESTAMP;
    RAISE NOTICE '=================================================================';

    FOREACH v_proc IN ARRAY v_procs
    LOOP
        RAISE NOTICE '  [CALL] %', v_proc;
        EXECUTE format('CALL %s()', v_proc);
        RAISE NOTICE '  [DONE] %', v_proc;
    END LOOP;

    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_master_load_bl3nf',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'SUCCESS',
        p_message        => 'All BL_3NF procedures completed successfully.'
    );

    RAISE NOTICE '=================================================================';
    RAISE NOTICE ' prc_master_load_bl3nf — END: %', CURRENT_TIMESTAMP;
    RAISE NOTICE '=================================================================';

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_master_load_bl3nf',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'ERROR',
        p_message        => SQLERRM
    );
    RAISE;
END;
$$;


-- ============================================================
-- EXECUTION ENTRY POINT
-- Run this to execute the full BL_3NF incremental load.
-- ============================================================

CALL bl_cl.prc_master_load_bl3nf();


-- ============================================================
-- FINAL VERIFICATION - Row counts across all 12 CE_ tables
-- ============================================================

DO $$
DECLARE
    v_store_zones       INTEGER;
    v_payment_types     INTEGER;
    v_top_cats          INTEGER;
    v_categories        INTEGER;
    v_subcategories     INTEGER;
    v_locations         INTEGER;
    v_employees         INTEGER;
    v_stores            INTEGER;
    v_customers         INTEGER;
    v_products          INTEGER;
    v_sales_retail      INTEGER;
    v_sales_ecom        INTEGER;
    v_sales_total       INTEGER;
    v_errors            TEXT := '';   -- accumulates all failures
BEGIN
    SELECT COUNT(*) INTO v_store_zones    FROM bl_3nf.ce_store_zones             WHERE store_zone_id           > 0;
    SELECT COUNT(*) INTO v_payment_types  FROM bl_3nf.ce_payment_types           WHERE payment_type_id         > 0;
    SELECT COUNT(*) INTO v_top_cats       FROM bl_3nf.ce_product_top_categories  WHERE product_top_category_id > 0;
    SELECT COUNT(*) INTO v_categories     FROM bl_3nf.ce_product_categories      WHERE product_category_id     > 0;
    SELECT COUNT(*) INTO v_subcategories  FROM bl_3nf.ce_product_subcategories   WHERE product_subcategory_id  > 0;
    SELECT COUNT(*) INTO v_locations      FROM bl_3nf.ce_locations               WHERE location_id             > 0;
    SELECT COUNT(*) INTO v_employees      FROM bl_3nf.ce_employees               WHERE employee_id             > 0;
    SELECT COUNT(*) INTO v_stores         FROM bl_3nf.ce_stores                  WHERE store_id                > 0;
    SELECT COUNT(*) INTO v_customers      FROM bl_3nf.ce_customers_scd           WHERE customer_id             > 0;
    SELECT COUNT(*) INTO v_products       FROM bl_3nf.ce_products_scd            WHERE product_id              > 0;
    SELECT COUNT(*) INTO v_sales_retail   FROM bl_3nf.ce_sales                   WHERE source_system = 'SA_RETAIL';
    SELECT COUNT(*) INTO v_sales_ecom     FROM bl_3nf.ce_sales                   WHERE source_system = 'SA_ECOM';
    SELECT COUNT(*) INTO v_sales_total    FROM bl_3nf.ce_sales;

    -- ── Print summary ────────────────────────────────────────────
    RAISE NOTICE '=================================================================';
    RAISE NOTICE ' BL_3NF INCREMENTAL LOAD - FINAL ROW COUNT SUMMARY';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE '  GROUP 1 - SCD Type 0:';
    RAISE NOTICE '    ce_store_zones              business rows: %',  v_store_zones;
    RAISE NOTICE '    ce_payment_types            business rows: %',  v_payment_types;
    RAISE NOTICE '-----------------------------------------------------------------';
    RAISE NOTICE '  GROUP 2 - SCD Type 1 (product hierarchy):';
    RAISE NOTICE '    ce_product_top_categories   business rows: %',  v_top_cats;
    RAISE NOTICE '    ce_product_categories       business rows: %',  v_categories;
    RAISE NOTICE '    ce_product_subcategories    business rows: %',  v_subcategories;
    RAISE NOTICE '-----------------------------------------------------------------';
    RAISE NOTICE '  GROUP 3 - SCD Type 1 (address + store chain):';
    RAISE NOTICE '    ce_locations                business rows: %',  v_locations;
    RAISE NOTICE '    ce_employees                business rows: %',  v_employees;
    RAISE NOTICE '    ce_stores                   business rows: %',  v_stores;
    RAISE NOTICE '-----------------------------------------------------------------';
    RAISE NOTICE '  GROUP 4 - SCD Type 2:';
    RAISE NOTICE '    ce_customers_scd            business rows: %',  v_customers;
    RAISE NOTICE '    ce_products_scd             business rows: %',  v_products;
    RAISE NOTICE '-----------------------------------------------------------------';
    RAISE NOTICE '  GROUP 5 - Fact table:';
    RAISE NOTICE '    ce_sales  SA_RETAIL          rows: %',  v_sales_retail;
    RAISE NOTICE '    ce_sales  SA_ECOM             rows: %',  v_sales_ecom;
    RAISE NOTICE '    ce_sales  TOTAL               rows: %',  v_sales_total;
    RAISE NOTICE '=================================================================';

    -- ── Validate every table - accumulate failures ───────────────
    IF v_store_zones    = 0 THEN v_errors := v_errors || '  [FAIL] ce_store_zones            = 0 business rows' || chr(10); END IF;
    IF v_payment_types  = 0 THEN v_errors := v_errors || '  [FAIL] ce_payment_types          = 0 business rows' || chr(10); END IF;
    IF v_top_cats       = 0 THEN v_errors := v_errors || '  [FAIL] ce_product_top_categories = 0 business rows' || chr(10); END IF;
    IF v_categories     = 0 THEN v_errors := v_errors || '  [FAIL] ce_product_categories     = 0 business rows' || chr(10); END IF;
    IF v_subcategories  = 0 THEN v_errors := v_errors || '  [FAIL] ce_product_subcategories  = 0 business rows' || chr(10); END IF;
    IF v_locations      = 0 THEN v_errors := v_errors || '  [FAIL] ce_locations              = 0 business rows' || chr(10); END IF;
    IF v_employees      = 0 THEN v_errors := v_errors || '  [FAIL] ce_employees              = 0 business rows' || chr(10); END IF;
    IF v_stores         = 0 THEN v_errors := v_errors || '  [FAIL] ce_stores                 = 0 business rows' || chr(10); END IF;
    IF v_customers      = 0 THEN v_errors := v_errors || '  [FAIL] ce_customers_scd          = 0 business rows' || chr(10); END IF;
    IF v_products       = 0 THEN v_errors := v_errors || '  [FAIL] ce_products_scd           = 0 business rows' || chr(10); END IF;
    IF v_sales_retail   = 0 THEN v_errors := v_errors || '  [FAIL] ce_sales SA_RETAIL        = 0 rows'          || chr(10); END IF;
    IF v_sales_ecom     = 0 THEN v_errors := v_errors || '  [FAIL] ce_sales SA_ECOM          = 0 rows'          || chr(10); END IF;
    IF v_sales_total    = 0 THEN v_errors := v_errors || '  [FAIL] ce_sales TOTAL            = 0 rows'          || chr(10); END IF;

    -- ── Final verdict ────────────────────────────────────────────
    IF v_errors <> '' THEN
        RAISE EXCEPTION E'BL_3NF load verification FAILED - empty tables detected:\n%', v_errors;
    END IF;

    RAISE NOTICE '  [OK] All tables passed row-count verification.';
    RAISE NOTICE '  BL_3NF load completed successfully.';
    RAISE NOTICE '=================================================================';
END;
$$;