-- DML - Incremental load scripts for all BL_DM table
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

BEGIN;

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
    src.payment_type_src_id,
    src.payment_type_name,
    CURRENT_TIMESTAMP,
    src.source_system,
    src.source_entity
FROM bl_3nf.ce_payment_types src
WHERE src.payment_type_id > 0   -- skip default row
  AND NOT EXISTS (
      SELECT 1
      FROM   bl_dm.dim_payment_types tgt
      WHERE  tgt.payment_type_src_id = src.payment_type_src_id
  );

DO $$
DECLARE v_cnt INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_cnt
    FROM   bl_dm.dim_payment_types
    WHERE  payment_type_surr_id > 0;
    RAISE NOTICE '[OK] bl_dm.dim_payment_types loaded. Business rows (id>0): %', v_cnt;
END;
$$;

COMMIT;


-- ============================================================
-- LOAD 3 - DIM_EMPLOYEES
--          SCD Type 1 - INSERT new + UPDATE changed.
--          Source: bl_3nf.ce_employees
--                  + bl_3nf.ce_locations (address flattened)
--          NK:     employee_src_id
--          Tracked: all attributes (SCD1 - full overwrite)
-- ============================================================

-- ------------------------------------------------------------
-- STEP 1: INSERT new employees (NK not yet in target)
-- ------------------------------------------------------------

BEGIN;

INSERT INTO bl_dm.dim_employees (
    employee_surr_id,
    employee_src_id,
    employee_name,
    employee_gender,
    employee_email,
    employee_phone_number,
    employee_address,
    employee_city,
    employee_state,
    employee_postal_code,
    ta_insert_dt,
    ta_update_dt,
    source_system,
    source_entity
)
SELECT
    nextval('bl_dm.seq_dim_employees'),
    src.employee_src_id,
    src.employee_name,
    src.employee_gender,
    src.employee_email,
    src.employee_phone_number,
    COALESCE(loc.location_address,      'n/a'),
    COALESCE(loc.location_city,         'n/a'),
    COALESCE(loc.location_state,        'n/a'),
    COALESCE(loc.location_postal_code,  'n/a'),
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    src.source_system,
    src.source_entity
FROM bl_3nf.ce_employees src
LEFT JOIN bl_3nf.ce_locations loc
       ON loc.location_id = src.employee_location_id
WHERE src.employee_id > 0   -- skip default row
  AND NOT EXISTS (
      SELECT 1
      FROM   bl_dm.dim_employees tgt
      WHERE  tgt.employee_src_id = src.employee_src_id
      AND  tgt.source_system   = src.source_system
  );

-- ------------------------------------------------------------
-- STEP 2: UPDATE existing employees when any attribute changed
--         (SCD Type 1 - overwrite on change)
--         Never update the default row (employee_surr_id > 0).
-- ------------------------------------------------------------

UPDATE bl_dm.dim_employees tgt
SET
    employee_name           = src.employee_name,
    employee_gender         = src.employee_gender,
    employee_email          = src.employee_email,
    employee_phone_number   = src.employee_phone_number,
    employee_address        = COALESCE(loc.location_address,     'n/a'),
    employee_city           = COALESCE(loc.location_city,        'n/a'),
    employee_state          = COALESCE(loc.location_state,       'n/a'),
    employee_postal_code    = COALESCE(loc.location_postal_code, 'n/a'),
    ta_update_dt            = CURRENT_TIMESTAMP
FROM bl_3nf.ce_employees src
LEFT JOIN bl_3nf.ce_locations loc
       ON loc.location_id = src.employee_location_id
