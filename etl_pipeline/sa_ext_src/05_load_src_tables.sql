-- ============================================================
-- Load data from EXT tables → SRC tables
-- Includes: type casting, NULL handling, date parsing,
--           and physical deduplication (within-source)
--
-- DATE FORMAT: YYYY-MM-DD (ISO 8601) consistent with
--   DM_DIM_TIME_DAY_population.sql which uses:
--   TO_CHAR(d.dt, 'YYYYMMDD') and '2010-01-01'::DATE notation.
--   TO_DATE(..., 'YYYY-MM-DD') is used here accordingly.
--
-- NULL HANDLING: empty string '' in CSV → NULL (OPTIONS null ''
--   in ext_ tables). Additional NULLIF(TRIM(col), '') guards
--   against whitespace-only strings.
--
-- CAST ERROR HANDLING: regex ~ '^[0-9]+\.?[0-9]*$' validates
--   numeric strings before casting. Non-numeric values → NULL.
--
-- DEDUPLICATION STRATEGY:
--   (A) PHYSICAL duplicates (identical rows within one CSV) are
--       removed here using ROW_NUMBER() OVER (PARTITION BY
--       natural grain key) – as required by the task description.
--   (B) CROSS-SOURCE duplicates (same customer/employee in both
--       retail and ecom) are handled in BL_3NF layer using the
--       Hierarchy L1 approach (Deduplication.pptx, Slide 11-12):
--         BL_3NF.CE_CUSTOMERS_L1 – immutable attributes (name,
--           birthday) shared across both sources
--         BL_3NF.CE_CUSTOMERS – per-source rows with l1_id FK
--       This separation preserves full source detail while
--       avoiding data loss, per the deduplication presentation.
--
-- RESTARTABILITY: TRUNCATE before INSERT ensures idempotency –
--   re-running this script produces the same result each time.
-- ============================================================


-- ============================================================
-- LOAD 1: sa_retail.src_retail_sales
-- Grain (dedup key): bill_id + product_code
--   = one line item per product per bill
-- ============================================================

TRUNCATE TABLE sa_retail.src_retail_sales;

