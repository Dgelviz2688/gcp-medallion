INSERT INTO `quarantine.invalid_records` (table_name, record_key, error_reason, rejected_payload, rejected_at)
SELECT
  'orders' AS table_name,
  id AS record_key,
  "Violación de Integridad Referencial: El customer_id no existe en la dimensión de clientes" AS error_reason,
  TO_JSON_STRING(STRUCT(customer_id, product_id, amount, order_date)) AS rejected_payload,
  CURRENT_TIMESTAMP() AS rejected_at
FROM
  `bronze.orders_raw`
WHERE
  customer_id NOT IN (SELECT customer_id FROM `silver.customers`);