WHERE tgt.employee_src_id   = src.employee_src_id
  AND tgt.employee_surr_id  > 0          -- never update default row
  AND src.employee_id       > 0          -- never read default row
  AND (
        tgt.employee_name           <> src.employee_name
     OR tgt.employee_gender         <> src.employee_gender
     OR tgt.employee_email          <> src.employee_email
     OR tgt.employee_phone_number   <> src.employee_phone_number
     OR tgt.employee_address        <> COALESCE(loc.location_address,     'n/a')
     OR tgt.employee_city           <> COALESCE(loc.location_city,        'n/a')
     OR tgt.employee_state          <> COALESCE(loc.location_state,       'n/a')
     OR tgt.employee_postal_code    <> COALESCE(loc.location_postal_code, 'n/a')
  );

DO $$
DECLARE v_cnt INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_cnt
    FROM   bl_dm.dim_employees
    WHERE  employee_surr_id > 0;
    RAISE NOTICE '[OK] bl_dm.dim_employees loaded. Business rows (id>0): %', v_cnt;
END;
$$;

COMMIT;


-- ============================================================
-- LOAD 4 - DIM_STORES
--          SCD Type 1 - INSERT new + UPDATE changed.
--          Source: bl_3nf.ce_stores
--                  + bl_3nf.ce_store_zones (zone flattened)
--                  + bl_3nf.ce_locations   (address flattened)
--          NK:     store_src_id
-- ============================================================

-- ------------------------------------------------------------
-- STEP 1: INSERT new stores (NK not yet in target)
-- ------------------------------------------------------------

BEGIN;

INSERT INTO bl_dm.dim_stores (
    store_surr_id,
    store_src_id,
    store_channel,
    store_zone_id,
    store_zone_name,
    store_address,
    store_city,
    store_state,
    store_postal_code,
    ta_insert_dt,
    ta_update_dt,
    source_system,
    source_entity
)
SELECT
    nextval('bl_dm.seq_dim_stores'),
    src.store_src_id,
    src.store_channel,
    COALESCE(zon.store_zone_id,         -1),
    COALESCE(zon.store_zone_name,       'n/a'),
    COALESCE(loc.location_address,      'n/a'),
    COALESCE(loc.location_city,         'n/a'),
    COALESCE(loc.location_state,        'n/a'),
    COALESCE(loc.location_postal_code,  'n/a'),
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    src.source_system,
    src.source_entity
FROM bl_3nf.ce_stores src
LEFT JOIN bl_3nf.ce_store_zones zon
       ON zon.store_zone_id  = src.store_zone_id
LEFT JOIN bl_3nf.ce_locations loc
       ON loc.location_id    = src.store_location_id
WHERE src.store_id > 0   -- skip default row
  AND NOT EXISTS (
      SELECT 1
      FROM   bl_dm.dim_stores tgt
      WHERE  tgt.store_src_id = src.store_src_id
  );

-- ------------------------------------------------------------
-- STEP 2: UPDATE existing stores when any attribute changed
--         (SCD Type 1 - overwrite on change)
-- ------------------------------------------------------------

UPDATE bl_dm.dim_stores tgt
SET
    store_channel       = src.store_channel,
    store_zone_id       = COALESCE(zon.store_zone_id,        -1),
    store_zone_name     = COALESCE(zon.store_zone_name,      'n/a'),
    store_address       = COALESCE(loc.location_address,     'n/a'),
    store_city          = COALESCE(loc.location_city,        'n/a'),
    store_state         = COALESCE(loc.location_state,       'n/a'),
    store_postal_code   = COALESCE(loc.location_postal_code, 'n/a'),
    ta_update_dt        = CURRENT_TIMESTAMP,
    source_system           = src.source_system,
    source_entity           = src.source_entity
FROM bl_3nf.ce_stores src
LEFT JOIN bl_3nf.ce_store_zones zon
       ON zon.store_zone_id = src.store_zone_id
LEFT JOIN bl_3nf.ce_locations loc
       ON loc.location_id   = src.store_location_id
