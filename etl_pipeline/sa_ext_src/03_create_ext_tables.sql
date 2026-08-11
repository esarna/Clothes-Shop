-- ============================================================
-- Create EXTERNAL (FOREIGN) tables on SA layer

-- COLUMN ORDER matches exact CSV header order.
-- ALL columns VARCHAR – raw data, type casting in 05_load_src_.
-- NULL handling: null '' in OPTIONS (empty string = NULL).
--
-- SENSITIVE DATA NOTE:
--   Columns marked SENSITIVE are present here because ext_ is
--   a 1:1 raw mirror of the CSV. They are INTENTIONALLY EXCLUDED
--   from src_ and all downstream layers.
-- ============================================================


-- ============================================================
-- 1. sa_retail.ext_retail_sales
--    CSV header order:
--    customer_id, bill_id, line_item_amount, bill_discount,
--    transaction_date, description, colour, size, zone_code,
--    store_code, product_code, subcategory, top_category,
--    category, min_amount, cost, payment_method, employee_id,
--    customer_ssn, customer_name, customer_gender, customer_age,
--    credit_card_number, credit_card_Expiration_Date,
--    Credit_card_CVV, bank_number, employee_ssn, employee_name,
--    employee_gender, employee_email, store_address, store_city,
--    store_state, store_postal_code, employee_address,
--    employee_city, employee_state, employee_postal_code,
--    customer_address, customer_city, customer_state,
--    customer_postal_Code, customer_phone_number,
--    employee_phone_number, quantity_sold
-- ============================================================
DROP FOREIGN TABLE IF EXISTS sa_retail.ext_retail_sales;

CREATE FOREIGN TABLE sa_retail.ext_retail_sales (
    customer_id                     VARCHAR(50),
    bill_id                         VARCHAR(50),
    line_item_amount                VARCHAR(50),
    bill_discount                   VARCHAR(50),
    transaction_date                VARCHAR(50),
    description                     VARCHAR(200),
    colour                          VARCHAR(50),
    size                            VARCHAR(20),
    zone_code                       VARCHAR(50),
    store_code                      VARCHAR(50),
    product_code                    VARCHAR(50),
    subcategory                     VARCHAR(100),
    top_category                    VARCHAR(100),
    category                        VARCHAR(100),
    min_amount                      VARCHAR(50),
    cost                            VARCHAR(50),
    payment_method                  VARCHAR(50),
    employee_id                     VARCHAR(50),
    customer_ssn                    VARCHAR(50),    -- SENSITIVE: raw only, excluded from src_
    customer_name                   VARCHAR(100),
    customer_gender                 VARCHAR(10),
    customer_age                    VARCHAR(10),
    credit_card_number              VARCHAR(50),    -- SENSITIVE: excluded from src_
    credit_card_expiration_date     VARCHAR(50),    -- SENSITIVE: excluded from src_
    credit_card_cvv                 VARCHAR(10),    -- SENSITIVE: excluded from src_
    bank_number                     VARCHAR(50),    -- SENSITIVE: excluded from src_
    employee_ssn                    VARCHAR(50),    -- SENSITIVE: excluded from src_
    employee_name                   VARCHAR(100),
    employee_gender                 VARCHAR(10),
    employee_email                  VARCHAR(100),
    store_address                   VARCHAR(200),
    store_city                      VARCHAR(100),
    store_state                     VARCHAR(10),
    store_postal_code               VARCHAR(20),
    employee_address                VARCHAR(200),
    employee_city                   VARCHAR(100),
    employee_state                  VARCHAR(10),
    employee_postal_code            VARCHAR(20),
    customer_address                VARCHAR(200),
    customer_city                   VARCHAR(100),
    customer_state                  VARCHAR(10),
    customer_postal_code            VARCHAR(20),
    customer_phone_number           VARCHAR(50),
    employee_phone_number           VARCHAR(50),
    quantity_sold                   VARCHAR(50)
)
SERVER file_server
OPTIONS (
    filename  'C:/Program Files/PostgreSQL/18/data/retail-sample.csv',
    format    'csv',
    header    'true',
    delimiter ',',
    null      ''
);

