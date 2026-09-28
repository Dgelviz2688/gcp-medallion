CREATE OR REPLACE TABLE `silver.customers` 
OPTIONS(
  description="Tabla de clientes limpia, tipada y estructurada desde Firestore"
) AS
SELECT
  document_id AS customer_id,
  TRIM(JSON_VALUE(data.fields.name.stringValue)) AS name,
  LOWER(TRIM(JSON_VALUE(data.fields.email.stringValue))) AS email,
  CAST(JSON_VALUE(data.fields.active.booleanValue) AS BOOL) AS is_active,
  TIMESTAMP(JSON_VALUE(data.fields.signup_date.timestampValue)) AS signup_date,
  event_timestamp AS ingestion_timestamp
FROM
  `bronze.firestore_customers_raw`;