WHERE tgt.store_src_id  = src.store_src_id
  AND tgt.store_surr_id > 0      -- never update default row
  AND src.store_id      > 0      -- never read default row
  AND (
        tgt.store_channel     <> src.store_channel
     OR tgt.store_zone_id     <> COALESCE(zon.store_zone_id,        -1)
     OR tgt.store_zone_name   <> COALESCE(zon.store_zone_name,      'n/a')
     OR tgt.store_address     <> COALESCE(loc.location_address,     'n/a')
     OR tgt.store_city        <> COALESCE(loc.location_city,        'n/a')
     OR tgt.store_state       <> COALESCE(loc.location_state,       'n/a')
     OR tgt.store_postal_code <> COALESCE(loc.location_postal_code, 'n/a')
  );

DO $$
DECLARE v_cnt INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_cnt
    FROM   bl_dm.dim_stores
    WHERE  store_surr_id > 0;
    RAISE NOTICE '[OK] bl_dm.dim_stores loaded. Business rows (id>0): %', v_cnt;
END;
$$;

COMMIT;


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

-- ------------------------------------------------------------
-- STEP A: Close previous active version in DIM_CUSTOMERS_SCD
--         when the address has changed in BL_3NF source.
--         Condition: NK matches + is_active = 'Y'
--                    + any tracked address attribute differs.
-- ------------------------------------------------------------

BEGIN;

UPDATE bl_dm.dim_customers_scd tgt
SET
    end_dt       = CURRENT_DATE - 1,
    is_active    = 'N',
    ta_update_dt = CURRENT_TIMESTAMP
FROM bl_3nf.ce_customers_scd src
LEFT JOIN bl_3nf.ce_locations loc
       ON loc.location_id = src.customer_location_id
WHERE tgt.customer_src_id   = src.customer_src_id
  AND tgt.is_active          = 'Y'
  AND tgt.end_dt             = DATE '9999-12-31'
  AND tgt.customer_surr_id  > 0      -- never touch default row
  AND src.is_active          = 'Y'   -- only compare against active 3NF version
  AND src.customer_id        > 0     -- skip default row from source
  AND (
        tgt.customer_address      <> COALESCE(loc.location_address,     'n/a')
     OR tgt.customer_city         <> COALESCE(loc.location_city,        'n/a')
     OR tgt.customer_state        <> COALESCE(loc.location_state,       'n/a')
     OR tgt.customer_postal_code  <> COALESCE(loc.location_postal_code, 'n/a')
  );

-- ------------------------------------------------------------
-- STEP B: Insert new version for customers just closed in STEP A.
-- ------------------------------------------------------------

INSERT INTO bl_dm.dim_customers_scd (
    customer_surr_id,
    customer_src_id,
    customer_name,
    customer_gender,
    customer_email,
    customer_phone_number,
    customer_address,
    customer_city,
    customer_state,
    customer_postal_code,
    start_dt,
    end_dt,
    is_active,
    ta_insert_dt,
    ta_update_dt,
    source_system,
    source_entity
)
SELECT
    nextval('bl_dm.seq_dim_customers_scd'),
    src.customer_src_id,
    src.customer_name,
    src.customer_gender,
    src.customer_email,
    src.customer_phone_number,
    COALESCE(loc.location_address,     'n/a'),
    COALESCE(loc.location_city,        'n/a'),
    COALESCE(loc.location_state,       'n/a'),
    COALESCE(loc.location_postal_code, 'n/a'),
    CURRENT_DATE,
    DATE '9999-12-31',
    'Y',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    src.source_system,
    src.source_entity
FROM bl_3nf.ce_customers_scd src
LEFT JOIN bl_3nf.ce_locations loc
       ON loc.location_id = src.customer_location_id
