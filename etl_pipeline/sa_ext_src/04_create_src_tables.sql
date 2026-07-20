-- ============================================================
-- Create SOURCE tables on SA layer
--
-- ============================================================
-- COLUMN → TARGET MAPPING
-- ============================================================
--
-- RETAIL SOURCE (sa_retail.src_retail_sales)
-- ┌─────────────────────────────────────────┬─────────────────────────────────────────────────┐
-- │ SRC Column(s)                           │ Target Table(s)                                 │
-- ├─────────────────────────────────────────┼─────────────────────────────────────────────────┤
-- │ product_code                            │ CE_PRODUCTS_SCD (NK)                            │
-- │ subcategory                             │ CE_PRODUCT_SUBCATEGORIES                        │
-- │ category                                │ CE_PRODUCT_CATEGORIES                           │
-- │ top_category                            │ CE_PRODUCT_TOP_CATEGORIES                       │
-- │ description, colour, size, min_amount   │ CE_PRODUCTS_SCD                                 │
-- │ cost                                    │ CE_SALES (KPI) + FCT_SALES_DD.FCT_UNIT_COST     │
-- ├─────────────────────────────────────────┼─────────────────────────────────────────────────┤
-- │ bill_id                                 │ CE_SALES (NK) + FCT_SALES_DD.PAYMENT_SRC_ID     │
-- │ transaction_date                        │ CE_DATES + FCT_SALES_DD.EVENT_DT                │
-- │ line_item_amount                        │ CE_SALES.SALES_AMOUNT + FCT_SALES_DD            │
-- │ bill_discount                           │ CE_SALES.DISCOUNT + FCT_SALES_DD.FCT_DISCOUNT   │
-- │ quantity_sold                           │ CE_SALES.QUANTITY + FCT_SALES_DD.FCT_QUANTITY   │
-- │ payment_method                          │ CE_PAYMENT_TYPES                                │
-- ├─────────────────────────────────────────┼─────────────────────────────────────────────────┤
-- │ store_code                              │ CE_STORES (NK)                                  │
-- │ zone_code                               │ CE_STORE_ZONES                                  │
-- │ store_address, store_city,              │ CE_LOCATIONS                                    │
-- │   store_state, store_postal_code        │   via CE_STORES.STORE_LOCATION_ID               │
-- ├─────────────────────────────────────────┼─────────────────────────────────────────────────┤
-- │ customer_id                             │ CE_CUSTOMERS_SCD (NK)                           │
-- │ customer_name, customer_gender,         │ CE_CUSTOMERS_SCD                                │
-- │   customer_age, customer_phone_number   │                                                 │
-- │ customer_address, customer_city,        │ CE_LOCATIONS                                    │
-- │   customer_state, customer_postal_code  │   via CE_CUSTOMERS_SCD.CUSTOMER_LOCATION_ID     │
-- ├─────────────────────────────────────────┼─────────────────────────────────────────────────┤
-- │ employee_id                             │ CE_EMPLOYEES (NK)                               │
-- │ employee_name, employee_gender,         │ CE_EMPLOYEES                                    │
-- │   employee_email, employee_phone_number │                                                 │
-- │ employee_address, employee_city,        │ CE_LOCATIONS                                    │
-- │   employee_state, employee_postal_code  │   via CE_EMPLOYEES.EMPLOYEE_LOCATION_ID         │
-- └─────────────────────────────────────────┴─────────────────────────────────────────────────┘
--
-- ECOM SOURCE (sa_ecom.src_ecom_sales)
-- ┌─────────────────────────────────────────┬─────────────────────────────────────────────────┐
-- │ SRC Column(s)                           │ Target Table(s)                                 │
-- ├─────────────────────────────────────────┼─────────────────────────────────────────────────┤
-- │ product_code                            │ CE_PRODUCTS_SCD (NK)                            │
-- │ details                                 │ CE_PRODUCT_SUBCATEGORIES                        │
-- │ product_type                            │ CE_PRODUCT_CATEGORIES                           │
-- │ cost  ⚠ ≈1.0 = coefficient, not money  │ FCT_SALES_DD.FCT_UNIT_COST = NULL               │
-- ├─────────────────────────────────────────┼─────────────────────────────────────────────────┤
-- │ payment_id                              │ CE_SALES (NK) + FCT_SALES_DD.PAYMENT_SRC_ID     │
-- │ transaction_date  (CSV col: "date")     │ CE_DATES + FCT_SALES_DD.EVENT_DT                │
-- │ sales_amount                            │ CE_SALES.SALES_AMOUNT + FCT_SALES_DD            │
-- │ discount                                │ CE_SALES.DISCOUNT + FCT_SALES_DD.FCT_DISCOUNT   │
-- │ quantity                                │ CE_SALES.QUANTITY + FCT_SALES_DD.FCT_QUANTITY   │
-- │ payment_type                            │ CE_PAYMENT_TYPES                                │
-- ├─────────────────────────────────────────┼─────────────────────────────────────────────────┤
-- │ store info: NONE                        │ CE_STORES → STORE_SRC_ID = 'ECOMMERCE'          │
-- │                                         │ CE_STORE_ZONES → 'N/A'                          │
-- │                                         │ CE_LOCATIONS (store) → 'N/A'                    │
-- ├─────────────────────────────────────────┼─────────────────────────────────────────────────┤
-- │ user_id                                 │ CE_CUSTOMERS_SCD (NK)                           │
-- │ user_name, user_gender, user_age,       │ CE_CUSTOMERS_SCD                                │
-- │   user_email, user_phone_number         │                                                 │
-- │ user_address, user_city,                │ CE_LOCATIONS                                    │
-- │   user_state, user_postal_code          │   via CE_CUSTOMERS_SCD.CUSTOMER_LOCATION_ID     │
-- │ customer_email: NONE in retail          │ CE_CUSTOMERS_SCD.CUSTOMER_EMAIL = 'N/A'         │
-- ├─────────────────────────────────────────┼─────────────────────────────────────────────────┤
-- │ ee_id                                   │ CE_EMPLOYEES (NK)                               │
-- │ ee_name, ee_gender, ee_email,           │ CE_EMPLOYEES                                    │
-- │   ee_phone_number                       │                                                 │
-- │ ee_address, ee_city,                    │ CE_LOCATIONS                                    │
-- │   ee_state, ee_postal_code              │   via CE_EMPLOYEES.EMPLOYEE_LOCATION_ID         │
-- └─────────────────────────────────────────┴─────────────────────────────────────────────────┘
--
-- SENSITIVE COLUMNS EXCLUDED:
--   customer_ssn, credit_card_number, credit_card_expiration_date,
--   credit_card_cvv, bank_number (retail)
--   user_ssn, credit_card_number, credit_card_expiration_date,
--   cvv, iban (ecom)
--   employee_ssn / ee_ssn (both)
-- ============================================================


