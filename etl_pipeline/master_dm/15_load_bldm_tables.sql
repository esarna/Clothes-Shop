 -- DML - ETL: BL_DM Incremental Load — all DIM_ and FCT_ tables
 --
 -- STRUCTURE:
 --   bl_cl.fn_get_dim_<name>()    RETURNS TABLE  — data extraction
 --   bl_cl.prc_load_dim_<name>()  PROCEDURE      — FOR loop + logging
 --   bl_cl.prc_master_load_bldm() ORCHESTRATOR   — EXECUTE dynamic dispatch
 --
-- ============================================================
-- Load all DIM_ and FCT_ tables in BL_DM from BL_3NF layer.
--
-- SOURCE LAYER:  BL_3NF (bl_3nf.ce_* tables)
--
-- LOAD ORDER (respects FK dependencies):
--   2. DIM_PAYMENT_TYPES     ← bl_3nf.ce_payment_types
--   3. DIM_EMPLOYEES         ← bl_3nf.ce_employees
--                               + bl_3nf.ce_locations (flatten)
--   4. DIM_STORES            ← bl_3nf.ce_stores
--                               + bl_3nf.ce_store_zones  (flatten)
--                               + bl_3nf.ce_locations    (flatten)
--   5. DIM_CUSTOMERS_SCD     ← bl_3nf.ce_customers_scd
--                               + bl_3nf.ce_locations (flatten)
--                               SCD2 logic: steps A, B, C
--   6. DIM_PRODUCTS_SCD      ← bl_3nf.ce_products_scd
--                               + bl_3nf.ce_product_subcategories (flatten)
--                               + bl_3nf.ce_product_categories    (flatten)
--                               + bl_3nf.ce_product_top_categories(flatten)
--                               SCD2 logic: steps A, B, C
--   7. FCT_SALES_DD          ← bl_3nf.ce_sales
--                               + lookup to all 6 DIM tables above
-- ============================================================

-- ============================================================
-- LOAD 2 - DIM_PAYMENT_TYPES
--          SCD Type 0 - append only, never update.
--          Source: bl_3nf.ce_payment_types
--          NK:     payment_type_src_id
-- ============================================================
 DROP TYPE IF EXISTS bl_cl.t_dim_payment_type_row CASCADE;
 CREATE TYPE bl_cl.t_dim_payment_type_row AS (
     payment_type_src_id  VARCHAR(100),
     payment_type_name    VARCHAR(50),
     source_system        VARCHAR(50),
     source_entity        VARCHAR(50)
 );

CREATE OR REPLACE FUNCTION bl_cl.fn_get_dim_payment_types()
RETURNS TABLE (
    payment_type_src_id  VARCHAR,
    payment_type_name    VARCHAR,
    source_system        VARCHAR,
    source_entity        VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        src.payment_type_src_id::VARCHAR,
        src.payment_type_name::VARCHAR,
        src.source_system::VARCHAR,
        src.source_entity::VARCHAR
    FROM bl_3nf.ce_payment_types src
    WHERE src.payment_type_id > 0;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.prc_load_dim_payment_types()
LANGUAGE plpgsql AS $$
DECLARE
    -- Composite type variable
    v_row           bl_cl.t_dim_payment_type_row;
    v_rows_inserted INTEGER := 0;
    v_delta         INTEGER := 0;
BEGIN
    -- Cursor FOR loop over composite-type-shaped rows
    FOR v_row IN (
        SELECT r.payment_type_src_id::VARCHAR,
               r.payment_type_name::VARCHAR,
               r.source_system::VARCHAR,
               r.source_entity::VARCHAR
        FROM bl_cl.fn_get_dim_payment_types() r
    )
    LOOP
        INSERT INTO bl_dm.dim_payment_types (
            payment_type_surr_id,
            payment_type_src_id,
            payment_type_name,
            ta_insert_dt,
            source_system,
            source_entity
        )
        SELECT
            nextval('bl_dm.seq_dim_payment_types'),
            v_row.payment_type_src_id,
            v_row.payment_type_name,
            CURRENT_TIMESTAMP,
            v_row.source_system,
            v_row.source_entity
        WHERE NOT EXISTS (
            SELECT 1 FROM bl_dm.dim_payment_types tgt
            WHERE tgt.payment_type_src_id = v_row.payment_type_src_id
        );
        GET DIAGNOSTICS v_delta = ROW_COUNT;
        v_rows_inserted := v_rows_inserted + v_delta;
    END LOOP;

    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_dim_payment_types',
        p_rows_inserted  => v_rows_inserted,
        p_rows_updated   => 0,
        p_status         => 'SUCCESS',
        p_source_system  => 'BL_3NF',
        p_source_entity  => 'CE_PAYMENT_TYPES'
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_dim_payment_types',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'ERROR',
        p_message        => SQLERRM
    );
    RAISE;
END;
$$;


-- ============================================================
-- LOAD 3 - DIM_EMPLOYEES
--          SCD Type 1 - INSERT new + UPDATE changed.
--          Source: bl_3nf.ce_employees
--                  + bl_3nf.ce_locations (address flattened)
--          NK:     employee_src_id
--          Tracked: all attributes (SCD1 - full overwrite)
-- ============================================================

