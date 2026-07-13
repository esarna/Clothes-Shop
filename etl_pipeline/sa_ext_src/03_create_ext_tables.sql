-- ============================================================
-- Create EXTERNAL (FOREIGN) tables on SA layer
-- ============================================================
-- 1. sa_retail.ext_retail_sales
--    Source file: retail-sample.csv
-- ============================================================
DROP FOREIGN TABLE IF EXISTS sa_retail.ext_retail_sales;

CREATE FOREIGN TABLE sa_retail.ext_retail_sales (
    -- ----- PRODUCT INFORMATION -----
    product_code                VARCHAR(50),
    description                 VARCHAR(200),
    colour                      VARCHAR(50),
    size                        VARCHAR(20),
    subcategory                 VARCHAR(100),
    category                    VARCHAR(100),
    top_category                VARCHAR(100),
    cost                        VARCHAR(50),    -- DECIMAL in src_

    -- ----- TRANSACTION INFORMATION -----
    bill_id                     VARCHAR(50),
    transaction_date            VARCHAR(50),    -- DATE in src_ (format YYYY-MM-DD)
    line_item_amount            VARCHAR(50),    -- DECIMAL in src_
    bill_discount               VARCHAR(50),    -- DECIMAL in src_
    min_amount                  VARCHAR(50),    -- DECIMAL in src_
    quantity_sold               VARCHAR(50),    -- INTEGER in src_
    payment_method              VARCHAR(50),

    -- ----- STORE INFORMATION -----
    store_code                  VARCHAR(50),
    zone_code                   VARCHAR(50),
    store_address               VARCHAR(200),
    store_city                  VARCHAR(100),
    store_state                 VARCHAR(10),
    store_postal_code           VARCHAR(20),

    -- ----- CUSTOMER INFORMATION -----
    customer_id                 VARCHAR(50),
    customer_ssn                VARCHAR(50),    -- SENSITIVE: excluded from src_
    customer_name               VARCHAR(100),
    customer_gender             VARCHAR(10),
    customer_age                VARCHAR(10),    -- INTEGER in src_
    customer_address            VARCHAR(200),
    customer_city               VARCHAR(100),
    customer_state              VARCHAR(10),
    customer_postal_Code        VARCHAR(20),
    customer_phone_number       VARCHAR(50),

    -- ----- CREDIT CARD INFORMATION (SENSITIVE - NOT propagated downstream) -----
    credit_card_number          VARCHAR(50),    -- SENSITIVE: excluded from src_
    credit_card_Expiration_Date VARCHAR(50),    -- SENSITIVE: excluded from src_
    Credit_card_CVV             VARCHAR(10),    -- SENSITIVE: excluded from src_
    bank_number                 VARCHAR(50),    -- SENSITIVE: excluded from src_

    -- ----- EMPLOYEE INFORMATION -----
    employee_id                 VARCHAR(50),
    employee_ssn                VARCHAR(50),    -- SENSITIVE: excluded from src_
    employee_name               VARCHAR(100),
    employee_gender             VARCHAR(10),
    employee_email              VARCHAR(100),
    employee_address            VARCHAR(200),
    employee_city               VARCHAR(100),
    employee_state              VARCHAR(10),
    employee_postal_code        VARCHAR(20),
    employee_phone_number       VARCHAR(50)
)
SERVER file_server
OPTIONS (
    filename  '\Users\EmiliaSarna\Projects\Clothes-Shop\data\retail-sample.csv',
    format    'csv',
    header    'true',
    delimiter ',',
    null      ''
);

COMMENT ON FOREIGN TABLE sa_retail.ext_retail_sales IS
    'External (foreign) table - direct 1:1 mirror of retail-sample.csv. '
    'All columns VARCHAR (raw). Sensitive columns present for raw audit '
    'only - excluded from src_ and all downstream layers.';


-- ============================================================
-- 2. sa_ecom.ext_ecom_sales
--    Source file: ecom-sample.csv
-- ============================================================
DROP FOREIGN TABLE IF EXISTS sa_ecom.ext_ecom_sales;

CREATE FOREIGN TABLE sa_ecom.ext_ecom_sales (
    -- ----- PRODUCT INFORMATION -----
    product_code                    VARCHAR(50),
    details                         VARCHAR(100),
    product_type                    VARCHAR(100),
    cost                            VARCHAR(50),    -- DECIMAL in src_

    -- ----- TRANSACTION INFORMATION -----
    payment_id                      VARCHAR(50),
    "date"                          VARCHAR(50),    -- DATE in src_ (format YYYY-MM-DD); quoted: reserved word
    sales_amount                    VARCHAR(50),    -- DECIMAL in src_
    discount                        VARCHAR(50),    -- DECIMAL in src_
    payment_type                    VARCHAR(50),
    quantity                        VARCHAR(50),    -- INTEGER in src_

    -- ----- CUSTOMER (USER) INFORMATION -----
    user_id                         VARCHAR(50),
    user_ssn                        VARCHAR(50),    -- SENSITIVE: excluded from src_
    user_username                   VARCHAR(100),
    user_name                       VARCHAR(100),
    user_gender                     VARCHAR(10),
    user_email                      VARCHAR(100),
    user_age                        VARCHAR(10),    -- INTEGER in src_
    user_address                    VARCHAR(200),
    user_city                       VARCHAR(100),
    user_state                      VARCHAR(10),
    user_postal_code                VARCHAR(20),
    user_phone_number               VARCHAR(50),

    -- ----- CREDIT CARD INFORMATION (SENSITIVE - NOT propagated downstream) -----
    user_credit_card_number              VARCHAR(50),    -- SENSITIVE: excluded from src_
    user_credit_card_expiration_date     VARCHAR(50),    -- SENSITIVE: excluded from src_
    user_CVV                             VARCHAR(10),    -- SENSITIVE: excluded from src_
    user_IBAN                            VARCHAR(50),    -- SENSITIVE: excluded from src_

    -- ----- EMPLOYEE INFORMATION -----
    ee_id                           VARCHAR(50),
    ee_ssn                          VARCHAR(50),    -- SENSITIVE: excluded from src_
    ee_username                     VARCHAR(100),
    ee_name                         VARCHAR(100),
    ee_gender                       VARCHAR(10),
    ee_email                        VARCHAR(100),
    ee_address                      VARCHAR(200),
    ee_city                         VARCHAR(100),
    ee_state                        VARCHAR(10),
    ee_postal_code                  VARCHAR(20),
    ee_phone_number                 VARCHAR(50)
)
SERVER file_server
OPTIONS (
    filename  '\Users\EmiliaSarna\Projects\Clothes-Shop\data\ecom-sample.csv',
    format    'csv',
    header    'true',
    delimiter ',',
    null      ''
);

COMMENT ON FOREIGN TABLE sa_ecom.ext_ecom_sales IS
    'External (foreign) table - direct 1:1 mirror of ecom-sample.csv. '
    'All columns VARCHAR (raw). Column "date" quoted (SQL reserved word). '
    'Sensitive columns present for raw audit only - excluded from src_ '
    'and all downstream layers.';