-- ============================================================
-- 1. sa_retail.src_retail_sales
-- ============================================================
DROP TABLE IF EXISTS sa_retail.src_retail_sales;

CREATE TABLE sa_retail.src_retail_sales (

    -- ----- PRODUCT → CE_PRODUCTS_SCD + CE_PRODUCT_SUBCATEGORIES
    --                   CE_PRODUCT_CATEGORIES + CE_PRODUCT_TOP_CATEGORIES -----
    product_code            VARCHAR(50),    
    description             VARCHAR(200),   
    colour                  VARCHAR(50),    
    size                    VARCHAR(20),    
    subcategory             VARCHAR(100),   
    category                VARCHAR(100),   
    top_category            VARCHAR(100),   
    min_amount              DECIMAL(18,8),  

    -- ----- COST → CE_SALES (KPI) + FCT_SALES_DD.FCT_UNIT_COST -----
    cost                    DECIMAL(18,8),

    -- ----- TRANSACTION → CE_SALES + FCT_SALES_DD -----
    bill_id                 VARCHAR(50),    
    transaction_date        DATE,           
    line_item_amount        DECIMAL(18,8),  
    bill_discount           DECIMAL(18,8), 
    -- NOTE: FCT_NET_AMOUNT (RETAIL) = line_item_amount – bill_discount
    --       (one line item per bill in current dataset; if multiple
    --        lines per bill exist, discount must be pro-rated)
    quantity_sold           INTEGER,        
    payment_method          VARCHAR(50),    

    -- ----- STORE → CE_STORES -----
    store_code              VARCHAR(50),    

    -- ----- ZONE → CE_STORE_ZONES -----
    zone_code               VARCHAR(50),    

    -- ----- STORE ADDRESS → CE_LOCATIONS -----
    store_address           VARCHAR(200),
    store_city              VARCHAR(100),
    store_state             VARCHAR(10),
    store_postal_code       VARCHAR(20),

    -- ----- CUSTOMER → CE_CUSTOMERS_SCD -----
    -- SENSITIVE EXCLUDED: customer_ssn, credit_card_*, bank_number
    customer_id             VARCHAR(50),    
    customer_name           VARCHAR(100),
    customer_gender         VARCHAR(10),
    customer_age            INTEGER,        
    customer_phone_number   VARCHAR(50),

    -- ----- CUSTOMER ADDRESS → CE_LOCATIONS (via CE_CUSTOMERS_SCD.CUSTOMER_LOCATION_ID) -----
    customer_address        VARCHAR(200),
    customer_city           VARCHAR(100),
    customer_state          VARCHAR(10),
    customer_postal_code    VARCHAR(20),

    -- ----- EMPLOYEE → CE_EMPLOYEES -----
    -- SENSITIVE EXCLUDED: employee_ssn
    employee_id             VARCHAR(50),    
    employee_name           VARCHAR(100),
    employee_gender         VARCHAR(10),
    employee_email          VARCHAR(100),
    employee_phone_number   VARCHAR(50),

    -- ----- EMPLOYEE ADDRESS → CE_LOCATIONS -----
    employee_address        VARCHAR(200),
    employee_city           VARCHAR(100),
    employee_state          VARCHAR(10),
    employee_postal_code    VARCHAR(20),

    -- ----- TECHNICAL ATTRIBUTES -----
    ta_insert_dt            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE sa_retail.src_retail_sales IS
    'Source table for retail-sample.csv. Deduplicated, typed, sensitive '
    'columns excluded. Maps to: CE_SALES, CE_CUSTOMERS_SCD, CE_EMPLOYEES, '
    'CE_PRODUCTS_SCD, CE_PRODUCT_SUBCATEGORIES, CE_PRODUCT_CATEGORIES, '
    'CE_PRODUCT_TOP_CATEGORIES, CE_STORES, CE_STORE_ZONES, CE_LOCATIONS, '
    'CE_PAYMENT_TYPES, CE_DATES (BL_3NF).';


-- ============================================================
-- 2. sa_ecom.src_ecom_sales
-- ============================================================
DROP TABLE IF EXISTS sa_ecom.src_ecom_sales;

CREATE TABLE sa_ecom.src_ecom_sales (

    -- ----- PRODUCT → CE_PRODUCTS_SCD + CE_PRODUCT_SUBCATEGORIES
    --                   CE_PRODUCT_CATEGORIES -----
    -- NOTE: ecom has NO top_category, description, colour, size, min_amount
    --       These will be set to 'NOT-CAPTURED' / NULL in BL_3NF
    product_code                VARCHAR(50),  
    details                     VARCHAR(100), 
    product_type                VARCHAR(100), 

    -- ----- COST → FCT_SALES_DD.FCT_UNIT_COST -----
    cost                        DECIMAL(18,8),

    -- ----- TRANSACTION → CE_SALES + FCT_SALES_DD -----
    payment_id                  VARCHAR(50),   
    transaction_date            DATE,          
    -- NOTE: FCT_NET_AMOUNT (ECOM) = sales_amount directly
    --       (discount is already applied; do NOT subtract again)
    sales_amount                DECIMAL(18,8),
    discount                    DECIMAL(18,8),
    payment_type                VARCHAR(50),   
    quantity                    INTEGER,       

    -- ----- CUSTOMER/USER → CE_CUSTOMERS_SCD -----
    -- SENSITIVE EXCLUDED: user_ssn, credit_card_*, cvv, iban
    -- NOTE: ecom has NO customer_email equivalent in retail →
    --       retail CE_CUSTOMERS_SCD.CUSTOMER_EMAIL = 'N/A'
    user_id                     VARCHAR(50),   
    user_username               VARCHAR(100),
    user_name                   VARCHAR(100),
    user_gender                 VARCHAR(10),
    user_email                  VARCHAR(100),  
    user_age                    INTEGER,       
-- ----- CUSTOMER ADDRESS → CE_LOCATIONS  -----
    
    user_phone_number           VARCHAR(50),
    user_address                VARCHAR(200),
    user_city                   VARCHAR(100),
    user_state                  VARCHAR(10),
    user_postal_code            VARCHAR(20),

    -- ----- EMPLOYEE → CE_EMPLOYEES -----
    -- SENSITIVE EXCLUDED: ee_ssn
    -- NOTE: ecom has NO store info → CE_STORES uses 'ECOMMERCE',
    --       CE_STORE_ZONES → 'N/A', CE_LOCATIONS store → 'N/A'
    ee_id                       VARCHAR(50),   
    ee_username                 VARCHAR(100),
    ee_name                     VARCHAR(100),
    ee_gender                   VARCHAR(10),
    ee_email                    VARCHAR(100),

    -- ----- EMPLOYEE ADDRESS → CE_LOCATIONS -----
    ee_address                  VARCHAR(200),
    ee_city                     VARCHAR(100),
    ee_state                    VARCHAR(10),
    ee_postal_code              VARCHAR(20),
    ee_phone_number             VARCHAR(50),

    -- ----- TECHNICAL ATTRIBUTES -----
    ta_insert_dt            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE sa_ecom.src_ecom_sales IS
    'Source table for ecom-sample.csv. Deduplicated, typed, sensitive '
    'columns excluded. Column "date" renamed to transaction_date. '
    'cost ≈ 1.0 in ecom = coefficient, FCT_UNIT_COST set to NULL in BL_DM. '
    'No store info → CE_STORES.STORE_SRC_ID = ECOMMERCE. '
    'Maps to same BL_3NF targets as sa_retail (unified DWH model).';