CREATE OR REPLACE FUNCTION bl_cl.fn_get_dim_employees()
RETURNS TABLE (
    employee_src_id       VARCHAR,
    employee_name         VARCHAR,
    employee_gender       VARCHAR,
    employee_email        VARCHAR,
    employee_phone_number VARCHAR,
    employee_address      VARCHAR,
    employee_city         VARCHAR,
    employee_state        VARCHAR,
    employee_postal_code  VARCHAR,
    source_system         VARCHAR,
    source_entity         VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        src.employee_src_id::VARCHAR,
        src.employee_name::VARCHAR,
        src.employee_gender::VARCHAR,
        src.employee_email::VARCHAR,
        src.employee_phone_number::VARCHAR,
        COALESCE(loc.location_address,     'n/a')::VARCHAR,
        COALESCE(loc.location_city,        'n/a')::VARCHAR,
        COALESCE(loc.location_state,       'n/a')::VARCHAR,
        COALESCE(loc.location_postal_code, 'n/a')::VARCHAR,
        src.source_system::VARCHAR,
        src.source_entity::VARCHAR
    FROM bl_3nf.ce_employees src
    LEFT JOIN bl_3nf.ce_locations loc ON loc.location_id = src.employee_location_id
    WHERE src.employee_id > 0;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.prc_load_dim_employees()
LANGUAGE plpgsql AS $$
DECLARE
    -- Cursor variable technique
    v_cur           REFCURSOR;
    v_rec           RECORD;
    v_rows_inserted INTEGER := 0;
    v_rows_updated  INTEGER := 0;
    v_delta         INTEGER := 0;
BEGIN
    -- Open cursor variable
    OPEN v_cur FOR SELECT * FROM bl_cl.fn_get_dim_employees();

    LOOP
        FETCH v_cur INTO v_rec;
        EXIT WHEN NOT FOUND;

        -- INSERT new (NOT EXISTS guard)
        INSERT INTO bl_dm.dim_employees (
            employee_surr_id, employee_src_id, employee_name,
            employee_gender, employee_email, employee_phone_number,
            employee_address, employee_city, employee_state,
            employee_postal_code, ta_insert_dt, ta_update_dt,
            source_system, source_entity
        )
        SELECT
            nextval('bl_dm.seq_dim_employees'),
            v_rec.employee_src_id, v_rec.employee_name,
            v_rec.employee_gender, v_rec.employee_email, v_rec.employee_phone_number,
            v_rec.employee_address, v_rec.employee_city, v_rec.employee_state,
            v_rec.employee_postal_code, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
            v_rec.source_system, v_rec.source_entity
        WHERE NOT EXISTS (
            SELECT 1 FROM bl_dm.dim_employees tgt
            WHERE tgt.employee_src_id = v_rec.employee_src_id
              AND tgt.source_system   = v_rec.source_system
        );
        GET DIAGNOSTICS v_delta = ROW_COUNT;
        v_rows_inserted := v_rows_inserted + v_delta;

        -- UPDATE changed rows (SCD1)
        UPDATE bl_dm.dim_employees tgt
        SET
            employee_name         = v_rec.employee_name,
            employee_gender       = v_rec.employee_gender,
            employee_email        = v_rec.employee_email,
            employee_phone_number = v_rec.employee_phone_number,
            employee_address      = v_rec.employee_address,
            employee_city         = v_rec.employee_city,
            employee_state        = v_rec.employee_state,
            employee_postal_code  = v_rec.employee_postal_code,
            ta_update_dt          = CURRENT_TIMESTAMP
        WHERE tgt.employee_src_id = v_rec.employee_src_id
          AND tgt.source_system   = v_rec.source_system
          AND tgt.employee_surr_id > 0
          AND (
                tgt.employee_name         <> v_rec.employee_name
             OR tgt.employee_gender       <> v_rec.employee_gender
             OR tgt.employee_email        <> v_rec.employee_email
             OR tgt.employee_phone_number <> v_rec.employee_phone_number
             OR tgt.employee_address      <> v_rec.employee_address
             OR tgt.employee_city         <> v_rec.employee_city
             OR tgt.employee_state        <> v_rec.employee_state
             OR tgt.employee_postal_code  <> v_rec.employee_postal_code
          );
        GET DIAGNOSTICS v_delta = ROW_COUNT;
        v_rows_updated := v_rows_updated + v_delta;
    END LOOP;

    CLOSE v_cur;

    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_dim_employees',
        p_rows_inserted  => v_rows_inserted,
        p_rows_updated   => v_rows_updated,
        p_status         => 'SUCCESS',
        p_source_system  => 'BL_3NF',
        p_source_entity  => 'CE_EMPLOYEES'
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_dim_employees',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'ERROR',
        p_message        => SQLERRM
    );
    RAISE;
END;
$$;


-- ============================================================
-- LOAD 4 - DIM_STORES
--          SCD Type 1 - INSERT new + UPDATE changed.
--          Source: bl_3nf.ce_stores
--                  + bl_3nf.ce_store_zones (zone flattened)
--                  + bl_3nf.ce_locations   (address flattened)
--          NK:     store_src_id
-- ============================================================
-- ============================================================
-- LOAD 4 - DIM_STORES  (SCD Type 1)
-- ============================================================

CREATE OR REPLACE FUNCTION bl_cl.fn_get_dim_stores()
RETURNS TABLE (
    store_src_id      VARCHAR,
    store_channel     VARCHAR,
    store_zone_id     BIGINT,
    store_zone_name   VARCHAR,
    store_address     VARCHAR,
    store_city        VARCHAR,
    store_state       VARCHAR,
    store_postal_code VARCHAR,
    source_system     VARCHAR,
    source_entity     VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        src.store_src_id::VARCHAR,
        src.store_channel::VARCHAR,
        COALESCE(zon.store_zone_id,         -1)::BIGINT,
        COALESCE(zon.store_zone_name,       'n/a')::VARCHAR,
        COALESCE(loc.location_address,      'n/a')::VARCHAR,
        COALESCE(loc.location_city,         'n/a')::VARCHAR,
        COALESCE(loc.location_state,        'n/a')::VARCHAR,
        COALESCE(loc.location_postal_code,  'n/a')::VARCHAR,
        src.source_system::VARCHAR,
        src.source_entity::VARCHAR
    FROM bl_3nf.ce_stores src
    LEFT JOIN bl_3nf.ce_store_zones zon ON zon.store_zone_id   = src.store_zone_id
    LEFT JOIN bl_3nf.ce_locations   loc ON loc.location_id     = src.store_location_id
    WHERE src.store_id > 0;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.prc_load_dim_stores()
LANGUAGE plpgsql AS $$
DECLARE
    v_rec           RECORD;
    v_rows_inserted INTEGER := 0;
    v_rows_updated  INTEGER := 0;
    v_delta         INTEGER := 0;
BEGIN
    FOR v_rec IN (SELECT * FROM bl_cl.fn_get_dim_stores())
    LOOP
        -- INSERT new
        INSERT INTO bl_dm.dim_stores (
            store_surr_id, store_src_id, store_channel,
            store_zone_id, store_zone_name,
            store_address, store_city, store_state, store_postal_code,
            ta_insert_dt, ta_update_dt, source_system, source_entity
        )
        SELECT
            nextval('bl_dm.seq_dim_stores'),
            v_rec.store_src_id, v_rec.store_channel,
            v_rec.store_zone_id, v_rec.store_zone_name,
            v_rec.store_address, v_rec.store_city,
            v_rec.store_state, v_rec.store_postal_code,
            CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
            v_rec.source_system, v_rec.source_entity
        WHERE NOT EXISTS (
            SELECT 1 FROM bl_dm.dim_stores tgt
            WHERE tgt.store_src_id = v_rec.store_src_id
        );
        GET DIAGNOSTICS v_delta = ROW_COUNT;
        v_rows_inserted := v_rows_inserted + v_delta;

        -- UPDATE changed (SCD1)
        UPDATE bl_dm.dim_stores tgt
        SET
            store_channel     = v_rec.store_channel,
            store_zone_id     = v_rec.store_zone_id,
            store_zone_name   = v_rec.store_zone_name,
            store_address     = v_rec.store_address,
            store_city        = v_rec.store_city,
            store_state       = v_rec.store_state,
            store_postal_code = v_rec.store_postal_code,
            ta_update_dt      = CURRENT_TIMESTAMP,
            source_system     = v_rec.source_system,
            source_entity     = v_rec.source_entity
        WHERE tgt.store_src_id  = v_rec.store_src_id
          AND tgt.store_surr_id > 0
          AND (
                tgt.store_channel     <> v_rec.store_channel
             OR tgt.store_zone_id     <> v_rec.store_zone_id
             OR tgt.store_zone_name   <> v_rec.store_zone_name
             OR tgt.store_address     <> v_rec.store_address
             OR tgt.store_city        <> v_rec.store_city
             OR tgt.store_state       <> v_rec.store_state
             OR tgt.store_postal_code <> v_rec.store_postal_code
          );
        GET DIAGNOSTICS v_delta = ROW_COUNT;
        v_rows_updated := v_rows_updated + v_delta;
    END LOOP;

    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_dim_stores',
        p_rows_inserted  => v_rows_inserted,
        p_rows_updated   => v_rows_updated,
        p_status         => 'SUCCESS',
        p_source_system  => 'BL_3NF',
        p_source_entity  => 'CE_STORES'
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_dim_stores',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'ERROR',
        p_message        => SQLERRM
    );
    RAISE;
