INSERT INTO `quarantine.invalid_records` (table_name, record_key, error_reason, rejected_payload, rejected_at)
SELECT DISTINCT -- DISTINCT: eventos idénticos en Bronze generan un solo rechazo
  'customers' AS table_name,
  b.document_id AS record_key,
  CASE
    WHEN TRIM(JSON_VALUE(b.data.fields.name.stringValue)) IS NULL OR TRIM(JSON_VALUE(b.data.fields.name.stringValue)) = "" THEN "El nombre está vacío o es nulo"
    WHEN LOWER(TRIM(JSON_VALUE(b.data.fields.email.stringValue))) NOT LIKE '%@%.%' THEN "Formato de correo electrónico inválido"
    WHEN TIMESTAMP(JSON_VALUE(b.data.fields.signup_date.timestampValue)) > CURRENT_TIMESTAMP() THEN "Fecha de registro inconsistente (en el futuro)"
  END AS error_reason,
  TO_JSON_STRING(b.data) AS rejected_payload,
  CURRENT_TIMESTAMP() AS rejected_at
FROM
  `bronze.firestore_customers_raw` b
WHERE
  -- Identifica registros de Bronze que violan CUALQUIERA de las tres reglas básicas
  (
    (TRIM(JSON_VALUE(b.data.fields.name.stringValue)) IS NULL OR TRIM(JSON_VALUE(b.data.fields.name.stringValue)) = "") OR
    (LOWER(TRIM(JSON_VALUE(b.data.fields.email.stringValue))) NOT LIKE '%@%.%') OR
    (TIMESTAMP(JSON_VALUE(b.data.fields.signup_date.timestampValue)) > CURRENT_TIMESTAMP())
  )
  -- Evita re-insertar el mismo rechazo si la auditoría se ejecuta varias veces (idempotencia)
  AND NOT EXISTS (
    SELECT 1 FROM `quarantine.invalid_records` q
    WHERE q.table_name = 'customers'
      AND q.record_key = b.document_id
      AND q.rejected_payload = TO_JSON_STRING(b.data)
  );