WHERE src.is_active   = 'Y'
  AND src.customer_id > 0
  -- Only for customers whose previous DM version was just closed today:
  AND EXISTS (
      SELECT 1
      FROM   bl_dm.dim_customers_scd closed
      WHERE  closed.customer_src_id = src.customer_src_id
        AND  closed.is_active       = 'N'
        AND  closed.end_dt          = CURRENT_DATE - 1
  )
  -- And no active version has been opened today yet:
  AND NOT EXISTS (
      SELECT 1
      FROM   bl_dm.dim_customers_scd active
      WHERE  active.customer_src_id = src.customer_src_id
        AND  active.is_active       = 'Y'
        AND  active.start_dt        = CURRENT_DATE
  );

-- ------------------------------------------------------------
-- STEP C: Insert brand-new customers.
--         NK has never appeared in DIM_CUSTOMERS_SCD at all.
-- ------------------------------------------------------------

INSERT INTO bl_dm.dim_customers_scd (
    customer_surr_id,
    customer_src_id,
    customer_name,
    customer_gender,
    customer_email,
    customer_phone_number,
    customer_address,
    customer_city,
    customer_state,
    customer_postal_code,
    start_dt,
    end_dt,
    is_active,
    ta_insert_dt,
    ta_update_dt,
    source_system,
    source_entity
)
SELECT
    nextval('bl_dm.seq_dim_customers_scd'),
    src.customer_src_id,
    src.customer_name,
    src.customer_gender,
    src.customer_email,
    src.customer_phone_number,
    COALESCE(loc.location_address,     'n/a'),
    COALESCE(loc.location_city,        'n/a'),
    COALESCE(loc.location_state,       'n/a'),
    COALESCE(loc.location_postal_code, 'n/a'),
    CURRENT_DATE,
    DATE '9999-12-31',
    'Y',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    src.source_system,
    src.source_entity
FROM bl_3nf.ce_customers_scd src
LEFT JOIN bl_3nf.ce_locations loc
       ON loc.location_id = src.customer_location_id
WHERE src.is_active   = 'Y'
  AND src.customer_id > 0
  -- NK has never appeared in DIM_CUSTOMERS_SCD:
  AND NOT EXISTS (
      SELECT 1
      FROM   bl_dm.dim_customers_scd tgt
      WHERE  tgt.customer_src_id = src.customer_src_id
  );

DO $$
DECLARE v_cnt INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_cnt
    FROM   bl_dm.dim_customers_scd
    WHERE  customer_surr_id > 0;
    RAISE NOTICE '[OK] bl_dm.dim_customers_scd loaded. Business rows (id>0): %', v_cnt;
END;
$$;

COMMIT;


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

-- ------------------------------------------------------------
-- STEP A: Close previous active version in DIM_PRODUCTS_SCD
--         when any tracked attribute has changed in BL_3NF.
-- ------------------------------------------------------------

BEGIN;

UPDATE bl_dm.dim_products_scd tgt
SET
    end_dt       = CURRENT_DATE - 1,
    is_active    = 'N',
    ta_update_dt = CURRENT_TIMESTAMP
FROM bl_3nf.ce_products_scd src
LEFT JOIN bl_3nf.ce_product_subcategories  sub
       ON sub.product_subcategory_id  = src.product_subcategory_id
LEFT JOIN bl_3nf.ce_product_categories     cat
       ON cat.product_category_id     = sub.product_category_id
LEFT JOIN bl_3nf.ce_product_top_categories top
       ON top.product_top_category_id = cat.product_top_category_id
WHERE tgt.product_src_id   = src.product_src_id
  AND tgt.is_active         = 'Y'
  AND tgt.end_dt            = DATE '9999-12-31'
  AND tgt.product_surr_id  > 0      -- never touch default row
  AND src.is_active         = 'Y'   -- only compare against active 3NF version
  AND src.product_id        > 0     -- skip default row from source
  AND (
        tgt.product_description     <> src.product_description
     OR tgt.product_colour          <> src.product_colour
     OR tgt.product_size            <> src.product_size
     OR tgt.product_min_amount      IS DISTINCT FROM src.product_min_amount
     OR tgt.product_subcategory_id  <> COALESCE(sub.product_subcategory_id,  -1)
     OR tgt.product_category_id     <> COALESCE(cat.product_category_id,     -1)
     OR tgt.product_top_category_id <> COALESCE(top.product_top_category_id, -1)
  );