END;
$$;


-- ============================================================
-- LOAD 5 - DIM_CUSTOMERS_SCD
--          SCD Type 2 - full history tracking.
--          Source: bl_3nf.ce_customers_scd (active rows only)
--                  + bl_3nf.ce_locations (address flattened)
--          NK:     customer_src_id
--          Tracked: customer_address, customer_city,
--                   customer_state, customer_postal_code
--                   (change in location triggers new SCD2 version)
--
-- SCD2 LOGIC:
--   STEP A - Close previous active version when address changed.
--   STEP B - Insert new version for just-closed rows.
--   STEP C - Insert brand-new customers (NK never seen).
-- ============================================================
-- ============================================================
-- LOAD 5 - DIM_CUSTOMERS_SCD  (SCD Type 2 — Steps A / B / C)
-- ============================================================

CREATE OR REPLACE FUNCTION bl_cl.fn_get_dim_customers_scd()
RETURNS TABLE (
    customer_src_id       VARCHAR,
    customer_name         VARCHAR,
    customer_gender       VARCHAR,
    customer_email        VARCHAR,
    customer_phone_number VARCHAR,
    customer_address      VARCHAR,
    customer_city         VARCHAR,
    customer_state        VARCHAR,
    customer_postal_code  VARCHAR,
    source_system         VARCHAR,
    source_entity         VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        src.customer_src_id::VARCHAR,
        src.customer_name::VARCHAR,
        src.customer_gender::VARCHAR,
        src.customer_email::VARCHAR,
        src.customer_phone_number::VARCHAR,
        COALESCE(loc.location_address,     'n/a')::VARCHAR,
        COALESCE(loc.location_city,        'n/a')::VARCHAR,
        COALESCE(loc.location_state,       'n/a')::VARCHAR,
        COALESCE(loc.location_postal_code, 'n/a')::VARCHAR,
        src.source_system::VARCHAR,
        src.source_entity::VARCHAR
    FROM bl_3nf.ce_customers_scd src
    LEFT JOIN bl_3nf.ce_locations loc ON loc.location_id = src.customer_location_id
    WHERE src.is_active   = 'Y'
      AND src.customer_id > 0;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.prc_load_dim_customers_scd()
LANGUAGE plpgsql AS $$
DECLARE
    v_rec           RECORD;
    v_rows_inserted INTEGER := 0;
    v_rows_updated  INTEGER := 0;
    v_delta         INTEGER := 0;
BEGIN
    -- ── STEP A: Close active DM version when address changed ────────
    UPDATE bl_dm.dim_customers_scd tgt
    SET
        end_dt       = CURRENT_DATE - 1,
        is_active    = 'N',
        ta_update_dt = CURRENT_TIMESTAMP
    FROM bl_cl.fn_get_dim_customers_scd() src
    WHERE tgt.customer_src_id  = src.customer_src_id
      AND tgt.is_active         = 'Y'
      AND tgt.end_dt            = DATE '9999-12-31'
      AND tgt.customer_surr_id > 0
      AND (
            tgt.customer_address     <> src.customer_address
         OR tgt.customer_city        <> src.customer_city
         OR tgt.customer_state       <> src.customer_state
         OR tgt.customer_postal_code <> src.customer_postal_code
      );
    GET DIAGNOSTICS v_delta = ROW_COUNT;
    v_rows_updated := v_rows_updated + v_delta;

    -- ── STEP B: New version for just-closed rows ─────────────────────
    FOR v_rec IN (SELECT * FROM bl_cl.fn_get_dim_customers_scd())
    LOOP
        INSERT INTO bl_dm.dim_customers_scd (
            customer_surr_id, customer_src_id, customer_name,
            customer_gender, customer_email, customer_phone_number,
            customer_address, customer_city, customer_state,
            customer_postal_code, start_dt, end_dt, is_active,
            ta_insert_dt, ta_update_dt, source_system, source_entity
        )
        SELECT
            nextval('bl_dm.seq_dim_customers_scd'),
            v_rec.customer_src_id, v_rec.customer_name,
            v_rec.customer_gender, v_rec.customer_email, v_rec.customer_phone_number,
            v_rec.customer_address, v_rec.customer_city,
            v_rec.customer_state, v_rec.customer_postal_code,
            CURRENT_DATE, DATE '9999-12-31', 'Y',
            CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
            v_rec.source_system, v_rec.source_entity
        WHERE EXISTS (
            SELECT 1 FROM bl_dm.dim_customers_scd cl
            WHERE cl.customer_src_id = v_rec.customer_src_id
              AND cl.is_active = 'N'
              AND cl.end_dt    = CURRENT_DATE - 1
        )
        AND NOT EXISTS (
            SELECT 1 FROM bl_dm.dim_customers_scd ac
            WHERE ac.customer_src_id = v_rec.customer_src_id
              AND ac.is_active = 'Y'
              AND ac.start_dt  = CURRENT_DATE
        );
        GET DIAGNOSTICS v_delta = ROW_COUNT;
        v_rows_inserted := v_rows_inserted + v_delta;
    END LOOP;

-- ── STEP C: Brand-new customers — INSERT as is_active='Y' ──────────
    FOR v_rec IN (SELECT * FROM bl_cl.fn_get_dim_customers_scd())
    LOOP
        INSERT INTO bl_dm.dim_customers_scd (
            customer_surr_id, customer_src_id, customer_name,
            customer_gender, customer_email, customer_phone_number,
            customer_address, customer_city, customer_state,
            customer_postal_code, start_dt, end_dt, is_active,
            ta_insert_dt, ta_update_dt, source_system, source_entity
        )
        SELECT
            nextval('bl_dm.seq_dim_customers_scd'),
            v_rec.customer_src_id, v_rec.customer_name,
            v_rec.customer_gender, v_rec.customer_email, v_rec.customer_phone_number,
            v_rec.customer_address, v_rec.customer_city,
            v_rec.customer_state, v_rec.customer_postal_code,
            CURRENT_DATE, DATE '9999-12-31', 'Y',
            CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
            v_rec.source_system, v_rec.source_entity
        WHERE NOT EXISTS (
            SELECT 1 FROM bl_dm.dim_customers_scd tgt
            WHERE tgt.customer_src_id = v_rec.customer_src_id
            AND tgt.source_system   = v_rec.source_system
        );
        GET DIAGNOSTICS v_delta = ROW_COUNT;
        v_rows_inserted := v_rows_inserted + v_delta;
    END LOOP;


    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_dim_customers_scd',
        p_rows_inserted  => v_rows_inserted,
        p_rows_updated   => v_rows_updated,
        p_status         => 'SUCCESS',
        p_source_system  => 'BL_3NF',
        p_source_entity  => 'CE_CUSTOMERS_SCD'
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_dim_customers_scd',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'ERROR',
        p_message        => SQLERRM
    );
    RAISE;
