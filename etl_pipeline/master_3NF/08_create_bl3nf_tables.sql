-- DDL - All BL_3NF CE_ tables (rerunnable: DROP TABLE IF EXISTS + CREATE TABLE)

-- Tables to create (in dependency order):
-- bl_3nf.CE_DATES - SCD Type 0
-- Columns: DATE_ID, DATE_SRC_ID, FULL_DT, DAY_OF_WEEK_NUM, DAY_OF_WEEK_DESC, IS_WEEKEND, DAY_OF_MONTH_NUM, WEEK_NUM, MONTH_NUM, MONTH_DESC, QUARTER_NUM, YEAR_NUM, TA_INSERT_DT, SOURCE_SYSTEM, SOURCE_ENTITY
-- PK: DATE_ID
-- No TA_UPDATE_DT (SCD Type 0 - immutable)
-- bl_3nf.CE_PAYMENT_TYPES - SCD Type 0
-- Columns: PAYMENT_TYPE_ID, PAYMENT_TYPE_SRC_ID, PAYMENT_TYPE_NAME, TA_INSERT_DT, SOURCE_SYSTEM, SOURCE_ENTITY
-- PK: PAYMENT_TYPE_ID
-- No TA_UPDATE_DT
-- bl_3nf.CE_STORE_ZONES - SCD Type 0
-- Columns: STORE_ZONE_ID, STORE_ZONE_SRC_ID, STORE_ZONE_NAME, TA_INSERT_DT, SOURCE_SYSTEM, SOURCE_ENTITY
-- PK: STORE_ZONE_ID
-- No TA_UPDATE_DT
-- bl_3nf.CE_PRODUCT_TOP_CATEGORIES - SCD Type 1
-- Columns: PRODUCT_TOP_CATEGORY_ID, PRODUCT_TOP_CATEGORY_SRC_ID, PRODUCT_TOP_CATEGORY_NAME, TA_INSERT_DT, TA_UPDATE_DT, SOURCE_SYSTEM, SOURCE_ENTITY
-- PK: PRODUCT_TOP_CATEGORY_ID
-- bl_3nf.CE_PRODUCT_CATEGORIES - SCD Type 1
-- Columns: PRODUCT_CATEGORY_ID, PRODUCT_CATEGORY_SRC_ID, PRODUCT_CATEGORY_NAME, PRODUCT_TOP_CATEGORY_ID (FK), TA_INSERT_DT, TA_UPDATE_DT, SOURCE_SYSTEM, SOURCE_ENTITY
-- PK: PRODUCT_CATEGORY_ID
-- FK → CE_PRODUCT_TOP_CATEGORIES
-- bl_3nf.CE_PRODUCT_SUBCATEGORIES - SCD Type 1
-- Columns: PRODUCT_SUBCATEGORY_ID, PRODUCT_SUBCATEGORY_SRC_ID, PRODUCT_SUBCATEGORY_NAME, PRODUCT_CATEGORY_ID (FK), TA_INSERT_DT, TA_UPDATE_DT, SOURCE_SYSTEM, SOURCE_ENTITY
-- PK: PRODUCT_SUBCATEGORY_ID
-- FK → CE_PRODUCT_CATEGORIES
-- bl_3nf.CE_LOCATIONS - SCD Type 1
-- Columns: LOCATION_ID, LOCATION_SRC_ID, LOCATION_ADDRESS, LOCATION_POSTAL_CODE, LOCATION_CITY, LOCATION_STATE, TA_INSERT_DT, TA_UPDATE_DT, SOURCE_SYSTEM, SOURCE_ENTITY
-- PK: LOCATION_ID
-- LOCATION_SRC_ID = generated from address components (hash/concatenation)
-- bl_3nf.CE_STORES - SCD Type 1
-- Columns: STORE_ID, STORE_SRC_ID, STORE_CHANNEL, STORE_ZONE_ID (FK), STORE_LOCATION_ID (FK), TA_INSERT_DT, TA_UPDATE_DT, SOURCE_SYSTEM, SOURCE_ENTITY
-- PK: STORE_ID
-- FK → CE_STORE_ZONES, CE_LOCATIONS
-- bl_3nf.CE_EMPLOYEES - SCD Type 1
-- Columns: EMPLOYEE_ID, EMPLOYEE_SRC_ID, EMPLOYEE_NAME, EMPLOYEE_GENDER, EMPLOYEE_EMAIL, EMPLOYEE_PHONE_NUMBER, EMPLOYEE_LOCATION_ID (FK), TA_INSERT_DT, TA_UPDATE_DT, SOURCE_SYSTEM, SOURCE_ENTITY
-- PK: EMPLOYEE_ID
-- FK → CE_LOCATIONS
-- bl_3nf.CE_CUSTOMERS_SCD - SCD Type 2 
-- Columns: CUSTOMER_ID, CUSTOMER_SRC_ID, CUSTOMER_NAME, CUSTOMER_GENDER, CUSTOMER_EMAIL, CUSTOMER_PHONE_NUMBER, CUSTOMER_LOCATION_ID (logical FK), START_DT, END_DT, IS_ACTIVE, TA_INSERT_DT, TA_UPDATE_DT, SOURCE_SYSTEM, SOURCE_ENTITY
-- PK: composite (CUSTOMER_ID, START_DT)
--  No DB FK constraint (SCD2 - logical FK only, per convention)
-- bl_3nf.CE_PRODUCTS_SCD - SCD Type 2 
-- Columns: PRODUCT_ID, PRODUCT_SRC_ID, PRODUCT_SUBCATEGORY_ID (FK), PRODUCT_DESCRIPTION, PRODUCT_COLOUR, PRODUCT_SIZE, PRODUCT_MIN_AMOUNT, START_DT, END_DT, IS_ACTIVE, TA_INSERT_DT, TA_UPDATE_DT, SOURCE_SYSTEM, SOURCE_ENTITY
-- PK: composite (PRODUCT_ID, START_DT)
-- FK → CE_PRODUCT_SUBCATEGORIES
--  No DB FK constraint from fact table (SCD2)
-- bl_3nf.CE_SALES - Fact entity (CE_ naming per 3NF rules)
-- Columns: SALE_ID, SALE_SRC_ID, DATE_ID (FK), CUSTOMER_ID (logical FK), EMPLOYEE_ID (FK), PRODUCT_ID (logical FK), STORE_ID (FK), PAYMENT_TYPE_ID (FK), SALES_AMOUNT, DISCOUNT, COST, QUANTITY, TA_INSERT_DT, TA_UPDATE_DT, SOURCE_SYSTEM, SOURCE_ENTITY
-- PK: SALE_ID
-- FK → CE_DATES, CE_EMPLOYEES, CE_STORES, CE_PAYMENT_TYPES
--  Logical FK only → CE_CUSTOMERS_SCD, CE_PRODUCTS_SCD (SCD2 - no DB constraint)
-- KPI columns (SALES_AMOUNT, DISCOUNT, COST, QUANTITY) = nullable
--  All DDL scripts must be: DROP TABLE IF EXISTS → CREATE TABLE - rerunnable without errors.
--  All sequences: DROP SEQUENCE IF EXISTS → CREATE SEQUENCE - rerunnable.
--  All non-KPI columns: NOT NULL constraint.
--  Naming: TA_INSERT_DT, TA_UPDATE_DT (per TA_ prefix convention).