-- ------------------------------------------------------------
-- STEP B: Insert new version for products just closed in STEP A.
-- ------------------------------------------------------------

INSERT INTO bl_dm.dim_products_scd (
    product_surr_id,
    product_src_id,
    product_description,
    product_colour,
    product_size,
    product_min_amount,
    product_subcategory_id,
    product_subcategory_name,
    product_category_id,
    product_category_name,
    product_top_category_id,
    product_top_category_name,
    start_dt,
    end_dt,
    is_active,
    ta_insert_dt,
    ta_update_dt,
    source_system,
    source_entity
)
SELECT
    nextval('bl_dm.seq_dim_products_scd'),
    src.product_src_id,
    src.product_description,
    src.product_colour,
    src.product_size,
    src.product_min_amount,
    COALESCE(sub.product_subcategory_id,   -1),
    COALESCE(sub.product_subcategory_name, 'n/a'),
    COALESCE(cat.product_category_id,      -1),
    COALESCE(cat.product_category_name,    'n/a'),
    COALESCE(top.product_top_category_id,  -1),
    COALESCE(top.product_top_category_name,'n/a'),
    CURRENT_DATE,
    DATE '9999-12-31',
    'Y',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    src.source_system,
    src.source_entity
FROM bl_3nf.ce_products_scd src
LEFT JOIN bl_3nf.ce_product_subcategories  sub
       ON sub.product_subcategory_id  = src.product_subcategory_id
LEFT JOIN bl_3nf.ce_product_categories     cat
       ON cat.product_category_id     = sub.product_category_id
LEFT JOIN bl_3nf.ce_product_top_categories top
       ON top.product_top_category_id = cat.product_top_category_id
WHERE src.is_active  = 'Y'
  AND src.product_id > 0
  AND EXISTS (
      SELECT 1
      FROM   bl_dm.dim_products_scd closed
      WHERE  closed.product_src_id = src.product_src_id
        AND  closed.is_active      = 'N'
        AND  closed.end_dt         = CURRENT_DATE - 1
  )
  AND NOT EXISTS (
      SELECT 1
      FROM   bl_dm.dim_products_scd active
      WHERE  active.product_src_id = src.product_src_id
        AND  active.is_active      = 'Y'
        AND  active.start_dt       = CURRENT_DATE
  );

-- ------------------------------------------------------------
-- STEP C: Insert brand-new products (NK never seen in target).
-- ------------------------------------------------------------

INSERT INTO bl_dm.dim_products_scd (
    product_surr_id,
    product_src_id,
    product_description,
    product_colour,
    product_size,
    product_min_amount,
    product_subcategory_id,
    product_subcategory_name,
    product_category_id,
    product_category_name,
    product_top_category_id,
    product_top_category_name,
    start_dt,
    end_dt,
    is_active,
    ta_insert_dt,
    ta_update_dt,
    source_system,
    source_entity
)
SELECT
    nextval('bl_dm.seq_dim_products_scd'),
    src.product_src_id,
    src.product_description,
    src.product_colour,
    src.product_size,
    src.product_min_amount,
    COALESCE(sub.product_subcategory_id,    -1),
    COALESCE(sub.product_subcategory_name,  'n/a'),
    COALESCE(cat.product_category_id,       -1),
    COALESCE(cat.product_category_name,     'n/a'),
    COALESCE(top.product_top_category_id,   -1),
    COALESCE(top.product_top_category_name, 'n/a'),
    CURRENT_DATE,
    DATE '9999-12-31',
    'Y',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    src.source_system,
    src.source_entity
FROM bl_3nf.ce_products_scd src
LEFT JOIN bl_3nf.ce_product_subcategories  sub
       ON sub.product_subcategory_id  = src.product_subcategory_id