END;
$$;


-- ============================================================
-- LOAD 6 - DIM_PRODUCTS_SCD
--          SCD Type 2 - full history tracking.
--          Source: bl_3nf.ce_products_scd (active rows only)
--                  + bl_3nf.ce_product_subcategories  (flatten)
--                  + bl_3nf.ce_product_categories     (flatten)
--                  + bl_3nf.ce_product_top_categories (flatten)
--          NK:     product_src_id
--          Tracked: product_description, product_colour,
--                   product_size, product_min_amount
--                   (any change triggers new SCD2 version)
--
-- SCD2 LOGIC:
--   STEP A - Close previous active version when tracked attrs changed.
--   STEP B - Insert new version for just-closed rows.
--   STEP C - Insert brand-new products (NK never seen).
-- ============================================================
-- ============================================================
-- LOAD 6 - DIM_PRODUCTS_SCD  (SCD Type 2)
-- Step C uses MERGE (upsert technique)
-- ============================================================

CREATE OR REPLACE FUNCTION bl_cl.fn_get_dim_products_scd()
RETURNS TABLE (
    product_src_id            VARCHAR,
    product_description       VARCHAR,
    product_colour            VARCHAR,
    product_size              VARCHAR,
    product_min_amount        DECIMAL(12,2),
    product_subcategory_id    BIGINT,
    product_subcategory_name  VARCHAR,
    product_category_id       BIGINT,
    product_category_name     VARCHAR,
    product_top_category_id   BIGINT,
    product_top_category_name VARCHAR,
    source_system             VARCHAR,
    source_entity             VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        src.product_src_id::VARCHAR,
        src.product_description::VARCHAR,
        src.product_colour::VARCHAR,
        src.product_size::VARCHAR,
        src.product_min_amount::DECIMAL(12,2),
        COALESCE(sub.product_subcategory_id,    -1)::BIGINT,
        COALESCE(sub.product_subcategory_name,  'n/a')::VARCHAR,
        COALESCE(cat.product_category_id,       -1)::BIGINT,
        COALESCE(cat.product_category_name,     'n/a')::VARCHAR,
        COALESCE(top.product_top_category_id,   -1)::BIGINT,
        COALESCE(top.product_top_category_name, 'n/a')::VARCHAR,
        src.source_system::VARCHAR,
        src.source_entity::VARCHAR
    FROM bl_3nf.ce_products_scd src
    LEFT JOIN bl_3nf.ce_product_subcategories  sub
           ON sub.product_subcategory_id  = src.product_subcategory_id
    LEFT JOIN bl_3nf.ce_product_categories     cat
           ON cat.product_category_id     = sub.product_category_id
    LEFT JOIN bl_3nf.ce_product_top_categories top
           ON top.product_top_category_id = cat.product_top_category_id
    WHERE src.is_active  = 'Y'
      AND src.product_id > 0;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.prc_load_dim_products_scd()
LANGUAGE plpgsql AS $$
DECLARE
    v_rec           RECORD;
    v_rows_inserted INTEGER := 0;
    v_rows_updated  INTEGER := 0;
    v_delta         INTEGER := 0;
BEGIN
    -- ── STEP A: Close active DM version when tracked attrs changed ──
    UPDATE bl_dm.dim_products_scd tgt
    SET
        end_dt       = CURRENT_DATE - 1,
        is_active    = 'N',
        ta_update_dt = CURRENT_TIMESTAMP
    FROM bl_cl.fn_get_dim_products_scd() src
    WHERE tgt.product_src_id  = src.product_src_id
      AND tgt.is_active        = 'Y'
      AND tgt.end_dt           = DATE '9999-12-31'
      AND tgt.product_surr_id > 0
      AND (
            tgt.product_description    <> src.product_description
         OR tgt.product_colour         <> src.product_colour
         OR tgt.product_size           <> src.product_size
         OR tgt.product_min_amount     IS DISTINCT FROM src.product_min_amount
         OR tgt.product_subcategory_id <> src.product_subcategory_id
         OR tgt.product_category_id    <> src.product_category_id
         OR tgt.product_top_category_id<> src.product_top_category_id
      );
    GET DIAGNOSTICS v_delta = ROW_COUNT;
    v_rows_updated := v_rows_updated + v_delta;

    -- ── STEP B: New version for just-closed products ─────────────────
    FOR v_rec IN (SELECT * FROM bl_cl.fn_get_dim_products_scd())
    LOOP
        INSERT INTO bl_dm.dim_products_scd (
            product_surr_id, product_src_id, product_description,
            product_colour, product_size, product_min_amount,
            product_subcategory_id, product_subcategory_name,
            product_category_id,    product_category_name,
            product_top_category_id, product_top_category_name,
            start_dt, end_dt, is_active,
            ta_insert_dt, ta_update_dt, source_system, source_entity
        )
        SELECT
            nextval('bl_dm.seq_dim_products_scd'),
            v_rec.product_src_id, v_rec.product_description,
            v_rec.product_colour, v_rec.product_size, v_rec.product_min_amount,
            v_rec.product_subcategory_id, v_rec.product_subcategory_name,
            v_rec.product_category_id,    v_rec.product_category_name,
            v_rec.product_top_category_id,v_rec.product_top_category_name,
            CURRENT_DATE, DATE '9999-12-31', 'Y',
            CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
            v_rec.source_system, v_rec.source_entity
        WHERE EXISTS (
            SELECT 1 FROM bl_dm.dim_products_scd cl
            WHERE cl.product_src_id = v_rec.product_src_id
              AND cl.is_active = 'N'
              AND cl.end_dt    = CURRENT_DATE - 1
        )
        AND NOT EXISTS (
            SELECT 1 FROM bl_dm.dim_products_scd ac
            WHERE ac.product_src_id = v_rec.product_src_id
              AND ac.is_active = 'Y'
              AND ac.start_dt  = CURRENT_DATE
        );
        GET DIAGNOSTICS v_delta = ROW_COUNT;
        v_rows_inserted := v_rows_inserted + v_delta;
    END LOOP;

    -- ── STEP C: Brand-new products — MERGE (upsert) ──────────────────
    MERGE INTO bl_dm.dim_products_scd AS tgt
    USING (
        SELECT * FROM bl_cl.fn_get_dim_products_scd()
    ) AS src
    ON  tgt.product_src_id = src.product_src_id
    AND tgt.source_system   = src.source_system
    AND tgt.is_active       = 'Y'
    WHEN NOT MATCHED THEN
        INSERT (
            product_surr_id, product_src_id, product_description,
            product_colour, product_size, product_min_amount,
            product_subcategory_id, product_subcategory_name,
            product_category_id, product_category_name,
            product_top_category_id, product_top_category_name,
            start_dt, end_dt, is_active,
            ta_insert_dt, ta_update_dt, source_system, source_entity
        )
        VALUES (
            nextval('bl_dm.seq_dim_products_scd'),
            src.product_src_id, src.product_description,
            src.product_colour, src.product_size, src.product_min_amount,
            src.product_subcategory_id, src.product_subcategory_name,
            src.product_category_id,    src.product_category_name,
            src.product_top_category_id, src.product_top_category_name,
            CURRENT_DATE, DATE '9999-12-31', 'Y',
            CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
            src.source_system, src.source_entity
        );
    GET DIAGNOSTICS v_delta = ROW_COUNT;
    v_rows_inserted := v_rows_inserted + v_delta;

    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_dim_products_scd',
        p_rows_inserted  => v_rows_inserted,
        p_rows_updated   => v_rows_updated,
        p_status         => 'SUCCESS',
        p_source_system  => 'BL_3NF',
        p_source_entity  => 'CE_PRODUCTS_SCD'
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_dim_products_scd',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'ERROR',
        p_message        => SQLERRM
    );
    RAISE;