-- ============================================================
-- FILE:    08_create_bl3nf_tables.sql
-- LAYER:   BL_3NF (Business Layer - Third Normal Form)
-- PURPOSE: DDL - Create all Core Entity (CE_) tables for the
--          Clothes Shop DWH in the BL_3NF schema.
--
-- EXECUTION ORDER IN PIPELINE:
--   01_create_schemas.sql               ← SA schemas
--   02_setup_file_fdw.sql               ← file_fdw extension + server
--   03_create_ext_tables.sql            ← EXT_ foreign tables
--   04_create_src_tables.sql            ← SRC_ staging tables
--   05_load_src_tables.sql              ← SA layer incremental load
--   06_create_bl3nf_schema.sql          ← BL_3NF schema
--   07_create_bl3nf_sequences.sql       ← BL_3NF sequences
--   >>> 08_create_bl3nf_tables.sql      ← YOU ARE HERE
--   09_insert_bl3nf_default_rows.sql
--   10_load_bl3nf_tables.sql
--
-- RERUNNABLE:  YES
--   Tables are dropped (CASCADE) and recreated on each run.
--   Safe to execute multiple times. Run AFTER sequences script
--   (sequences survive DROP TABLE CASCADE).
--
-- SOURCES:
--   SA_RETAIL  →  sa_retail.src_retail_sales
--   SA_ECOM    →  sa_ecom.src_ecom_sales
--
-- NAMING CONVENTIONS (per Naming_Conventions.docx):
--   Schema        : bl_3nf
--   SCD Type 0/1  : CE_<Name in Plural>
--   SCD Type 2    : CE_<Name in Plural>_SCD
--   Fact (3NF)    : CE_SALES  (CE_ prefix, no SCD suffix)
--   PK surrogate  : <Name>_ID  BIGINT  (generated by SEQUENCE)
--   Natural key   : <Name>_SRC_ID  VARCHAR
--   Date columns  : postfix _DT  (e.g. TA_INSERT_DT, FULL_DT)
--   Technical cols: prefix TA_  (TA_INSERT_DT, TA_UPDATE_DT)
--   IDs           : BIGINT NOT NULL - SEQUENCE only, no SERIAL
--
-- COLUMN RULES (per Naming_Conventions.docx §Column):
--   • ALL columns NOT NULL except KPI metrics in CE_SALES
--   • SCD Type 2: composite PK = (_ID + START_DT)
--   • SCD Type 0: no TA_UPDATE_DT (rows never modified)
--   • SCD Type 1: TA_INSERT_DT + TA_UPDATE_DT
--   • SCD Type 2: START_DT, END_DT, IS_ACTIVE, TA_INSERT_DT
--                 (no TA_UPDATE_DT - new row inserted on change)
--   • Source triplet: SOURCE_SYSTEM, SOURCE_ENTITY, <Name>_SRC_ID
--
-- FK CONSTRAINT RULES (per Naming_Conventions.docx §SCD Type 2):
--   • FK constraints from CE_SALES to SCD2 tables (CE_CUSTOMERS_SCD,
--     CE_PRODUCTS_SCD) are STRICTLY PROHIBITED at DB level.
--     These are LOGICAL FKs only (enforced via ETL, not DB engine).
--   • FK constraints to SCD Type 0/1 tables ARE enforced at DB level.
--
-- DEFAULT ROW POLICY (per Default-value.pptx):
--   • Every CE_ dimension table (ALL except CE_SALES) must have
--     a default row with surrogate key = -1.
--   • Default rows are inserted in 09_insert_bl3nf_default_rows.sql.
--
-- TABLE CREATION ORDER (dependency-safe):
--   Group 1 - SCD Type 0 (no FKs):
--     CE_DATES, CE_STORE_ZONES, CE_PAYMENT_TYPES
--   Group 2 - SCD Type 1, product hierarchy (top-down):
--     CE_PRODUCT_TOP_CATEGORIES → CE_PRODUCT_CATEGORIES
--     → CE_PRODUCT_SUBCATEGORIES
--   Group 3 - SCD Type 1, address + store chain:
--     CE_LOCATIONS → CE_EMPLOYEES, CE_STORES
--   Group 4 - SCD Type 2 (composite PK):
--     CE_CUSTOMERS_SCD, CE_PRODUCTS_SCD
--   Group 5 - Fact table:
--     CE_SALES
--
-- SCD TYPE SUMMARY (per Business_Template.docx §2.2):
--   SCD Type 0 : CE_DATES, CE_PAYMENT_TYPES, CE_STORE_ZONES
--   SCD Type 1 : CE_LOCATIONS, CE_PRODUCT_TOP_CATEGORIES,
--                CE_PRODUCT_CATEGORIES, CE_PRODUCT_SUBCATEGORIES,
--                CE_EMPLOYEES, CE_STORES
--   SCD Type 2 : CE_CUSTOMERS_SCD, CE_PRODUCTS_SCD
--   Fact       : CE_SALES
--
-- AUTHOR:  DWH ETL Pipeline
-- CREATED: 2024-01-01
-- ============================================================


-- ============================================================
-- GROUP 1 - SCD TYPE 0: Immutable reference tables
--           Rows are inserted ONCE and NEVER modified.
--           → No TA_UPDATE_DT column (per Naming_Conventions.docx).
--           → SOURCE_SYSTEM = 'MANUAL', SOURCE_ENTITY = 'MANUAL'
--              for default and static reference rows.
-- ============================================================

-- ------------------------------------------------------------
-- 1.1  CE_DATES
--      SCD Type 0 - Calendar / date dimension.
--      NK: DATE_SRC_ID = TO_CHAR(transaction_date, 'YYYYMMDD')
--      Sources: src_retail_sales.transaction_date
--               src_ecom_sales.transaction_date
--      No FK dependencies.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS bl_3nf.ce_dates CASCADE;

CREATE TABLE bl_3nf.ce_dates (
    date_id             BIGINT          NOT NULL    DEFAULT nextval('bl_3nf.seq_ce_dates'),
    date_src_id         VARCHAR(100)    NOT NULL,
    full_dt             DATE            NOT NULL,
    day_of_week_num     INTEGER         NOT NULL,
    day_of_week_desc    VARCHAR(25)     NOT NULL,
    is_weekend          INTEGER         NOT NULL,
    day_of_month_num    INTEGER         NOT NULL,
    week_num            INTEGER         NOT NULL,
    month_num           CHAR(2)         NOT NULL,
    month_desc          VARCHAR(25)     NOT NULL,
    quarter_num         CHAR(1)         NOT NULL,
    year_num            CHAR(4)         NOT NULL,
    ta_insert_dt        DATE            NOT NULL,
    source_system       VARCHAR(50)     NOT NULL,
    source_entity       VARCHAR(50)     NOT NULL,
    CONSTRAINT pk_ce_dates PRIMARY KEY (date_id)
);

