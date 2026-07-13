-- Sprawdź EXT tables (czyta bezpośrednio z CSV):
SELECT * FROM sa_retail.ext_retail_sales LIMIT 10;
SELECT * FROM sa_ecom.ext_ecom_sales LIMIT 10;

-- Sprawdź SRC tables (dane po deduplicacji):
SELECT * FROM sa_retail.src_retail_sales LIMIT 10;
SELECT * FROM sa_ecom.src_ecom_sales LIMIT 10;

-- Sprawdź czy deduplicacja zadziałała:
SELECT COUNT(*) AS total_ext FROM sa_retail.ext_retail_sales;
SELECT COUNT(*) AS total_src FROM sa_retail.src_retail_sales;

-- Sprawdź duplikaty (wynik powinien być 0):
SELECT bill_id, product_code, COUNT(*)
FROM sa_retail.src_retail_sales
GROUP BY bill_id, product_code
HAVING COUNT(*) > 1;

SELECT payment_id, product_code, COUNT(*)
FROM sa_ecom.src_ecom_sales
GROUP BY payment_id, product_code
HAVING COUNT(*) > 1;-- Sprawdź EXT tables (czyta bezpośrednio z CSV):
SELECT * FROM sa_retail.ext_retail_sales LIMIT 10;
SELECT * FROM sa_ecom.ext_ecom_sales LIMIT 10;

-- Sprawdź SRC tables (dane po deduplicacji):
SELECT * FROM sa_retail.src_retail_sales LIMIT 10;
SELECT * FROM sa_ecom.src_ecom_sales LIMIT 10;

-- Sprawdź czy deduplicacja zadziałała:
SELECT COUNT(*) AS total_ext FROM sa_retail.ext_retail_sales;
SELECT COUNT(*) AS total_src FROM sa_retail.src_retail_sales;

-- Sprawdź duplikaty (wynik powinien być 0):
SELECT bill_id, product_code, COUNT(*)
FROM sa_retail.src_retail_sales
GROUP BY bill_id, product_code
HAVING COUNT(*) > 1;

SELECT payment_id, product_code, COUNT(*)
FROM sa_ecom.src_ecom_sales
GROUP BY payment_id, product_code
HAVING COUNT(*) > 1;