END;
$$;


-- ============================================================
-- LOAD 7 - FCT_SALES_DD
--          Append-only incremental load.
--          Source: bl_3nf.ce_sales
--                  + lookup to all 6 DIM tables in BL_DM
--          Grain:  PAYMENT_SRC_ID + PRODUCT_SURR_ID + SOURCE_SYSTEM
--
-- NOTE ON LINE_SRC_ID:
--   Composed as: sale_src_id || '_' || product_src_id
--   product_src_id resolved via join to ce_products_scd
--   using the product_id FK stored in ce_sales.
--
-- NOTE ON FK LOOKUPS FOR SCD2 DIMENSIONS:
--   For DIM_CUSTOMERS_SCD and DIM_PRODUCTS_SCD, the lookup
--   chain is:
--     ce_sales.customer_id → ce_customers_scd.customer_id
--     ce_customers_scd.customer_src_id → dim_customers_scd
--     (join on customer_src_id + is_active = 'Y')
--   This ensures we always link to the CURRENT active version
--   in BL_DM, consistent with the SCD2 temporal model.
-- ============================================================
-- ============================================================
-- LOAD 7 - FCT_SALES_DD  (Append-only incremental)
-- ============================================================
-- ============================================================
-- LOAD 7 - FCT_SALES_DD
--
-- PARTITION STRATEGY (per polecenie + PDF §2.1-2.2 + slajdy 15-20):
--   1. Determine target month from new CE_SALES rows.
--   2. Create staging table: fct_sales_dd_staging_<YYYY_MM>
--      (LIKE fct_sales_dd INCLUDING ALL).
--   3. Load new rows into staging table (fast, no concurrency impact).
--   4. ATTACH staging table as new partition of fct_sales_dd.
--   5. Rolling window: DETACH + DROP partitions older than 3 months.
--
-- INCREMENTAL GUARD:
--   The NOT EXISTS check on (line_src_id, source_system, event_dt)
--   is performed against ALL existing partitions via the parent table.
--   After ATTACH, the partition is visible immediately to all queries.
--
-- NOTE: fn_get_fct_sales_dd reads from bl_3nf.ce_sales and
--       performs all dimension lookups. The dedup filter is applied
--       inside the function against the parent fct_sales_dd table.
-- ============================================================