COMMENT ON TABLE  bl_3nf.ce_dates                IS 'SCD Type 0 - Calendar dimension. One row per calendar day. Populated from transaction_date columns in both source systems. Immutable: rows are never updated. NK: date_src_id = YYYYMMDD string.';
COMMENT ON COLUMN bl_3nf.ce_dates.date_id        IS 'Surrogate PK - generated by bl_3nf.seq_ce_dates.';
COMMENT ON COLUMN bl_3nf.ce_dates.date_src_id    IS 'Natural key - TO_CHAR(transaction_date, ''YYYYMMDD'').';
COMMENT ON COLUMN bl_3nf.ce_dates.full_dt        IS 'Actual calendar date. _DT postfix per naming convention.';
COMMENT ON COLUMN bl_3nf.ce_dates.day_of_week_num IS '1 = Monday, 7 = Sunday (ISO).';
COMMENT ON COLUMN bl_3nf.ce_dates.day_of_week_desc IS 'Monday - Sunday.';
COMMENT ON COLUMN bl_3nf.ce_dates.is_weekend     IS '1 = weekend (Sat/Sun), 0 = weekday.';
COMMENT ON COLUMN bl_3nf.ce_dates.day_of_month_num IS '1 - 31.';
COMMENT ON COLUMN bl_3nf.ce_dates.week_num       IS 'ISO week number 1 - 52/53.';
COMMENT ON COLUMN bl_3nf.ce_dates.month_num      IS '01 - 12.';
COMMENT ON COLUMN bl_3nf.ce_dates.month_desc     IS 'January - December.';
COMMENT ON COLUMN bl_3nf.ce_dates.quarter_num    IS '1 - 4.';
COMMENT ON COLUMN bl_3nf.ce_dates.year_num       IS 'YYYY.';
COMMENT ON COLUMN bl_3nf.ce_dates.ta_insert_dt   IS 'Technical: row creation date. TA_ prefix per naming convention.';
COMMENT ON COLUMN bl_3nf.ce_dates.source_system  IS 'Source triplet: system the row was loaded from (SA_RETAIL / SA_ECOM / MANUAL).';
COMMENT ON COLUMN bl_3nf.ce_dates.source_entity  IS 'Source triplet: entity/table the row was loaded from.';


-- ------------------------------------------------------------
-- 1.2  CE_STORE_ZONES
--      SCD Type 0 - Fixed zone reference values.
--      NK: STORE_ZONE_SRC_ID = UPPER(TRIM(zone_code))
--      Values: North / South / East / West / N/A (for ecom)
--      Sources: src_retail_sales.zone_code; ecom → 'N/A' constant
--      No FK dependencies.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS bl_3nf.ce_store_zones CASCADE;

CREATE TABLE bl_3nf.ce_store_zones (
    store_zone_id       BIGINT          NOT NULL    DEFAULT nextval('bl_3nf.seq_ce_store_zones'),
    store_zone_src_id   VARCHAR(100)    NOT NULL,
    store_zone_name     VARCHAR(50)     NOT NULL,
    ta_insert_dt        DATE            NOT NULL,
    source_system       VARCHAR(50)     NOT NULL,
    source_entity       VARCHAR(50)     NOT NULL,
    CONSTRAINT pk_ce_store_zones          PRIMARY KEY (store_zone_id),
    CONSTRAINT uq_ce_store_zones_src_id   UNIQUE      (store_zone_src_id)
);

COMMENT ON TABLE  bl_3nf.ce_store_zones                  IS 'SCD Type 0 - Fixed store zone reference. Values: North / South / East / West / N/A. Immutable after initial load. NK: store_zone_src_id = UPPER(TRIM(zone_code)).';
COMMENT ON COLUMN bl_3nf.ce_store_zones.store_zone_id    IS 'Surrogate PK - generated by bl_3nf.seq_ce_store_zones.';
COMMENT ON COLUMN bl_3nf.ce_store_zones.store_zone_src_id IS 'Natural key - UPPER(TRIM(zone_code)). E.g. NORTH, SOUTH, EAST, WEST, N/A.';
COMMENT ON COLUMN bl_3nf.ce_store_zones.store_zone_name  IS 'Human-readable zone name: North / South / East / West / N/A.';
COMMENT ON COLUMN bl_3nf.ce_store_zones.ta_insert_dt     IS 'Technical: row creation date.';
COMMENT ON COLUMN bl_3nf.ce_store_zones.source_system    IS 'Source triplet: SA_RETAIL or MANUAL.';
COMMENT ON COLUMN bl_3nf.ce_store_zones.source_entity    IS 'Source triplet: SRC_RETAIL_SALES or MANUAL.';


-- ------------------------------------------------------------
-- 1.3  CE_PAYMENT_TYPES
--      SCD Type 0 - Junk dimension for payment method labels.
--      NK: PAYMENT_TYPE_SRC_ID = UPPER(TRIM(payment_method/type))
--      Values: CASH / CREDIT CARD / DEBIT CARD
--      Sources: src_retail_sales.payment_method
--               src_ecom_sales.payment_type
--      No FK dependencies.
--      NOTE: No SOURCE_ID in raw data → NK generated from name.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS bl_3nf.ce_payment_types CASCADE;

CREATE TABLE bl_3nf.ce_payment_types (
    payment_type_id         BIGINT          NOT NULL    DEFAULT nextval('bl_3nf.seq_ce_payment_types'),
    payment_type_src_id     VARCHAR(100)    NOT NULL,
    payment_type_name       VARCHAR(50)     NOT NULL,
    ta_insert_dt            DATE            NOT NULL,
    source_system           VARCHAR(50)     NOT NULL,
    source_entity           VARCHAR(50)     NOT NULL,
    CONSTRAINT pk_ce_payment_types          PRIMARY KEY (payment_type_id),
    CONSTRAINT uq_ce_payment_types_src_id   UNIQUE      (payment_type_src_id)
);

COMMENT ON TABLE  bl_3nf.ce_payment_types                    IS 'SCD Type 0 - Junk dimension for payment method labels. Immutable. Values: Cash / Credit Card / Debit Card. NK generated from name (no source ID in raw data).';
COMMENT ON COLUMN bl_3nf.ce_payment_types.payment_type_id   IS 'Surrogate PK - generated by bl_3nf.seq_ce_payment_types.';
COMMENT ON COLUMN bl_3nf.ce_payment_types.payment_type_src_id IS 'Natural key - UPPER(TRIM(payment_method)). E.g. CASH, CREDIT CARD, DEBIT CARD.';
COMMENT ON COLUMN bl_3nf.ce_payment_types.payment_type_name IS 'Payment method label: Cash / Credit Card / Debit Card.';
COMMENT ON COLUMN bl_3nf.ce_payment_types.ta_insert_dt      IS 'Technical: row creation date.';
COMMENT ON COLUMN bl_3nf.ce_payment_types.source_system     IS 'Source triplet: SA_RETAIL / SA_ECOM / MANUAL.';
COMMENT ON COLUMN bl_3nf.ce_payment_types.source_entity     IS 'Source triplet: SRC_RETAIL_SALES / SRC_ECOM_SALES / MANUAL.';


-- ============================================================
-- GROUP 2 - SCD TYPE 1: Product category hierarchy
--           Loaded top-down to satisfy FK dependencies.
--           CE_PRODUCT_TOP_CATEGORIES
--             └─ CE_PRODUCT_CATEGORIES
--                  └─ CE_PRODUCT_SUBCATEGORIES
-- ============================================================

-- ------------------------------------------------------------
-- 2.1  CE_PRODUCT_TOP_CATEGORIES
--      SCD Type 1 - Broadest product classification level.
--      NK: PRODUCT_TOP_CATEGORY_SRC_ID = UPPER(TRIM(top_category))
--      Sources: src_retail_sales.top_category
--               ecom → no equivalent → FK in CE_PRODUCTS_SCD = -1
--      No FK dependencies.
--      NOTE: No _DESC column - not present in source data
--            (per Business_Template.docx §2.3.7).
-- ------------------------------------------------------------
DROP TABLE IF EXISTS bl_3nf.ce_product_top_categories CASCADE;

CREATE TABLE bl_3nf.ce_product_top_categories (
    product_top_category_id         BIGINT          NOT NULL    DEFAULT nextval('bl_3nf.seq_ce_product_top_categories'),
    product_top_category_src_id     VARCHAR(100)    NOT NULL,
    product_top_category_name       VARCHAR(100)    NOT NULL,
    ta_insert_dt                    DATE            NOT NULL,
    ta_update_dt                    DATE            NOT NULL,
    source_system                   VARCHAR(50)     NOT NULL,
    source_entity                   VARCHAR(50)     NOT NULL,
    CONSTRAINT pk_ce_product_top_categories         PRIMARY KEY (product_top_category_id),
    CONSTRAINT uq_ce_product_top_categories_src_id  UNIQUE      (product_top_category_src_id)
);