INSERT INTO sa_retail.src_retail_sales (
    product_code,
    description,
    colour,
    size,
    subcategory,
    category,
    top_category,
    cost,
    bill_id,
    transaction_date,
    line_item_amount,
    bill_discount,
    min_amount,
    quantity_sold,
    payment_method,
    store_code,
    zone_code,
    store_address,
    store_city,
    store_state,
    store_postal_code,
    customer_id,
    customer_name,
    customer_gender,
    customer_age,
    customer_address,
    customer_city,
    customer_state,
    customer_postal_code,
    customer_phone_number,
    employee_id,
    employee_name,
    employee_gender,
    employee_email,
    employee_address,
    employee_city,
    employee_state,
    employee_postal_code,
    employee_phone_number,
    ta_insert_dt
)
SELECT
    -- ----- PRODUCT -----
    NULLIF(TRIM(product_code),   '')                                AS product_code,
    NULLIF(TRIM(description),    '')                                AS description,
    NULLIF(TRIM(colour),         '')                                AS colour,
    NULLIF(TRIM(size),           '')                                AS size,
    NULLIF(TRIM(subcategory),    '')                                AS subcategory,
    NULLIF(TRIM(category),       '')                                AS category,
    NULLIF(TRIM(top_category),   '')                                AS top_category,

    -- DECIMAL cast with numeric guard:
    CASE
        WHEN TRIM(cost) ~ '^-?[0-9]+\.?[0-9]*$'
        THEN TRIM(cost)::DECIMAL(12,2)
        ELSE NULL
    END                                                             AS cost,

    -- ----- TRANSACTION -----
    NULLIF(TRIM(bill_id),        '')                                AS bill_id,

    -- DATE cast: format YYYY-MM-DD (consistent with DIM_TIME_DAY population script)
    CASE
        WHEN TRIM(transaction_date) ~ '^\d{4}-\d{2}-\d{2}$'
        THEN TO_DATE(TRIM(transaction_date), 'YYYY-MM-DD')
        ELSE NULL
    END                                                             AS transaction_date,

    CASE
        WHEN TRIM(line_item_amount) ~ '^-?[0-9]+\.?[0-9]*$'
        THEN TRIM(line_item_amount)::DECIMAL(12,2)
        ELSE NULL
    END                                                             AS line_item_amount,

    CASE
        WHEN TRIM(bill_discount) ~ '^-?[0-9]+\.?[0-9]*$'
        THEN TRIM(bill_discount)::DECIMAL(12,2)
        ELSE NULL
    END                                                             AS bill_discount,

    CASE
        WHEN TRIM(min_amount) ~ '^-?[0-9]+\.?[0-9]*$'
        THEN TRIM(min_amount)::DECIMAL(12,2)
        ELSE NULL
    END                                                             AS min_amount,

    CASE
        WHEN TRIM(quantity_sold) ~ '^[0-9]+$'
        THEN TRIM(quantity_sold)::INTEGER
        ELSE NULL
    END                                                             AS quantity_sold,

    NULLIF(TRIM(payment_method), '')                                AS payment_method,

    -- ----- STORE -----
    NULLIF(TRIM(store_code),         '')                            AS store_code,
    NULLIF(TRIM(zone_code),          '')                            AS zone_code,
    NULLIF(TRIM(store_address),      '')                            AS store_address,
    NULLIF(TRIM(store_city),         '')                            AS store_city,
    NULLIF(TRIM(store_state),        '')                            AS store_state,
    NULLIF(TRIM(store_postal_code),  '')                            AS store_postal_code,

    -- ----- CUSTOMER (sensitive columns NOT selected – excluded by design) -----
    NULLIF(TRIM(customer_id),            '')                        AS customer_id,
    NULLIF(TRIM(customer_name),          '')                        AS customer_name,
    NULLIF(TRIM(customer_gender),        '')                        AS customer_gender,

    CASE
        WHEN TRIM(customer_age) ~ '^[0-9]+$'
        THEN TRIM(customer_age)::INTEGER
        ELSE NULL
    END                                                             AS customer_age,

    NULLIF(TRIM(customer_address),       '')                        AS customer_address,
    NULLIF(TRIM(customer_city),          '')                        AS customer_city,
    NULLIF(TRIM(customer_state),         '')                        AS customer_state,
    NULLIF(TRIM(customer_postal_code),   '')                        AS customer_postal_code,
    NULLIF(TRIM(customer_phone_number),  '')                        AS customer_phone_number,

    -- ----- EMPLOYEE (employee_ssn NOT selected – excluded by design) -----
    NULLIF(TRIM(employee_id),            '')                        AS employee_id,
    NULLIF(TRIM(employee_name),          '')                        AS employee_name,
    NULLIF(TRIM(employee_gender),        '')                        AS employee_gender,
    NULLIF(TRIM(employee_email),         '')                        AS employee_email,
    NULLIF(TRIM(employee_address),       '')                        AS employee_address,
    NULLIF(TRIM(employee_city),          '')                        AS employee_city,
    NULLIF(TRIM(employee_state),         '')                        AS employee_state,
    NULLIF(TRIM(employee_postal_code),   '')                        AS employee_postal_code,
    NULLIF(TRIM(employee_phone_number),  '')                        AS employee_phone_number,

    -- ----- TECHNICAL -----
    CURRENT_DATE                                                    AS ta_insert_dt

FROM (
    -- --------------------------------------------------------
    -- (A) PHYSICAL DEDUPLICATION within retail source
    --     Grain key: bill_id + product_code
    --     (one product line per bill = defined grain in Business Template)
    --     ROW_NUMBER keeps first occurrence when duplicates exist.
    -- --------------------------------------------------------
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY
                NULLIF(TRIM(bill_id),      ''),
                NULLIF(TRIM(product_code), '')
            ORDER BY
                NULLIF(TRIM(bill_id),      ''),
                NULLIF(TRIM(product_code), '')
        ) AS rn
    FROM sa_retail.ext_retail_sales
    WHERE NULLIF(TRIM(bill_id),      '') IS NOT NULL
      AND NULLIF(TRIM(product_code), '') IS NOT NULL
) deduped
WHERE rn = 1;


-- ============================================================
-- LOAD 2: sa_ecom.src_ecom_sales
-- Grain (dedup key): payment_id + product_code
-- ============================================================

TRUNCATE TABLE sa_ecom.src_ecom_sales;

