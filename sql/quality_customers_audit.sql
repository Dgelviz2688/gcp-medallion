INSERT INTO `quarantine.invalid_records` (table_name, record_key, error_reason, rejected_payload, rejected_at)
SELECT
  'customers' AS table_name,
  document_id AS record_key,
  CASE
    WHEN TRIM(JSON_VALUE(data.fields.name.stringValue)) IS NULL OR TRIM(JSON_VALUE(data.fields.name.stringValue)) = "" THEN "El nombre está vacío o es nulo"
    WHEN LOWER(TRIM(JSON_VALUE(data.fields.email.stringValue))) NOT LIKE '%@%.%' THEN "Formato de correo electrónico inválido"
    WHEN TIMESTAMP(JSON_VALUE(data.fields.signup_date.timestampValue)) > CURRENT_TIMESTAMP() THEN "Fecha de registro inconsistente (en el futuro)"
  END AS error_reason,
  TO_JSON_STRING(data) AS rejected_payload,
  CURRENT_TIMESTAMP() AS rejected_at
FROM
  `bronze.firestore_customers_raw`
WHERE
  -- Identifica registros de Bronze que violan CUALQUIERA de las tres reglas básicas
  (TRIM(JSON_VALUE(data.fields.name.stringValue)) IS NULL OR TRIM(JSON_VALUE(data.fields.name.stringValue)) = "") OR
  (LOWER(TRIM(JSON_VALUE(data.fields.email.stringValue))) NOT LIKE '%@%.%') OR
  (TIMESTAMP(JSON_VALUE(data.fields.signup_date.timestampValue)) > CURRENT_TIMESTAMP());