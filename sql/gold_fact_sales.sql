CREATE OR REPLACE TABLE `gold.fact_sales`
PARTITION BY order_date
CLUSTER BY product_id, customer_key
OPTIONS(
  description="Tabla de Hechos de Ventas. Particionada por order_date y clusterizada por producto y cliente"
) AS
SELECT
  order_id,
  customer_id AS customer_key,
  product_id,
  amount,
  order_date AS order_timestamp, -- Timestamp original de la transacción
  DATE(order_date) AS order_date, -- Campo tipo DATE obligatorio para el particionamiento
  CURRENT_TIMESTAMP() AS ingestion_timestamp
FROM
  `silver.orders`
WHERE
  -- Garantizar la consistencia referencial analítica del esquema en estrella
  customer_id IN (SELECT customer_id FROM `gold.dim_customers`);