COMMENT ON TABLE  bl_3nf.ce_product_top_categories                          IS 'SCD Type 1 - Broadest product classification. E.g. TOPS, BOTTOMS, SHOES, ACCESSORIES. NK = UPPER(TRIM(top_category)). No _DESC column: not available in source data. Ecom has no top_category → FK in CE_PRODUCTS_SCD defaults to -1.';
COMMENT ON COLUMN bl_3nf.ce_product_top_categories.product_top_category_id IS 'Surrogate PK - generated by bl_3nf.seq_ce_product_top_categories.';
COMMENT ON COLUMN bl_3nf.ce_product_top_categories.product_top_category_src_id IS 'Natural key - UPPER(TRIM(top_category)) from sa_retail.';
COMMENT ON COLUMN bl_3nf.ce_product_top_categories.product_top_category_name   IS 'Top category name. E.g. TOPS, BOTTOMS, SHOES, ACCESSORIES.';
COMMENT ON COLUMN bl_3nf.ce_product_top_categories.ta_insert_dt                IS 'Technical: row creation date.';
COMMENT ON COLUMN bl_3nf.ce_product_top_categories.ta_update_dt                IS 'Technical: last update date (SCD1 - overwrite on change).';
COMMENT ON COLUMN bl_3nf.ce_product_top_categories.source_system               IS 'Source triplet: SA_RETAIL or MANUAL.';
COMMENT ON COLUMN bl_3nf.ce_product_top_categories.source_entity               IS 'Source triplet: SRC_RETAIL_SALES or MANUAL.';


-- ------------------------------------------------------------
-- 2.2  CE_PRODUCT_CATEGORIES
--      SCD Type 1 - Mid-level product classification.
--      NK: PRODUCT_CATEGORY_SRC_ID = UPPER(TRIM(category/product_type))
--      Sources: src_retail_sales.category
--               src_ecom_sales.product_type
--      FK: PRODUCT_TOP_CATEGORY_ID → CE_PRODUCT_TOP_CATEGORIES
--          (ecom: FK = -1 default row, retail: resolved by NK)
--      NOTE: No _DESC column - not present in source data
--            (per Business_Template.docx §2.3.6).
-- ------------------------------------------------------------
DROP TABLE IF EXISTS bl_3nf.ce_product_categories CASCADE;

CREATE TABLE bl_3nf.ce_product_categories (
    product_category_id         BIGINT          NOT NULL    DEFAULT nextval('bl_3nf.seq_ce_product_categories'),
    product_category_src_id     VARCHAR(100)    NOT NULL,
    product_category_name       VARCHAR(100)    NOT NULL,
    product_top_category_id     BIGINT          NOT NULL,
    ta_insert_dt                DATE            NOT NULL,
    ta_update_dt                DATE            NOT NULL,
    source_system               VARCHAR(50)     NOT NULL,
    source_entity               VARCHAR(50)     NOT NULL,
    CONSTRAINT pk_ce_product_categories             PRIMARY KEY (product_category_id),
    CONSTRAINT uq_ce_product_categories_src_id      UNIQUE      (product_category_src_id),
    CONSTRAINT fk_ce_product_categories_top_cat     FOREIGN KEY (product_top_category_id)
                                                    REFERENCES  bl_3nf.ce_product_top_categories (product_top_category_id)
);

COMMENT ON TABLE  bl_3nf.ce_product_categories                              IS 'SCD Type 1 - Mid-level product category. Sources: retail=category, ecom=product_type. FK to CE_PRODUCT_TOP_CATEGORIES (ecom FK = -1 default row). No _DESC column: not in source data.';
COMMENT ON COLUMN bl_3nf.ce_product_categories.product_category_id         IS 'Surrogate PK - generated by bl_3nf.seq_ce_product_categories.';
COMMENT ON COLUMN bl_3nf.ce_product_categories.product_category_src_id     IS 'Natural key - UPPER(TRIM(category)) retail / UPPER(TRIM(product_type)) ecom.';
COMMENT ON COLUMN bl_3nf.ce_product_categories.product_category_name       IS 'Category name. E.g. T-Shirts, Jeans, Sneakers.';
COMMENT ON COLUMN bl_3nf.ce_product_categories.product_top_category_id     IS 'FK → CE_PRODUCT_TOP_CATEGORIES. -1 for ecom records (no top_category in source).';
COMMENT ON COLUMN bl_3nf.ce_product_categories.ta_insert_dt                IS 'Technical: row creation date.';
COMMENT ON COLUMN bl_3nf.ce_product_categories.ta_update_dt                IS 'Technical: last update date (SCD1 - overwrite on change).';
COMMENT ON COLUMN bl_3nf.ce_product_categories.source_system               IS 'Source triplet: SA_RETAIL / SA_ECOM / MANUAL.';
COMMENT ON COLUMN bl_3nf.ce_product_categories.source_entity               IS 'Source triplet: SRC_RETAIL_SALES / SRC_ECOM_SALES / MANUAL.';


-- ------------------------------------------------------------
-- 2.3  CE_PRODUCT_SUBCATEGORIES
--      SCD Type 1 - Detailed product classification.
--      NK: PRODUCT_SUBCATEGORY_SRC_ID = UPPER(TRIM(subcategory/details))
--      Sources: src_retail_sales.subcategory
--               src_ecom_sales.details
--      FK: PRODUCT_CATEGORY_ID → CE_PRODUCT_CATEGORIES
--      NOTE: No _DESC column - not present in source data
--            (per Business_Template.docx §2.3.5).
-- ------------------------------------------------------------
DROP TABLE IF EXISTS bl_3nf.ce_product_subcategories CASCADE;

CREATE TABLE bl_3nf.ce_product_subcategories (
    product_subcategory_id          BIGINT          NOT NULL    DEFAULT nextval('bl_3nf.seq_ce_product_subcategories'),
    product_subcategory_src_id      VARCHAR(100)    NOT NULL,
    product_subcategory_name        VARCHAR(100)    NOT NULL,
    product_category_id             BIGINT          NOT NULL,
    ta_insert_dt                    DATE            NOT NULL,
    ta_update_dt                    DATE            NOT NULL,
    source_system                   VARCHAR(50)     NOT NULL,
    source_entity                   VARCHAR(50)     NOT NULL,
    CONSTRAINT pk_ce_product_subcategories              PRIMARY KEY (product_subcategory_id),
    CONSTRAINT uq_ce_product_subcategories_src_id       UNIQUE      (product_subcategory_src_id),
    CONSTRAINT fk_ce_product_subcategories_cat          FOREIGN KEY (product_category_id)
                                                        REFERENCES  bl_3nf.ce_product_categories (product_category_id)
);

