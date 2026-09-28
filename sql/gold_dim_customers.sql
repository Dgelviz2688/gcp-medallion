CREATE OR REPLACE TABLE `gold.dim_customers`
OPTIONS(
  description="Dimensión Maestra de Clientes Activos - Capa Gold"
) AS
SELECT
  customer_id AS customer_key, -- Clave subrogada o natural para relacionamiento analítico
  customer_id,
  name AS customer_name,
  email AS customer_email,
  signup_date,
  CURRENT_TIMESTAMP() AS ingestion_timestamp
FROM
  `silver.customers`
WHERE
  is_active = true; -- Filtrado de negocio para optimizar reportes analíticos de usuarios activos