LEFT JOIN bl_3nf.ce_product_categories     cat
       ON cat.product_category_id     = sub.product_category_id
LEFT JOIN bl_3nf.ce_product_top_categories top
       ON top.product_top_category_id = cat.product_top_category_id
WHERE src.is_active  = 'Y'
  AND src.product_id > 0
  AND NOT EXISTS (
      SELECT 1
      FROM   bl_dm.dim_products_scd tgt
      WHERE  tgt.product_src_id = src.product_src_id
  );

DO $$
DECLARE v_cnt INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_cnt
    FROM   bl_dm.dim_products_scd
    WHERE  product_surr_id > 0;
    RAISE NOTICE '[OK] bl_dm.dim_products_scd loaded. Business rows (id>0): %', v_cnt;
END;
$$;

COMMIT;


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

BEGIN;

INSERT INTO bl_dm.fct_sales_dd (
    sales_surr_id,
    event_dt,
    date_surr_id,
    customer_surr_id,
    employee_surr_id,
    product_surr_id,
    store_surr_id,
    payment_type_surr_id,
    payment_src_id,
    line_src_id,
    fct_sales_amount,
    fct_discount,
    fct_net_amount,
    fct_unit_cost,
    fct_quantity,
    fct_total_cost,
    fct_gross_profit,
    ta_insert_dt,
    ta_update_dt,
    source_system,
    source_entity
)
SELECT
    nextval('bl_dm.seq_fct_sales_dd'),

    -- Main time key
    s.event_dt,
    COALESCE(dt.date_surr_id,           -1),

    -- CUSTOMER FK (logical) - resolve via 3NF NK chain:
    --   ce_sales.customer_id → ce_customers_scd.customer_src_id
    --   → dim_customers_scd (active version)
    COALESCE(dim_cust.customer_surr_id, -1),

    -- EMPLOYEE FK - lookup DIM_EMPLOYEES by NK
    COALESCE(dim_emp.employee_surr_id,  -1),

    -- PRODUCT FK (logical) - resolve via 3NF NK chain:
    --   ce_sales.product_id → ce_products_scd.product_src_id
    --   → dim_products_scd (active version)
    COALESCE(dim_prod.product_surr_id,  -1),

    -- STORE FK - lookup DIM_STORES by NK
    COALESCE(dim_st.store_surr_id,      -1),

    -- PAYMENT TYPE FK - lookup DIM_PAYMENT_TYPES by NK
    COALESCE(dim_pt.payment_type_surr_id, -1),

    s.sale_src_id,

    -- LINE_SRC_ID: PAYMENT_SRC_ID || '_' || PRODUCT_SRC_ID
    s.sale_src_id
        || '_'
        || COALESCE(ce_prod.product_src_id, 'n/a'),

    -- ── KPI columns ──────────────────────────────────────────

    -- FCT_SALES_AMOUNT: gross sales value
    s.sales_amount,

    -- FCT_DISCOUNT: discount applied
    s.discount,

    -- FCT_NET_AMOUNT:
    --   SA_RETAIL → sales_amount – discount
    --               (bill_discount at bill level; one line per bill
    --                in current dataset - no pro-rata needed)
    --   SA_ECOM   → sales_amount as-is
    --               (sales_amount already reflects discount)
    CASE s.source_system
        WHEN 'SA_RETAIL' THEN
            s.sales_amount - COALESCE(s.discount, 0)
        WHEN 'SA_ECOM' THEN
            s.sales_amount
        ELSE NULL
    END,

    -- FCT_UNIT_COST: monetary for both sources (project decision)
    s.cost,

    -- FCT_QUANTITY: units sold
    s.quantity,

    -- FCT_TOTAL_COST = FCT_UNIT_COST × FCT_QUANTITY (derived, stored)
    CASE
        WHEN s.cost IS NOT NULL
         AND s.quantity IS NOT NULL
        THEN s.cost * s.quantity
        ELSE NULL
    END,

    -- FCT_GROSS_PROFIT = FCT_NET_AMOUNT – FCT_TOTAL_COST (derived, stored)
    CASE
        WHEN s.sales_amount IS NOT NULL
         AND s.cost         IS NOT NULL
         AND s.quantity      IS NOT NULL
        THEN
            CASE s.source_system
                WHEN 'SA_RETAIL' THEN
                    (s.sales_amount - COALESCE(s.discount, 0))
                    - (s.cost * s.quantity)
                WHEN 'SA_ECOM' THEN
                    s.sales_amount
                    - (s.cost * s.quantity)
                ELSE NULL
            END
        ELSE NULL
    END,

    -- Technical attributes
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,

    -- Source triplet preserved from CE_SALES (original SA source)
    s.source_system,
    s.source_entity