COMMENT ON TABLE  bl_3nf.ce_product_subcategories                               IS 'SCD Type 1 - Detailed product subcategory. Sources: retail=subcategory, ecom=details. FK to CE_PRODUCT_CATEGORIES. No _DESC column: not in source data.';
COMMENT ON COLUMN bl_3nf.ce_product_subcategories.product_subcategory_id        IS 'Surrogate PK - generated by bl_3nf.seq_ce_product_subcategories.';
COMMENT ON COLUMN bl_3nf.ce_product_subcategories.product_subcategory_src_id    IS 'Natural key - UPPER(TRIM(subcategory)) retail / UPPER(TRIM(details)) ecom.';
COMMENT ON COLUMN bl_3nf.ce_product_subcategories.product_subcategory_name      IS 'Subcategory name. E.g. Polo T-Shirts, Slim Fit Jeans.';
COMMENT ON COLUMN bl_3nf.ce_product_subcategories.product_category_id           IS 'FK → CE_PRODUCT_CATEGORIES.';
COMMENT ON COLUMN bl_3nf.ce_product_subcategories.ta_insert_dt                  IS 'Technical: row creation date.';
COMMENT ON COLUMN bl_3nf.ce_product_subcategories.ta_update_dt                  IS 'Technical: last update date (SCD1 - overwrite on change).';
COMMENT ON COLUMN bl_3nf.ce_product_subcategories.source_system                 IS 'Source triplet: SA_RETAIL / SA_ECOM / MANUAL.';
COMMENT ON COLUMN bl_3nf.ce_product_subcategories.source_entity                 IS 'Source triplet: SRC_RETAIL_SALES / SRC_ECOM_SALES / MANUAL.';


-- ============================================================
-- GROUP 3 - SCD TYPE 1: Address and store chain
--           CE_LOCATIONS must be created before CE_EMPLOYEES
--           and CE_STORES (both reference it via FK).
-- ============================================================

-- ------------------------------------------------------------
-- 3.1  CE_LOCATIONS
--      SCD Type 1 - Shared address table for customers,
--      employees, and stores (per Business_Template §2.3.2).
--      NK: LOCATION_SRC_ID = COALESCE(TRIM(address),'n/a')
--                         || '_' || COALESCE(TRIM(postal_code),'n/a')
--      Sources: All address columns from both source systems
--               (store, customer, employee addresses).
--      No FK dependencies.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS bl_3nf.ce_locations CASCADE;

CREATE TABLE bl_3nf.ce_locations (
    location_id             BIGINT          NOT NULL    DEFAULT nextval('bl_3nf.seq_ce_locations'),
    location_src_id         VARCHAR(200)    NOT NULL,
    location_address        VARCHAR(200)    NOT NULL,
    location_postal_code    VARCHAR(10)     NOT NULL,
    location_city           VARCHAR(100)    NOT NULL,
    location_state          CHAR(2)         NOT NULL,
    ta_insert_dt            DATE            NOT NULL,
    ta_update_dt            DATE            NOT NULL,
    source_system           VARCHAR(50)     NOT NULL,
    source_entity           VARCHAR(50)     NOT NULL,
    CONSTRAINT pk_ce_locations              PRIMARY KEY (location_id),
    CONSTRAINT uq_ce_locations_src_id       UNIQUE      (location_src_id)
);

COMMENT ON TABLE  bl_3nf.ce_locations                    IS 'SCD Type 1 - Unified address table shared by customers, employees, and stores. NK = COALESCE(TRIM(address),''n/a'') || ''_'' || COALESCE(TRIM(postal_code),''n/a''). City and state are determined by postal_code.';
COMMENT ON COLUMN bl_3nf.ce_locations.location_id        IS 'Surrogate PK - generated by bl_3nf.seq_ce_locations.';
COMMENT ON COLUMN bl_3nf.ce_locations.location_src_id    IS 'Natural key - composite from address + postal_code. COALESCE to n/a for NULLs.';
COMMENT ON COLUMN bl_3nf.ce_locations.location_address   IS 'Street address. n/a for ecom store records.';
COMMENT ON COLUMN bl_3nf.ce_locations.location_postal_code IS 'Postal code - determinant of city and state.';
COMMENT ON COLUMN bl_3nf.ce_locations.location_city      IS 'City - determined by postal code.';
COMMENT ON COLUMN bl_3nf.ce_locations.location_state     IS 'State code (2 chars) - determined by postal code.';
COMMENT ON COLUMN bl_3nf.ce_locations.ta_insert_dt       IS 'Technical: row creation date.';
COMMENT ON COLUMN bl_3nf.ce_locations.ta_update_dt       IS 'Technical: last update date (SCD1 - overwrite on change).';
COMMENT ON COLUMN bl_3nf.ce_locations.source_system      IS 'Source triplet: SA_RETAIL / SA_ECOM / MANUAL.';
COMMENT ON COLUMN bl_3nf.ce_locations.source_entity      IS 'Source triplet: SRC_RETAIL_SALES / SRC_ECOM_SALES / MANUAL.';


-- ------------------------------------------------------------
-- 3.2  CE_EMPLOYEES
--      SCD Type 1 - Employee dimension.
--      NK: EMPLOYEE_SRC_ID = employee_id (retail) / ee_id (ecom)
--      Sources: src_retail_sales.employee_id + employee_*
--               src_ecom_sales.ee_id + ee_*
--      FK: EMPLOYEE_LOCATION_ID → CE_LOCATIONS
--      NOTE: SSN excluded from all layers (sensitive data).
-- ------------------------------------------------------------
DROP TABLE IF EXISTS bl_3nf.ce_employees CASCADE;

CREATE TABLE bl_3nf.ce_employees (
    employee_id             BIGINT          NOT NULL    DEFAULT nextval('bl_3nf.seq_ce_employees'),
    employee_src_id         VARCHAR(50)     NOT NULL,
    employee_name           VARCHAR(100)    NOT NULL,
    employee_gender         CHAR(1)         NOT NULL,
    employee_email          VARCHAR(100)    NOT NULL,
    employee_phone_number   VARCHAR(30)     NOT NULL,
    employee_location_id    BIGINT          NOT NULL,
    ta_insert_dt            DATE            NOT NULL,
    ta_update_dt            DATE            NOT NULL,
    source_system           VARCHAR(50)     NOT NULL,
    source_entity           VARCHAR(50)     NOT NULL,
    CONSTRAINT pk_ce_employees                  PRIMARY KEY (employee_id),
    CONSTRAINT uq_ce_employees_src_id           UNIQUE      (employee_src_id),
    CONSTRAINT fk_ce_employees_location         FOREIGN KEY (employee_location_id)
                                                REFERENCES  bl_3nf.ce_locations (location_id)
);

COMMENT ON TABLE  bl_3nf.ce_employees                        IS 'SCD Type 1 - Employee dimension. Unified from retail (employee_id) and ecom (ee_id). SSN excluded (sensitive). Address stored via FK to CE_LOCATIONS.';
COMMENT ON COLUMN bl_3nf.ce_employees.employee_id            IS 'Surrogate PK - generated by bl_3nf.seq_ce_employees.';
COMMENT ON COLUMN bl_3nf.ce_employees.employee_src_id        IS 'Natural key - employee_id (SA_RETAIL) / ee_id (SA_ECOM).';
COMMENT ON COLUMN bl_3nf.ce_employees.employee_name          IS 'Full name. COALESCE to n/a if NULL in source.';
COMMENT ON COLUMN bl_3nf.ce_employees.employee_gender        IS 'M / F. COALESCE to n if NULL in source.';
COMMENT ON COLUMN bl_3nf.ce_employees.employee_email         IS 'Work email address. COALESCE to n/a if NULL in source.';
COMMENT ON COLUMN bl_3nf.ce_employees.employee_phone_number  IS 'Contact phone number. COALESCE to n/a if NULL in source.';
COMMENT ON COLUMN bl_3nf.ce_employees.employee_location_id   IS 'FK → CE_LOCATIONS. -1 if address not available.';
COMMENT ON COLUMN bl_3nf.ce_employees.ta_insert_dt           IS 'Technical: row creation date.';
COMMENT ON COLUMN bl_3nf.ce_employees.ta_update_dt           IS 'Technical: last update date (SCD1 - overwrite on change).';
COMMENT ON COLUMN bl_3nf.ce_employees.source_system          IS 'Source triplet: SA_RETAIL / SA_ECOM / MANUAL.';
COMMENT ON COLUMN bl_3nf.ce_employees.source_entity          IS 'Source triplet: SRC_RETAIL_SALES / SRC_ECOM_SALES / MANUAL.';