COMMENT ON FOREIGN TABLE sa_retail.ext_retail_sales IS
    'External table – 1:1 mirror of retail-sample.csv. '
    'Column order matches CSV header exactly. '
    'Sensitive columns present for raw audit only.';


-- ============================================================
-- 2. sa_ecom.ext_ecom_sales
--    CSV header order:
--    user_id, payment_id, sales_amount, discount, date,
--    details, product_type, payment_type, ee_id, user_ssn,
--    user_username, user_name, user_gender, user_email,
--    user_age, user_credit_card_number,
--    user_credit_card_expiration_date, user_CVV, user_IBAN,
--    ee_ssn, ee_username, ee_name, ee_gender, ee_address,
--    ee_email, cost, user_phone_number, user_address,
--    user_city, user_state, user_postal_code, ee_address,
--    ee_city, ee_state, ee_postal_code, product_code,
--    quantity, ee_phone_number
--
-- NOTE: Two columns named "ee_address" in CSV header –
--       first occurrence = ee_address (employee address street),
--       second occurrence = duplicate/error in source.
--       Both mapped with distinct names below.
-- ============================================================
DROP FOREIGN TABLE IF EXISTS sa_ecom.ext_ecom_sales;

CREATE FOREIGN TABLE sa_ecom.ext_ecom_sales (
    user_id                             VARCHAR(50),
    payment_id                          VARCHAR(50),
    sales_amount                        VARCHAR(50),
    discount                            VARCHAR(50),
    transaction_date                    VARCHAR(50),    -- CSV col: "date" (reserved word – renamed)
    details                             VARCHAR(100),
    product_type                        VARCHAR(100),
    payment_type                        VARCHAR(50),
    ee_id                               VARCHAR(50),
    user_ssn                            VARCHAR(50),    -- SENSITIVE: excluded from src_
    user_username                       VARCHAR(100),
    user_name                           VARCHAR(100),
    user_gender                         VARCHAR(10),
    user_email                          VARCHAR(100),
    user_age                            VARCHAR(10),
    credit_card_number                  VARCHAR(50),    -- SENSITIVE: excluded from src_
    credit_card_expiration_date         VARCHAR(50),    -- SENSITIVE: excluded from src_
    cvv                                 VARCHAR(10),    -- SENSITIVE: excluded from src_
    iban                                VARCHAR(50),    -- SENSITIVE: excluded from src_
    ee_ssn                              VARCHAR(50),    -- SENSITIVE: excluded from src_
    ee_username                         VARCHAR(100),
    ee_name                             VARCHAR(100),
    ee_gender                           VARCHAR(10),
    ee_address                          VARCHAR(200),
    ee_email                            VARCHAR(100),
    cost                                VARCHAR(50),
    user_phone_number                   VARCHAR(50),
    user_address                        VARCHAR(200),
    user_city                           VARCHAR(100),
    user_state                          VARCHAR(10),
    user_postal_code                    VARCHAR(20),
    ee_address_2                        VARCHAR(200),   -- duplicate "ee_address" col in CSV
    ee_city                             VARCHAR(100),
    ee_state                            VARCHAR(10),
    ee_postal_code                      VARCHAR(20),
    product_code                        VARCHAR(50),
    quantity                            VARCHAR(50),
    ee_phone_number                     VARCHAR(50)
)
SERVER file_server
OPTIONS (
    filename  'C:/Program Files/PostgreSQL/18/data/ecom-sample.csv',
    format    'csv',
    header    'true',
    delimiter ',',
    null      ''
);

COMMENT ON FOREIGN TABLE sa_ecom.ext_ecom_sales IS
    'External table – 1:1 mirror of ecom-sample.csv. '
    'Column "date" renamed to transaction_date (SQL reserved word). '
    'Duplicate ee_address column mapped as ee_address_2. '
    'Sensitive columns present for raw audit only.';