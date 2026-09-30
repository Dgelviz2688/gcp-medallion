INSERT INTO `quarantine.invalid_records` (table_name, record_key, error_reason, rejected_payload, rejected_at)
SELECT DISTINCT -- DISTINCT: si el mismo CSV se cargó dos veces, se registra un solo rechazo
  'orders' AS table_name,
  o.id AS record_key,
  "Violación de Integridad Referencial: El customer_id no existe en la dimensión de clientes" AS error_reason,
  TO_JSON_STRING(STRUCT(o.customer_id, o.product_id, o.amount, o.order_date)) AS rejected_payload,
  CURRENT_TIMESTAMP() AS rejected_at
FROM
  `bronze.orders_raw` o
WHERE
  o.customer_id NOT IN (SELECT customer_id FROM `silver.customers`)
  -- Evita re-insertar la misma orden si la auditoría se ejecuta varias veces (idempotencia)
  AND NOT EXISTS (
    SELECT 1 FROM `quarantine.invalid_records` q
    WHERE q.table_name = 'orders'
      AND q.record_key = o.id
  );