INSERT INTO sa_ecom.src_ecom_sales (
    product_code,
    details,
    product_type,
    cost,
    payment_id,
    transaction_date,
    sales_amount,
    discount,
    payment_type,
    quantity,
    user_id,
    user_username,
    user_name,
    user_gender,
    user_email,
    user_age,
    user_address,
    user_city,
    user_state,
    user_postal_code,
    user_phone_number,
    ee_id,
    ee_username,
    ee_name,
    ee_gender,
    ee_email,
    ee_address,
    ee_city,
    ee_state,
    ee_postal_code,
    ee_phone_number,
    ta_insert_dt
)
SELECT
    -- ----- PRODUCT -----
    NULLIF(TRIM(product_code),   '')                                AS product_code,
    NULLIF(TRIM(details),        '')                                AS details,
    NULLIF(TRIM(product_type),   '')                                AS product_type,

    CASE
        WHEN TRIM(cost) ~ '^-?[0-9]+\.?[0-9]*$'
        THEN TRIM(cost)::DECIMAL(12,2)
        ELSE NULL
    END                                                             AS cost,

    -- ----- TRANSACTION -----
    NULLIF(TRIM(payment_id),     '')                                AS payment_id,

    -- DATE cast: column named "date" in ext_ (quoted reserved word)
    -- Format YYYY-MM-DD consistent with DIM_TIME_DAY population script
    CASE
        WHEN TRIM("date") ~ '^\d{4}-\d{2}-\d{2}$'
        THEN TO_DATE(TRIM("date"), 'YYYY-MM-DD')
        ELSE NULL
    END                                                             AS transaction_date,

    CASE
        WHEN TRIM(sales_amount) ~ '^-?[0-9]+\.?[0-9]*$'
        THEN TRIM(sales_amount)::DECIMAL(12,2)
        ELSE NULL
    END                                                             AS sales_amount,

    CASE
        WHEN TRIM(discount) ~ '^-?[0-9]+\.?[0-9]*$'
        THEN TRIM(discount)::DECIMAL(12,2)
        ELSE NULL
    END                                                             AS discount,

    NULLIF(TRIM(payment_type),   '')                                AS payment_type,

    CASE
        WHEN TRIM(quantity) ~ '^[0-9]+$'
        THEN TRIM(quantity)::INTEGER
        ELSE NULL
    END                                                             AS quantity,

    -- ----- CUSTOMER/USER (sensitive columns NOT selected – excluded by design) -----
    NULLIF(TRIM(user_id),            '')                            AS user_id,
    NULLIF(TRIM(user_username),      '')                            AS user_username,
    NULLIF(TRIM(user_name),          '')                            AS user_name,
    NULLIF(TRIM(user_gender),        '')                            AS user_gender,
    NULLIF(TRIM(user_email),         '')                            AS user_email,

    CASE
        WHEN TRIM(user_age) ~ '^[0-9]+$'
        THEN TRIM(user_age)::INTEGER
        ELSE NULL
    END                                                             AS user_age,

    NULLIF(TRIM(user_address),       '')                            AS user_address,
    NULLIF(TRIM(user_city),          '')                            AS user_city,
    NULLIF(TRIM(user_state),         '')                            AS user_state,
    NULLIF(TRIM(user_postal_code),   '')                            AS user_postal_code,
    NULLIF(TRIM(user_phone_number),  '')                            AS user_phone_number,

    -- ----- EMPLOYEE (ee_ssn NOT selected – excluded by design) -----
    NULLIF(TRIM(ee_id),              '')                            AS ee_id,
    NULLIF(TRIM(ee_username),        '')                            AS ee_username,
    NULLIF(TRIM(ee_name),            '')                            AS ee_name,
    NULLIF(TRIM(ee_gender),          '')                            AS ee_gender,
    NULLIF(TRIM(ee_email),           '')                            AS ee_email,
    NULLIF(TRIM(ee_address),         '')                            AS ee_address,
    NULLIF(TRIM(ee_city),            '')                            AS ee_city,
    NULLIF(TRIM(ee_state),           '')                            AS ee_state,
    NULLIF(TRIM(ee_postal_code),     '')                            AS ee_postal_code,
    NULLIF(TRIM(ee_phone_number),    '')                            AS ee_phone_number,

    -- ----- TECHNICAL -----
    CURRENT_DATE                                                    AS ta_insert_dt

FROM (
    -- --------------------------------------------------------
    -- (A) PHYSICAL DEDUPLICATION within ecom source
    --     Grain key: payment_id + product_code
    -- --------------------------------------------------------
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY
                NULLIF(TRIM(payment_id),   ''),
                NULLIF(TRIM(product_code), '')
            ORDER BY
                NULLIF(TRIM(payment_id),   ''),
                NULLIF(TRIM(product_code), '')
        ) AS rn
    FROM sa_ecom.ext_ecom_sales
    WHERE NULLIF(TRIM(payment_id),   '') IS NOT NULL
      AND NULLIF(TRIM(product_code), '') IS NOT NULL
) deduped
WHERE rn = 1;