-- ------------------------------------------------------------
-- 3.3  CE_STORES
--      SCD Type 1 - Store dimension.
--      NK: STORE_SRC_ID = store_code (retail) / 'ECOMMERCE' (ecom)
--      Sources: src_retail_sales.store_code + store_*
--               ecom → single constant row STORE_SRC_ID='ECOMMERCE'
--      FK: STORE_ZONE_ID     → CE_STORE_ZONES
--          STORE_LOCATION_ID → CE_LOCATIONS
-- ------------------------------------------------------------
DROP TABLE IF EXISTS bl_3nf.ce_stores CASCADE;

CREATE TABLE bl_3nf.ce_stores (
    store_id            BIGINT          NOT NULL    DEFAULT nextval('bl_3nf.seq_ce_stores'),
    store_src_id        VARCHAR(50)     NOT NULL,
    store_channel       VARCHAR(20)     NOT NULL,
    store_zone_id       BIGINT          NOT NULL,
    store_location_id   BIGINT          NOT NULL,
    ta_insert_dt        DATE            NOT NULL,
    ta_update_dt        DATE            NOT NULL,
    source_system       VARCHAR(50)     NOT NULL,
    source_entity       VARCHAR(50)     NOT NULL,
    CONSTRAINT pk_ce_stores                 PRIMARY KEY (store_id),
    CONSTRAINT uq_ce_stores_src_id          UNIQUE      (store_src_id),
    CONSTRAINT chk_ce_stores_channel        CHECK       (store_channel IN ('RETAIL', 'ECOMMERCE')),
    CONSTRAINT fk_ce_stores_zone            FOREIGN KEY (store_zone_id)
                                            REFERENCES  bl_3nf.ce_store_zones (store_zone_id),
    CONSTRAINT fk_ce_stores_location        FOREIGN KEY (store_location_id)
                                            REFERENCES  bl_3nf.ce_locations   (location_id)
);

COMMENT ON TABLE  bl_3nf.ce_stores                   IS 'SCD Type 1 - Store dimension. Retail rows use store_code as NK. Ecom has one constant row: STORE_SRC_ID=ECOMMERCE, STORE_CHANNEL=ECOMMERCE. Zone and location via FKs to CE_STORE_ZONES and CE_LOCATIONS.';
COMMENT ON COLUMN bl_3nf.ce_stores.store_id          IS 'Surrogate PK - generated by bl_3nf.seq_ce_stores.';
COMMENT ON COLUMN bl_3nf.ce_stores.store_src_id      IS 'Natural key - store_code (SA_RETAIL) / ''ECOMMERCE'' (SA_ECOM).';
COMMENT ON COLUMN bl_3nf.ce_stores.store_channel     IS 'Sales channel: RETAIL or ECOMMERCE.';
COMMENT ON COLUMN bl_3nf.ce_stores.store_zone_id     IS 'FK → CE_STORE_ZONES. -1 for ecom (no zone).';
COMMENT ON COLUMN bl_3nf.ce_stores.store_location_id IS 'FK → CE_LOCATIONS. -1 for ecom (no physical address).';
COMMENT ON COLUMN bl_3nf.ce_stores.ta_insert_dt      IS 'Technical: row creation date.';
COMMENT ON COLUMN bl_3nf.ce_stores.ta_update_dt      IS 'Technical: last update date (SCD1 - overwrite on change).';
COMMENT ON COLUMN bl_3nf.ce_stores.source_system     IS 'Source triplet: SA_RETAIL / SA_ECOM / MANUAL.';
COMMENT ON COLUMN bl_3nf.ce_stores.source_entity     IS 'Source triplet: SRC_RETAIL_SALES / SRC_ECOM_SALES / MANUAL.';


-- ============================================================
-- GROUP 4 - SCD TYPE 2: Historical dimension tables
--           Each attribute change creates a new row version.
--           COMPOSITE PK = (_ID + START_DT).
--           FK from CE_SALES to these tables: LOGICAL ONLY -
--           NO DB-level CONSTRAINT (per Naming_Conventions.docx).
--           IS_ACTIVE: Y = current version, N = expired version.
--           START_DT default: 1900-01-01
--           END_DT   default: 9999-12-31
-- ============================================================

-- ------------------------------------------------------------
-- 4.1  CE_CUSTOMERS_SCD
--      SCD Type 2 - Customer dimension with address history.
--      NK: CUSTOMER_SRC_ID = customer_id (retail) / user_id (ecom)
--      Sources: src_retail_sales.customer_id + customer_*
--               src_ecom_sales.user_id + user_*
--      Tracked attributes (SCD2): CUSTOMER_LOCATION_ID
--      FK: CUSTOMER_LOCATION_ID → CE_LOCATIONS (logical, no DB constraint)
--      PK: COMPOSITE (CUSTOMER_ID + START_DT)
--      NOTE: CUSTOMER_EMAIL = 'n/a' for retail source (not in src).
--            SSN, credit card data excluded (sensitive).
-- ------------------------------------------------------------
DROP TABLE IF EXISTS bl_3nf.ce_customers_scd CASCADE;

CREATE TABLE bl_3nf.ce_customers_scd (
    customer_id             BIGINT          NOT NULL    DEFAULT nextval('bl_3nf.seq_ce_customers_scd'),
    customer_src_id         VARCHAR(50)     NOT NULL,
    customer_name           VARCHAR(100)    NOT NULL,
    customer_gender         CHAR(1)         NOT NULL,
    customer_email          VARCHAR(100)    NOT NULL,
    customer_phone_number   VARCHAR(30)     NOT NULL,
    customer_location_id    BIGINT          NOT NULL,
    start_dt                DATE            NOT NULL,
    end_dt                  DATE            NOT NULL,
    is_active               VARCHAR(1)      NOT NULL,
    ta_insert_dt            DATE            NOT NULL,
    source_system           VARCHAR(50)     NOT NULL,
    source_entity           VARCHAR(50)     NOT NULL,
    CONSTRAINT pk_ce_customers_scd          PRIMARY KEY (customer_id, start_dt),
    CONSTRAINT chk_ce_customers_scd_active  CHECK       (is_active IN ('Y', 'N'))
    --  NO FK constraint on customer_location_id to CE_LOCATIONS:
    --    CE_CUSTOMERS_SCD is SCD2; logical FK only per Naming_Conventions.docx.
    --    FK to CE_LOCATIONS is enforced via ETL logic (COALESCE to -1).
);

