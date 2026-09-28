CREATE OR REPLACE TABLE `silver.orders` 
OPTIONS(
  description="Tabla de pedidos de compras estandarizada y limpia"
) AS
SELECT
  UPPER(TRIM(id)) AS order_id,
  TRIM(customer_id) AS customer_id,
  UPPER(TRIM(product_id)) AS product_id,
  CAST(amount AS FLOAT64) AS amount,
  PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', TRIM(order_date)) AS order_date,
  CURRENT_TIMESTAMP() AS ingestion_timestamp
FROM
  `bronze.orders_raw`
WHERE
  amount > 0;