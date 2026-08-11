-- ============================================================
-- Creation of SA leyer schemas
-- SOURCES: retail-sample.csv -> sa_retail
--          ecom-sample.csv -> sa_ecom
-- ============================================================

CREATE SCHEMA IF NOT EXISTS sa_retail;
COMMENT ON SCHEMA sa_retail IS
    'Staging area for retail store source system (retail-sample.csv).';

CREATE SCHEMA IF NOT EXISTS sa_ecom;
COMMENT ON SCHEMA sa_ecom IS
    'Staging area for e-commerce source system (ecom-sample.csv).';