COMMENT ON TABLE  bl_3nf.ce_customers_scd                        IS 'SCD Type 2 - Customer dimension. Tracks history of address changes via CUSTOMER_LOCATION_ID. Composite PK = (CUSTOMER_ID + START_DT). FK to CE_LOCATIONS is LOGICAL ONLY (no DB constraint). CUSTOMER_EMAIL = n/a for retail source. SSN and credit card data excluded.';
COMMENT ON COLUMN bl_3nf.ce_customers_scd.customer_id            IS 'Surrogate PK (part 1 of 2) - generated by bl_3nf.seq_ce_customers_scd. New value assigned on each new SCD2 version.';
COMMENT ON COLUMN bl_3nf.ce_customers_scd.customer_src_id        IS 'Natural key - customer_id (SA_RETAIL) / user_id (SA_ECOM).';
COMMENT ON COLUMN bl_3nf.ce_customers_scd.customer_name          IS 'Full name. COALESCE to n/a if NULL.';
COMMENT ON COLUMN bl_3nf.ce_customers_scd.customer_gender        IS 'M / F. COALESCE to n if NULL.';
COMMENT ON COLUMN bl_3nf.ce_customers_scd.customer_email         IS 'Email address. n/a for retail source (field absent in raw data).';
COMMENT ON COLUMN bl_3nf.ce_customers_scd.customer_phone_number  IS 'Contact phone number. COALESCE to n/a if NULL.';
COMMENT ON COLUMN bl_3nf.ce_customers_scd.customer_location_id   IS 'Logical FK → CE_LOCATIONS (no DB constraint). -1 if address not available. SCD2 tracked attribute.';
COMMENT ON COLUMN bl_3nf.ce_customers_scd.start_dt               IS 'SCD2 period start. PK component (part 2 of 2). Default: 1900-01-01. _DT postfix per naming convention.';
COMMENT ON COLUMN bl_3nf.ce_customers_scd.end_dt                 IS 'SCD2 period end. Default: 9999-12-31. Set to CURRENT_DATE-1 when row is expired. _DT postfix.';
COMMENT ON COLUMN bl_3nf.ce_customers_scd.is_active              IS 'Y = current active version, N = expired historical version.';
COMMENT ON COLUMN bl_3nf.ce_customers_scd.ta_insert_dt           IS 'Technical: row creation date. No TA_UPDATE_DT in SCD2 (new row inserted on change, not updated).';
COMMENT ON COLUMN bl_3nf.ce_customers_scd.source_system          IS 'Source triplet: SA_RETAIL / SA_ECOM / MANUAL.';
COMMENT ON COLUMN bl_3nf.ce_customers_scd.source_entity          IS 'Source triplet: SRC_RETAIL_SALES / SRC_ECOM_SALES / MANUAL.';


-- ------------------------------------------------------------
-- 4.2  CE_PRODUCTS_SCD
--      SCD Type 2 - Product dimension with price/attribute history.
--      NK: PRODUCT_SRC_ID = product_code (both sources)
--      Sources: src_retail_sales.product_code + product attributes
--               src_ecom_sales.product_code + ecom product attrs
--      Tracked attributes (SCD2):
--        PRODUCT_MIN_AMOUNT (catalog price changes)
--        PRODUCT_COLOUR     (colour variant changes)
--        PRODUCT_SIZE       (size variant changes)
--        PRODUCT_DESCRIPTION (description changes)
--      FK: PRODUCT_SUBCATEGORY_ID → CE_PRODUCT_SUBCATEGORIES
--      PK: COMPOSITE (PRODUCT_ID + START_DT)
--      NOTE: Ecom has no colour/size/description/min_amount/top_category.
--            → PRODUCT_COLOUR = 'NOT-CAPTURED'
--            → PRODUCT_SIZE   = 'NOT-CAPTURED'
--            → PRODUCT_DESCRIPTION = 'NOT-CAPTURED'
--            → PRODUCT_MIN_AMOUNT  = NULL  (KPI - nullable allowed)
--            PRODUCT_COST moved to CE_SALES as KPI
--            (per Business_Template.docx §2.3.11).
-- ------------------------------------------------------------
DROP TABLE IF EXISTS bl_3nf.ce_products_scd CASCADE;

CREATE TABLE bl_3nf.ce_products_scd (
    product_id                  BIGINT          NOT NULL    DEFAULT nextval('bl_3nf.seq_ce_products_scd'),
    product_src_id              VARCHAR(50)     NOT NULL,
    product_subcategory_id      BIGINT          NOT NULL,
    product_description         VARCHAR(200)    NOT NULL,
    product_colour              VARCHAR(50)     NOT NULL,
    product_size                VARCHAR(20)     NOT NULL,
    product_min_amount          DECIMAL(12,2),
    start_dt                    DATE            NOT NULL,
    end_dt                      DATE            NOT NULL,
    is_active                   VARCHAR(1)      NOT NULL,
    ta_insert_dt                DATE            NOT NULL,
    source_system               VARCHAR(50)     NOT NULL,
    source_entity               VARCHAR(50)     NOT NULL,
    CONSTRAINT pk_ce_products_scd               PRIMARY KEY (product_id, start_dt),
    CONSTRAINT chk_ce_products_scd_active       CHECK       (is_active IN ('Y', 'N')),
    CONSTRAINT fk_ce_products_scd_subcategory   FOREIGN KEY (product_subcategory_id)
                                                REFERENCES  bl_3nf.ce_product_subcategories (product_subcategory_id)
);

COMMENT ON TABLE  bl_3nf.ce_products_scd                         IS 'SCD Type 2 - Product dimension. Tracks history of: PRODUCT_MIN_AMOUNT, PRODUCT_COLOUR, PRODUCT_SIZE, PRODUCT_DESCRIPTION. Composite PK = (PRODUCT_ID + START_DT). PRODUCT_COST is a KPI stored in CE_SALES (not here). Ecom: colour/size/description = NOT-CAPTURED, min_amount = NULL.';
COMMENT ON COLUMN bl_3nf.ce_products_scd.product_id              IS 'Surrogate PK (part 1 of 2) - generated by bl_3nf.seq_ce_products_scd. New value on each SCD2 version.';
COMMENT ON COLUMN bl_3nf.ce_products_scd.product_src_id          IS 'Natural key - product_code from both SA_RETAIL and SA_ECOM.';
COMMENT ON COLUMN bl_3nf.ce_products_scd.product_subcategory_id  IS 'FK → CE_PRODUCT_SUBCATEGORIES. -1 for default/unknown records.';
COMMENT ON COLUMN bl_3nf.ce_products_scd.product_description     IS 'Product description. NOT-CAPTURED for ecom (no equivalent field).';
COMMENT ON COLUMN bl_3nf.ce_products_scd.product_colour          IS 'Product colour variant. NOT-CAPTURED for ecom.';
COMMENT ON COLUMN bl_3nf.ce_products_scd.product_size            IS 'Product size variant. NOT-CAPTURED for ecom.';
COMMENT ON COLUMN bl_3nf.ce_products_scd.product_min_amount      IS 'KPI - minimum/catalog price. NULL allowed (ecom has no catalog price). SCD2 tracked: price changes create new version.';
COMMENT ON COLUMN bl_3nf.ce_products_scd.start_dt                IS 'SCD2 period start. PK component (part 2 of 2). Default: 1900-01-01.';
COMMENT ON COLUMN bl_3nf.ce_products_scd.end_dt                  IS 'SCD2 period end. Default: 9999-12-31. Set to CURRENT_DATE-1 on expiry.';
COMMENT ON COLUMN bl_3nf.ce_products_scd.is_active               IS 'Y = current active version, N = expired historical version.';
COMMENT ON COLUMN bl_3nf.ce_products_scd.ta_insert_dt            IS 'Technical: row creation date. No TA_UPDATE_DT (SCD2 - new row on change).';
COMMENT ON COLUMN bl_3nf.ce_products_scd.source_system           IS 'Source triplet: SA_RETAIL / SA_ECOM / MANUAL.';
COMMENT ON COLUMN bl_3nf.ce_products_scd.source_entity           IS 'Source triplet: SRC_RETAIL_SALES / SRC_ECOM_SALES / MANUAL.';