FROM bl_3nf.ce_sales s

-- ── DIM_TIME_DAY lookup ──────────────────────────────────────
LEFT JOIN bl_dm.dim_time_day dt
       ON dt.date_src_id = TO_CHAR(s.event_dt, 'YYYYMMDD')

-- ── CE_CUSTOMERS_SCD → DIM_CUSTOMERS_SCD lookup chain ────────
-- Step 1: resolve customer_id back to customer_src_id in 3NF
LEFT JOIN bl_3nf.ce_customers_scd ce_cust
       ON ce_cust.customer_id = s.customer_id
      AND ce_cust.is_active   = 'Y'
-- Step 2: lookup active DM version by NK
LEFT JOIN bl_dm.dim_customers_scd dim_cust
       ON dim_cust.customer_src_id = ce_cust.customer_src_id
      AND dim_cust.is_active       = 'Y'

-- ── CE_EMPLOYEES → DIM_EMPLOYEES lookup chain ────────────────
LEFT JOIN bl_3nf.ce_employees ce_emp
       ON ce_emp.employee_id = s.employee_id
LEFT JOIN bl_dm.dim_employees dim_emp
       ON dim_emp.employee_src_id = ce_emp.employee_src_id

-- ── CE_PRODUCTS_SCD → DIM_PRODUCTS_SCD lookup chain ──────────
-- Step 1: resolve product_id back to product_src_id in 3NF
LEFT JOIN bl_3nf.ce_products_scd ce_prod
       ON ce_prod.product_id = s.product_id
      AND ce_prod.is_active  = 'Y'
-- Step 2: lookup active DM version by NK
LEFT JOIN bl_dm.dim_products_scd dim_prod
       ON dim_prod.product_src_id = ce_prod.product_src_id
      AND dim_prod.is_active      = 'Y'

-- ── CE_STORES → DIM_STORES lookup chain ──────────────────────
LEFT JOIN bl_3nf.ce_stores ce_st
       ON ce_st.store_id = s.store_id
LEFT JOIN bl_dm.dim_stores dim_st
       ON dim_st.store_src_id = ce_st.store_src_id

-- ── CE_PAYMENT_TYPES → DIM_PAYMENT_TYPES lookup chain ────────
LEFT JOIN bl_3nf.ce_payment_types ce_pt
       ON ce_pt.payment_type_id = s.payment_type_id
LEFT JOIN bl_dm.dim_payment_types dim_pt
       ON dim_pt.payment_type_src_id = ce_pt.payment_type_src_id

-- ── Dedup guard ───────────────────────────────────────────────
WHERE s.sale_id > 0
    AND NOT EXISTS (
        SELECT 1
        FROM   bl_dm.fct_sales_dd fct
        WHERE  fct.line_src_id   = s.sale_src_id
                                    || '_'
                                    || COALESCE(ce_prod.product_src_id, 'n/a')
            AND  fct.source_system = s.source_system
    );