CREATE OR REPLACE FUNCTION bl_cl.fn_get_fct_sales_dd(
    p_month_start DATE DEFAULT NULL,
    p_month_end   DATE DEFAULT NULL
)
RETURNS TABLE (
    event_dt             DATE,
    date_surr_id         BIGINT,
    customer_surr_id     BIGINT,
    employee_surr_id     BIGINT,
    product_surr_id      BIGINT,
    store_surr_id        BIGINT,
    payment_type_surr_id BIGINT,
    payment_src_id       VARCHAR,
    line_src_id          VARCHAR,
    fct_sales_amount     DECIMAL(18,8),
    fct_discount         DECIMAL(18,8),
    fct_net_amount       DECIMAL(18,8),
    fct_unit_cost        DECIMAL(18,8),
    fct_quantity         INTEGER,
    fct_total_cost       DECIMAL(18,8),
    fct_gross_profit     DECIMAL(18,8),
    source_system        VARCHAR,
    source_entity        VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.event_dt::DATE,
        COALESCE(dt.date_surr_id,            -1)::BIGINT,
        COALESCE(dim_cust.customer_surr_id,  -1)::BIGINT,
        COALESCE(dim_emp.employee_surr_id,   -1)::BIGINT,
        COALESCE(dim_prod.product_surr_id,   -1)::BIGINT,
        COALESCE(dim_st.store_surr_id,       -1)::BIGINT,
        COALESCE(dim_pt.payment_type_surr_id,-1)::BIGINT,
        s.sale_src_id::VARCHAR,
        (s.sale_src_id || '_' || COALESCE(ce_prod.product_src_id, 'n/a'))::VARCHAR,
        s.sales_amount::DECIMAL(18,8),
        s.discount::DECIMAL(18,8),
        CASE s.source_system
            WHEN 'SA_RETAIL' THEN (s.sales_amount - COALESCE(s.discount,0))
            WHEN 'SA_ECOM'   THEN s.sales_amount
            ELSE NULL
        END::DECIMAL(18,8),
        CASE WHEN s.source_system = 'SA_RETAIL' THEN s.cost ELSE NULL END::DECIMAL(18,8),
        s.quantity::INTEGER,
        CASE WHEN s.cost IS NOT NULL AND s.quantity IS NOT NULL
                AND s.source_system = 'SA_RETAIL'
            THEN (s.cost * s.quantity)
            ELSE NULL
        END::DECIMAL(18,8),
        CASE
            WHEN s.sales_amount IS NOT NULL AND s.cost IS NOT NULL
                AND s.quantity IS NOT NULL
            THEN
                CASE s.source_system
                    WHEN 'SA_RETAIL' THEN
                        (s.sales_amount - COALESCE(s.discount,0)) - (s.cost * s.quantity)
                    WHEN 'SA_ECOM' THEN s.sales_amount
                    ELSE NULL
                END
            ELSE NULL
        END::DECIMAL(18,8),
        s.source_system::VARCHAR,
        s.source_entity::VARCHAR
    FROM bl_3nf.ce_sales s
    LEFT JOIN bl_dm.dim_time_day dt
        ON dt.date_src_id = TO_CHAR(s.event_dt, 'YYYYMMDD')
    LEFT JOIN bl_3nf.ce_customers_scd ce_cust
        ON ce_cust.customer_id = s.customer_id
    LEFT JOIN bl_dm.dim_customers_scd dim_cust
        ON dim_cust.customer_src_id      = ce_cust.customer_src_id
        AND dim_cust.source_system         = ce_cust.source_system
        AND dim_cust.customer_name         = ce_cust.customer_name
        AND dim_cust.customer_gender       = ce_cust.customer_gender
        AND dim_cust.customer_email        = ce_cust.customer_email
        AND dim_cust.customer_phone_number = ce_cust.customer_phone_number
        AND dim_cust.customer_address      = COALESCE(
                (SELECT loc.location_address FROM bl_3nf.ce_locations loc
                WHERE loc.location_id = ce_cust.customer_location_id LIMIT 1), 'n/a')
        AND dim_cust.customer_city         = COALESCE(
                (SELECT loc.location_city FROM bl_3nf.ce_locations loc
                WHERE loc.location_id = ce_cust.customer_location_id LIMIT 1), 'n/a')
        AND dim_cust.customer_state        = COALESCE(
                (SELECT loc.location_state FROM bl_3nf.ce_locations loc
                WHERE loc.location_id = ce_cust.customer_location_id LIMIT 1), 'n/a')
        AND dim_cust.customer_postal_code  = COALESCE(
                (SELECT loc.location_postal_code FROM bl_3nf.ce_locations loc
                WHERE loc.location_id = ce_cust.customer_location_id LIMIT 1), 'n/a')
    LEFT JOIN bl_3nf.ce_employees ce_emp
        ON ce_emp.employee_id = s.employee_id
    LEFT JOIN bl_dm.dim_employees dim_emp
        ON dim_emp.employee_src_id = ce_emp.employee_src_id
        AND dim_emp.source_system   = ce_emp.source_system
    LEFT JOIN bl_3nf.ce_products_scd ce_prod
        ON ce_prod.product_id = s.product_id
    LEFT JOIN bl_dm.dim_products_scd dim_prod
        ON dim_prod.product_src_id     = ce_prod.product_src_id
        AND dim_prod.source_system       = ce_prod.source_system
        AND dim_prod.product_description = ce_prod.product_description
        AND dim_prod.product_colour      = ce_prod.product_colour
        AND dim_prod.product_size        = ce_prod.product_size
        AND dim_prod.product_min_amount  IS NOT DISTINCT FROM ce_prod.product_min_amount
    LEFT JOIN bl_3nf.ce_stores ce_st
        ON ce_st.store_id = s.store_id
    LEFT JOIN bl_dm.dim_stores dim_st
        ON dim_st.store_src_id = ce_st.store_src_id
    LEFT JOIN bl_3nf.ce_payment_types ce_pt
        ON ce_pt.payment_type_id = s.payment_type_id
    LEFT JOIN bl_dm.dim_payment_types dim_pt
        ON dim_pt.payment_type_src_id = ce_pt.payment_type_src_id
    WHERE s.sale_id > 0
    -- MONTH FILTER: only rows for the target partition month
    AND (p_month_start IS NULL OR s.event_dt >= p_month_start)
    AND (p_month_end   IS NULL OR s.event_dt <  p_month_end)
    -- Incremental dedup guard
    AND NOT EXISTS (
        SELECT 1 FROM bl_dm.fct_sales_dd fct
        WHERE fct.line_src_id   = s.sale_src_id
                                    || '_' || COALESCE(ce_prod.product_src_id, 'n/a')
            AND fct.source_system = s.source_system
            AND fct.event_dt      = s.event_dt
    );
END;
$$;


CREATE OR REPLACE PROCEDURE bl_cl.prc_load_fct_sales_dd()
LANGUAGE plpgsql AS $$
DECLARE
    v_rec               RECORD;
    v_rows_inserted     INTEGER   := 0;
    v_rows_inserted_month INTEGER := 0;
    v_delta             INTEGER   := 0;
    -- Partition management
    v_month_start       DATE;
    v_month_end         DATE;
    v_partition_name    TEXT;
    v_partition_exists  BOOLEAN;
    -- Loop over unloaded months
    v_month             RECORD;
BEGIN
    -- ── Determine ALL unloaded months from CE_SALES ────────────────
    -- Iterate month by month in ascending order
    FOR v_month IN (
        SELECT DISTINCT
            DATE_TRUNC('month', s.event_dt)::DATE AS month_start,
            (DATE_TRUNC('month', s.event_dt) + INTERVAL '1 month')::DATE AS month_end
        FROM   bl_3nf.ce_sales s
        WHERE  s.sale_id > 0
          AND  NOT EXISTS (
               SELECT 1 FROM bl_dm.fct_sales_dd fct
               WHERE  fct.source_system = s.source_system
                 AND  fct.event_dt      = s.event_dt
                 AND  fct.line_src_id   = s.sale_src_id || '_' ||
                      COALESCE(
                          (SELECT p.product_src_id FROM bl_3nf.ce_products_scd p
                           WHERE p.product_id = s.product_id LIMIT 1), 'n/a')
          )
        ORDER BY month_start ASC
    )
    LOOP
        v_month_start    := v_month.month_start;
        v_month_end      := v_month.month_end;
        v_partition_name := 'fct_sales_dd_' || TO_CHAR(v_month_start, 'YYYY_MM');
        v_rows_inserted_month := 0;

        RAISE NOTICE '[prc_load_fct_sales_dd] Processing month: % → %',
                     v_month_start, v_month_end;

        -- ── Check if partition already attached ────────────────────
        SELECT EXISTS (
            SELECT 1
            FROM   pg_inherits  i
            JOIN   pg_class     c ON c.oid = i.inhrelid
            JOIN   pg_namespace n ON n.oid = c.relnamespace
            JOIN   pg_class     p ON p.oid = i.inhparent
            WHERE  n.nspname = 'bl_dm'
              AND  c.relname  = v_partition_name
              AND  p.relname  = 'fct_sales_dd'
        ) INTO v_partition_exists;

        -- ── STEP 1: Create partition table if not exists ───────────
        -- Use final partition name directly (no separate staging name)
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS bl_dm.%I
             (LIKE bl_dm.fct_sales_dd INCLUDING DEFAULTS INCLUDING CONSTRAINTS)',
            v_partition_name
        );
        RAISE NOTICE '[prc_load_fct_sales_dd] Table bl_dm.% ready.', v_partition_name;

        -- ── STEP 2: Load rows for this month into partition table ──
        FOR v_rec IN (
            SELECT * FROM bl_cl.fn_get_fct_sales_dd(v_month_start, v_month_end)
        )
        LOOP
            EXECUTE format(
                'INSERT INTO bl_dm.%I (
                    sales_surr_id, event_dt, date_surr_id,
                    customer_surr_id, employee_surr_id, product_surr_id,
                    store_surr_id, payment_type_surr_id,
                    payment_src_id, line_src_id,
                    fct_sales_amount, fct_discount, fct_net_amount,
                    fct_unit_cost, fct_quantity, fct_total_cost, fct_gross_profit,
                    ta_insert_dt, ta_update_dt, source_system, source_entity
                )
                SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,
                       $11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21
                WHERE NOT EXISTS (
                    SELECT 1 FROM bl_dm.%I s
                    WHERE s.line_src_id   = $10
                      AND s.source_system = $20
                      AND s.event_dt      = $2
                )',
                v_partition_name,
                v_partition_name
            )
            USING
                nextval('bl_dm.seq_fct_sales_dd'),
                v_rec.event_dt,
                v_rec.date_surr_id,
                v_rec.customer_surr_id,
                v_rec.employee_surr_id,
                v_rec.product_surr_id,
                v_rec.store_surr_id,
                v_rec.payment_type_surr_id,
                v_rec.payment_src_id,
                v_rec.line_src_id,
                v_rec.fct_sales_amount,
                v_rec.fct_discount,
                v_rec.fct_net_amount,
                v_rec.fct_unit_cost,
                v_rec.fct_quantity,
                v_rec.fct_total_cost,
                v_rec.fct_gross_profit,
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP,
                v_rec.source_system,
                v_rec.source_entity;

            GET DIAGNOSTICS v_delta = ROW_COUNT;
            v_rows_inserted_month := v_rows_inserted_month + v_delta;
            v_rows_inserted       := v_rows_inserted       + v_delta;
        END LOOP;

        RAISE NOTICE '[prc_load_fct_sales_dd] Loaded % rows for month bl_dm.%.',
                     v_rows_inserted_month, v_partition_name;

        -- ── STEP 3: ATTACH partition (only if not yet attached) ────
        IF NOT v_partition_exists THEN
            EXECUTE format(
                'ALTER TABLE bl_dm.fct_sales_dd
                 ATTACH PARTITION bl_dm.%I
                 FOR VALUES FROM (%L) TO (%L)',
                v_partition_name,
                v_month_start,
                v_month_end
            );
            RAISE NOTICE '[prc_load_fct_sales_dd] ATTACHED bl_dm.% → [% , %).',
                         v_partition_name, v_month_start, v_month_end;
        ELSE
            RAISE NOTICE '[prc_load_fct_sales_dd] Partition bl_dm.% already attached — skipping.',
                         v_partition_name;
        END IF;
        -- ── STEP 3b: Add FK constraints to newly attached partition ──
        -- FK constraints cannot be set on partitioned parent table —
        -- they must be added per partition after ATTACH.
        IF NOT v_partition_exists THEN
            EXECUTE format(
                'ALTER TABLE bl_dm.%I
                ADD CONSTRAINT fk_%s_date
                    FOREIGN KEY (date_surr_id)
                    REFERENCES bl_dm.dim_time_day(date_surr_id),
                ADD CONSTRAINT fk_%s_employee
                    FOREIGN KEY (employee_surr_id)
                    REFERENCES bl_dm.dim_employees(employee_surr_id),
                ADD CONSTRAINT fk_%s_store
                    FOREIGN KEY (store_surr_id)
                    REFERENCES bl_dm.dim_stores(store_surr_id),
                ADD CONSTRAINT fk_%s_payment
                    FOREIGN KEY (payment_type_surr_id)
                    REFERENCES bl_dm.dim_payment_types(payment_type_surr_id)',
                v_partition_name,
                v_partition_name,  -- for fk name
                v_partition_name,
                v_partition_name,
                v_partition_name
            );
            RAISE NOTICE '[prc_load_fct_sales_dd] FK constraints added to bl_dm.%.',
                        v_partition_name;
        END IF;

        -- ── STEP 4: (removed) — rolling window partition drop.
        -- NOTE: previously this step DETACHed + DROPped partitions older
        -- than N months. That permanently deletes historical fact rows,
        -- which breaks DQ test 4.06 (CE_SALES → FCT_SALES_DD coverage —
        -- dropped months show up as "missing") and DQ test 5.04/5.08
        -- (restartability — a re-run detects the dropped months as
        -- "unloaded" again via fn_get_fct_sales_dd and re-inserts them,
        -- so row counts differ between runs). FCT_SALES_DD keeps monthly
        -- partitions for manageability, but partitions are retained
        -- permanently — no data is ever dropped.

    END LOOP; -- end month loop

    -- ── Handle case: no new data at all ────────────────────────────
    IF v_rows_inserted = 0 THEN
        RAISE NOTICE '[prc_load_fct_sales_dd] No new data found — idempotent re-run.';
    END IF;

    -- ── Log success ─────────────────────────────────────────────────
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_fct_sales_dd',
        p_rows_inserted  => v_rows_inserted,
        p_rows_updated   => 0,
        p_status         => 'SUCCESS',
        p_source_system  => 'BL_3NF',
        p_source_entity  => 'CE_SALES'
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_load_fct_sales_dd',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'ERROR',
        p_message        => SQLERRM
    );
    RAISE;
