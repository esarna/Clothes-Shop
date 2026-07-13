-- ============================================================
-- Create SOURCE tables on SA layer
-- ============================================================


-- ============================================================
-- 1. sa_retail.src_retail_sales
--    Source: retail-sample.csv
-- ============================================================
DROP TABLE IF EXISTS sa_retail.src_retail_sales;

CREATE TABLE sa_retail.src_retail_sales (

    -- ----- PRODUCT INFORMATION -----
    product_code            VARCHAR(50),
    description             VARCHAR(200),
    colour                  VARCHAR(50),
    size                    VARCHAR(20),
    subcategory             VARCHAR(100),
    category                VARCHAR(100),
    top_category            VARCHAR(100),
    cost                    DECIMAL(12,2),

    -- ----- TRANSACTION INFORMATION -----
    bill_id                 VARCHAR(50),
    transaction_date        DATE,
    line_item_amount        DECIMAL(12,2),
    bill_discount           DECIMAL(12,2),
    min_amount              DECIMAL(12,2),
    quantity_sold           INTEGER,
    payment_method          VARCHAR(50),

    -- ----- STORE INFORMATION -----
    store_code              VARCHAR(50),
    zone_code               VARCHAR(50),
    store_address           VARCHAR(200),
    store_city              VARCHAR(100),
    store_state             VARCHAR(10),
    store_postal_code       VARCHAR(20),

    -- ----- CUSTOMER INFORMATION -----
    -- NOTE: customer_ssn, credit_card_number, credit_card_expiration_date,
    --       credit_card_cvv, bank_number are EXCLUDED here.
    customer_id             VARCHAR(50),
    customer_name           VARCHAR(100),
    customer_gender         VARCHAR(10),
    customer_age            INTEGER,
    customer_address        VARCHAR(200),
    customer_city           VARCHAR(100),
    customer_state          VARCHAR(10),
    customer_postal_code    VARCHAR(20),
    customer_phone_number   VARCHAR(50),

    -- ----- EMPLOYEE INFORMATION -----
    -- NOTE: employee_ssn EXCLUDED – sensitive field.
    employee_id             VARCHAR(50),
    employee_name           VARCHAR(100),
    employee_gender         VARCHAR(10),
    employee_email          VARCHAR(100),
    employee_address        VARCHAR(200),
    employee_city           VARCHAR(100),
    employee_state          VARCHAR(10),
    employee_postal_code    VARCHAR(20),
    employee_phone_number   VARCHAR(50),

    -- ----- TECHNICAL ATTRIBUTES -----
    ta_insert_dt            DATE NOT NULL DEFAULT CURRENT_DATE
);

COMMENT ON TABLE sa_retail.src_retail_sales IS
    'Source table for retail-sample.csv. Deduplicated, typed copy of '
    'ext_retail_sales. Sensitive columns (SSN, card details) excluded. '
    'TA_INSERT_DT records when the row was loaded into SA layer.';


-- ============================================================
-- 2. sa_ecom.src_ecom_sales
--    Source: ecom-sample.csv
-- ============================================================
DROP TABLE IF EXISTS sa_ecom.src_ecom_sales;

CREATE TABLE sa_ecom.src_ecom_sales (

    -- ----- PRODUCT INFORMATION -----
    product_code                VARCHAR(50),
    details                     VARCHAR(100),
    product_type                VARCHAR(100),
    cost                        DECIMAL(12,2),

    -- ----- TRANSACTION INFORMATION -----
    payment_id                  VARCHAR(50),
    transaction_date            DATE,           -- renamed from "date" (reserved word)
    sales_amount                DECIMAL(12,2),
    discount                    DECIMAL(12,2),
    payment_type                VARCHAR(50),
    quantity                    INTEGER,

    -- ----- CUSTOMER (USER) INFORMATION -----
    -- NOTE: user_ssn, credit_card_number, credit_card_expiration_date,
    --       CVV, IBAN are EXCLUDED here.
    user_id                     VARCHAR(50),
    user_username               VARCHAR(100),
    user_name                   VARCHAR(100),
    user_gender                 VARCHAR(10),
    user_email                  VARCHAR(100),
    user_age                    INTEGER,
    user_address                VARCHAR(200),
    user_city                   VARCHAR(100),
    user_state                  VARCHAR(10),
    user_postal_code            VARCHAR(20),
    user_phone_number           VARCHAR(50),

    -- ----- EMPLOYEE INFORMATION -----
    -- NOTE: ee_ssn EXCLUDED – sensitive field.
    ee_id                       VARCHAR(50),
    ee_username                 VARCHAR(100),
    ee_name                     VARCHAR(100),
    ee_gender                   VARCHAR(10),
    ee_email                    VARCHAR(100),
    ee_address                  VARCHAR(200),
    ee_city                     VARCHAR(100),
    ee_state                    VARCHAR(10),
    ee_postal_code              VARCHAR(20),
    ee_phone_number             VARCHAR(50),

    -- ----- TECHNICAL ATTRIBUTES -----
    ta_insert_dt                DATE NOT NULL DEFAULT CURRENT_DATE
);

COMMENT ON TABLE sa_ecom.src_ecom_sales IS
    'Source table for ecom-sample.csv. Deduplicated, typed copy of '
    'ext_ecom_sales. Column "date" renamed to transaction_date. '
    'Sensitive columns (SSN, card details, IBAN) excluded. '
    'TA_INSERT_DT records when the row was loaded into SA layer.';