DO $$
DECLARE
    v_retail INTEGER;
    v_ecom   INTEGER;
    v_total  INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_retail
    FROM   bl_dm.fct_sales_dd
    WHERE  source_system = 'SA_RETAIL';

    SELECT COUNT(*) INTO v_ecom
    FROM   bl_dm.fct_sales_dd
    WHERE  source_system = 'SA_ECOM';

    SELECT COUNT(*) INTO v_total
    FROM   bl_dm.fct_sales_dd;

    RAISE NOTICE '[OK] bl_dm.fct_sales_dd loaded.';
    RAISE NOTICE '     SA_RETAIL rows : %', v_retail;
    RAISE NOTICE '     SA_ECOM   rows : %', v_ecom;
    RAISE NOTICE '     TOTAL     rows : %', v_total;
END;
$$;

COMMIT;


-- ============================================================
-- FINAL VERIFICATION - Row counts across all 6 BL_DM tables
-- ============================================================

DO $$
DECLARE
    v_pay_types     INTEGER;
    v_employees     INTEGER;
    v_stores        INTEGER;
    v_customers     INTEGER;
    v_products      INTEGER;
    v_fct_retail    INTEGER;
    v_fct_ecom      INTEGER;
    v_fct_total     INTEGER;
BEGIN

    SELECT COUNT(*) INTO v_pay_types
    FROM bl_dm.dim_payment_types WHERE payment_type_surr_id > 0;

    SELECT COUNT(*) INTO v_employees
    FROM bl_dm.dim_employees     WHERE employee_surr_id      > 0;

    SELECT COUNT(*) INTO v_stores
    FROM bl_dm.dim_stores        WHERE store_surr_id         > 0;

    SELECT COUNT(*) INTO v_customers
    FROM bl_dm.dim_customers_scd WHERE customer_surr_id      > 0;

    SELECT COUNT(*) INTO v_products
    FROM bl_dm.dim_products_scd  WHERE product_surr_id       > 0;

    SELECT COUNT(*) INTO v_fct_retail
    FROM bl_dm.fct_sales_dd WHERE source_system = 'SA_RETAIL';

    SELECT COUNT(*) INTO v_fct_ecom
    FROM bl_dm.fct_sales_dd WHERE source_system = 'SA_ECOM';

    SELECT COUNT(*) INTO v_fct_total
    FROM bl_dm.fct_sales_dd;

    RAISE NOTICE '=================================================================';
    RAISE NOTICE ' BL_DM INCREMENTAL LOAD - FINAL ROW COUNT SUMMARY';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE '  GROUP 1 - SCD Type 0:';
    RAISE NOTICE '    dim_payment_types        business rows : %', v_pay_types;
    RAISE NOTICE '-----------------------------------------------------------------';
    RAISE NOTICE '  GROUP 2 - SCD Type 1:';
    RAISE NOTICE '    dim_employees            business rows : %', v_employees;
    RAISE NOTICE '    dim_stores               business rows : %', v_stores;
    RAISE NOTICE '-----------------------------------------------------------------';
    RAISE NOTICE '  GROUP 3 - SCD Type 2:';
    RAISE NOTICE '    dim_customers_scd        business rows : %', v_customers;
    RAISE NOTICE '    dim_products_scd         business rows : %', v_products;
    RAISE NOTICE '-----------------------------------------------------------------';
    RAISE NOTICE '  GROUP 4 - Fact table:';
    RAISE NOTICE '    fct_sales_dd  SA_RETAIL  rows : %',          v_fct_retail;
    RAISE NOTICE '    fct_sales_dd  SA_ECOM    rows : %',          v_fct_ecom;
    RAISE NOTICE '    fct_sales_dd  TOTAL      rows : %',          v_fct_total;
    RAISE NOTICE '=================================================================';
    RAISE NOTICE '  BL_DM load completed successfully.';
    RAISE NOTICE '=================================================================';
END;
$$;