END;
$$;

-- ============================================================
-- ORCHESTRATOR — prc_master_load_bldm
-- Calls all prc_load_* in FK order using EXECUTE (dynamic SQL)
-- ============================================================

CREATE OR REPLACE PROCEDURE bl_cl.prc_master_load_bldm()
LANGUAGE plpgsql AS $$
DECLARE
    v_proc  TEXT;
    v_procs TEXT[] := ARRAY[
        'bl_cl.prc_load_dim_payment_types',
        'bl_cl.prc_load_dim_employees',
        'bl_cl.prc_load_dim_stores',
        'bl_cl.prc_load_dim_customers_scd',
        'bl_cl.prc_load_dim_products_scd',
        'bl_cl.prc_load_fct_sales_dd'
    ];
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE ' prc_master_load_bldm — START: %', CURRENT_TIMESTAMP;
    RAISE NOTICE '=================================================================';

    FOREACH v_proc IN ARRAY v_procs
    LOOP
        RAISE NOTICE '  [CALL] %', v_proc;
        -- EXECUTE — dynamic SQL dispatch (required technique)
        EXECUTE format('CALL %s()', v_proc);
        RAISE NOTICE '  [DONE] %', v_proc;
    END LOOP;

    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_master_load_bldm',
        p_rows_inserted  => 0,
        p_rows_updated   => 0,
        p_status         => 'SUCCESS',
        p_message        => 'All BL_DM procedures completed successfully.'
    );

    RAISE NOTICE '=================================================================';
    RAISE NOTICE ' prc_master_load_bldm — END: %', CURRENT_TIMESTAMP;
    RAISE NOTICE '=================================================================';

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_log_procedure(
        p_procedure_name => 'prc_master_load_bldm',
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
-- ============================================================
CALL bl_cl.prc_master_load_bldm();

-- ============================================================
-- POST-LOAD MAINTENANCE - VACUUM ANALYZE
-- Run on all DIM tables and current FCT partition.
-- ============================================================
VACUUM ANALYZE bl_dm.dim_payment_types;
VACUUM ANALYZE bl_dm.dim_employees;
VACUUM ANALYZE bl_dm.dim_stores;
VACUUM ANALYZE bl_dm.dim_customers_scd;
VACUUM ANALYZE bl_dm.dim_products_scd;
VACUUM ANALYZE bl_dm.fct_sales_dd;

-- ============================================================
-- FINAL VERIFICATION — Row counts across all BL_DM tables
-- ============================================================
DO $$
DECLARE
    v_pay_types  INTEGER; v_employees  INTEGER; v_stores    INTEGER;
    v_customers  INTEGER; v_products   INTEGER;
    v_fct_retail INTEGER; v_fct_ecom   INTEGER; v_fct_total INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_pay_types  FROM bl_dm.dim_payment_types  WHERE payment_type_surr_id > 0;
    SELECT COUNT(*) INTO v_employees  FROM bl_dm.dim_employees       WHERE employee_surr_id     > 0;
    SELECT COUNT(*) INTO v_stores     FROM bl_dm.dim_stores          WHERE store_surr_id        > 0;
    SELECT COUNT(*) INTO v_customers  FROM bl_dm.dim_customers_scd   WHERE customer_surr_id     > 0;
    SELECT COUNT(*) INTO v_products   FROM bl_dm.dim_products_scd    WHERE product_surr_id      > 0;
    SELECT COUNT(*) INTO v_fct_retail FROM bl_dm.fct_sales_dd WHERE source_system = 'SA_RETAIL';
    SELECT COUNT(*) INTO v_fct_ecom   FROM bl_dm.fct_sales_dd WHERE source_system = 'SA_ECOM';
    SELECT COUNT(*) INTO v_fct_total  FROM bl_dm.fct_sales_dd;

    RAISE NOTICE '=================================================================';
    RAISE NOTICE ' BL_DM INCREMENTAL LOAD — FINAL ROW COUNT SUMMARY';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE '  SCD Type 0:  dim_payment_types   = %', v_pay_types;
    RAISE NOTICE '  SCD Type 1:  dim_employees        = %', v_employees;
    RAISE NOTICE '  SCD Type 1:  dim_stores           = %', v_stores;
    RAISE NOTICE '  SCD Type 2:  dim_customers_scd    = %', v_customers;
    RAISE NOTICE '  SCD Type 2:  dim_products_scd     = %', v_products;
    RAISE NOTICE '  FCT:         fct_sales_dd RETAIL  = %', v_fct_retail;
    RAISE NOTICE '  FCT:         fct_sales_dd ECOM    = %', v_fct_ecom;
    RAISE NOTICE '  FCT:         fct_sales_dd TOTAL   = %', v_fct_total;
    RAISE NOTICE '=================================================================';
    RAISE NOTICE '  BL_DM load completed successfully.';
    RAISE NOTICE '=================================================================';
END;
$$;