-- ============================================================
-- GROUP 5 - FACT TABLE: CE_SALES
--           Append-only incremental load (no SCD).
--           Named CE_SALES (CE_ prefix on 3NF layer,
--           per Naming_Conventions.docx §Facts rule).
--           NO default row (fact tables excluded from default
--           row policy per Default-value.pptx slide 3/9).
--
--           FK RULES:
--           • Hard FK enforced to SCD Type 0/1 dimensions:
--             CE_DATES, CE_EMPLOYEES, CE_STORES, CE_PAYMENT_TYPES
--           • LOGICAL FK ONLY (no DB constraint) to SCD Type 2:
--             CE_CUSTOMERS_SCD, CE_PRODUCTS_SCD
--             (per Naming_Conventions.docx §Facts rule 2:
--              "Creation of DB constraint references for SCD2
--               tables on 3NF layer are strongly PROHIBITED.")
--
--           KPI COLUMNS (nullable by design):
--             SALES_AMOUNT, DISCOUNT, COST, QUANTITY
-- ============================================================

-- ------------------------------------------------------------
-- 5.1  CE_SALES
--      Fact table - one row per product line item per transaction.
--      NK (grain key): SALE_SRC_ID + SOURCE_SYSTEM
--        = bill_id (retail) / payment_id (ecom) + source system
--      Sources: src_retail_sales (bill_id, line_item_amount, …)
--               src_ecom_sales   (payment_id, sales_amount, …)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS bl_3nf.ce_sales CASCADE;

CREATE TABLE bl_3nf.ce_sales (
    sale_id             BIGINT          NOT NULL    DEFAULT nextval('bl_3nf.seq_ce_sales'),
    sale_src_id         VARCHAR(50)     NOT NULL,
    date_id             BIGINT          NOT NULL,
    customer_id         BIGINT          NOT NULL,
    employee_id         BIGINT          NOT NULL,
    product_id          BIGINT          NOT NULL,
    store_id            BIGINT          NOT NULL,
    payment_type_id     BIGINT          NOT NULL,
    sales_amount        DECIMAL(12,2),
    discount            DECIMAL(12,2),
    cost                DECIMAL(12,2),
    quantity            INTEGER,
    ta_insert_dt        DATE            NOT NULL,
    ta_update_dt        DATE            NOT NULL,
    source_system       VARCHAR(50)     NOT NULL,
    source_entity       VARCHAR(50)     NOT NULL,
    CONSTRAINT pk_ce_sales                  PRIMARY KEY (sale_id),
    CONSTRAINT uq_ce_sales_src              UNIQUE      (sale_src_id, source_system, product_id),
    -- Hard FK constraints to SCD Type 0 / 1 dimensions only:
    CONSTRAINT fk_ce_sales_date             FOREIGN KEY (date_id)
                                            REFERENCES  bl_3nf.ce_dates         (date_id),
    CONSTRAINT fk_ce_sales_employee         FOREIGN KEY (employee_id)
                                            REFERENCES  bl_3nf.ce_employees      (employee_id),
    CONSTRAINT fk_ce_sales_store            FOREIGN KEY (store_id)
                                            REFERENCES  bl_3nf.ce_stores         (store_id),
    CONSTRAINT fk_ce_sales_payment_type     FOREIGN KEY (payment_type_id)
                                            REFERENCES  bl_3nf.ce_payment_types  (payment_type_id)
    --  NO FK constraint to CE_CUSTOMERS_SCD (customer_id):
    --    SCD2 table has composite PK. DB-level FK PROHIBITED
    --    per Naming_Conventions.docx §Facts rule 2.
    --  NO FK constraint to CE_PRODUCTS_SCD (product_id):
    --    Same reason as above. Logical FK only.
);

COMMENT ON TABLE  bl_3nf.ce_sales                  IS 'Fact table - 3NF layer. One row per product line item per sales transaction (grain). Append-only incremental load. No default row. Hard FKs to SCD0/1 dims; LOGICAL FK only to SCD2 dims (CE_CUSTOMERS_SCD, CE_PRODUCTS_SCD) - no DB constraint per naming convention.';
COMMENT ON COLUMN bl_3nf.ce_sales.sale_id          IS 'Surrogate PK - generated by bl_3nf.seq_ce_sales.';
COMMENT ON COLUMN bl_3nf.ce_sales.sale_src_id      IS 'Natural key - bill_id (SA_RETAIL) / payment_id (SA_ECOM). Unique per source_system.';
COMMENT ON COLUMN bl_3nf.ce_sales.date_id          IS 'FK → CE_DATES. Transaction date surrogate key.';
COMMENT ON COLUMN bl_3nf.ce_sales.customer_id      IS 'Logical FK → CE_CUSTOMERS_SCD (no DB constraint). COALESCE to -1 if lookup fails. References current or historical version per transaction date.';
COMMENT ON COLUMN bl_3nf.ce_sales.employee_id      IS 'FK → CE_EMPLOYEES. -1 via COALESCE if employee unknown.';
COMMENT ON COLUMN bl_3nf.ce_sales.product_id       IS 'Logical FK → CE_PRODUCTS_SCD (no DB constraint). COALESCE to -1 if lookup fails. References version valid at transaction date.';
COMMENT ON COLUMN bl_3nf.ce_sales.store_id         IS 'FK → CE_STORES. -1 via COALESCE for unresolved stores.';
COMMENT ON COLUMN bl_3nf.ce_sales.payment_type_id  IS 'FK → CE_PAYMENT_TYPES. -1 via COALESCE if unknown.';
COMMENT ON COLUMN bl_3nf.ce_sales.sales_amount     IS 'KPI - Gross sales value. line_item_amount (retail) / sales_amount (ecom). NULL allowed.';
COMMENT ON COLUMN bl_3nf.ce_sales.discount         IS 'KPI - Discount applied. bill_discount (retail) / discount (ecom). NULL allowed.';
COMMENT ON COLUMN bl_3nf.ce_sales.cost             IS 'KPI - Product procurement cost. cost from both sources. NULL for ecom (cost ≈ 1.0 is a coefficient, not monetary value). NULL allowed.';
COMMENT ON COLUMN bl_3nf.ce_sales.quantity         IS 'KPI - Units sold. quantity_sold (retail) / quantity (ecom). NULL allowed.';
COMMENT ON COLUMN bl_3nf.ce_sales.ta_insert_dt     IS 'Technical: row creation date.';
COMMENT ON COLUMN bl_3nf.ce_sales.ta_update_dt     IS 'Technical: last update date.';
COMMENT ON COLUMN bl_3nf.ce_sales.source_system    IS 'Source triplet: SA_RETAIL / SA_ECOM.';
COMMENT ON COLUMN bl_3nf.ce_sales.source_entity    IS 'Source triplet: SRC_RETAIL_SALES / SRC_ECOM_SALES.';


-- ============================================================
-- VERIFICATION - Check all 12 tables were created successfully
-- ============================================================

DO $$
DECLARE
    v_count     INTEGER;
    v_expected  INTEGER := 12;
BEGIN
    SELECT COUNT(*)
    INTO   v_count
    FROM   information_schema.tables
    WHERE  table_schema = 'bl_3nf'
      AND  table_type   = 'BASE TABLE';

    RAISE NOTICE '==============================================';
    RAISE NOTICE 'BL_3NF tables created: % / % expected.', v_count, v_expected;
    RAISE NOTICE '==============================================';

    IF v_count < v_expected THEN
        RAISE WARNING
            'Expected % tables in bl_3nf, found %. '
            'Check for creation errors above.',
            v_expected, v_count;
    ELSE
        RAISE NOTICE 'All % BL_3NF tables present. DDL completed successfully.', v_count;
    END IF;
END;
$$;