MERGE `silver.customers` T
USING (
  -- 1. Deduplicamos los eventos de Bronze quedándonos únicamente con la última mutación de cada cliente
  WITH latest_bronze_customers AS (
    SELECT
      document_id AS customer_id,
      TRIM(JSON_VALUE(data.fields.name.stringValue)) AS name,
      LOWER(TRIM(JSON_VALUE(data.fields.email.stringValue))) AS email,
      CAST(JSON_VALUE(data.fields.active.booleanValue) AS BOOL) AS is_active,
      TIMESTAMP(JSON_VALUE(data.fields.signup_date.timestampValue)) AS signup_date,
      event_timestamp AS ingestion_timestamp,
      ROW_NUMBER() OVER (
        PARTITION BY document_id 
        ORDER BY event_timestamp DESC
      ) as rn
    FROM
      `bronze.firestore_customers_raw`
  )
  SELECT * EXCEPT(rn) FROM latest_bronze_customers 
    WHERE rn = 1
    -- Filtros de Calidad de Datos (Ignora corruptos)
    AND (name IS NOT NULL AND name != "")
    AND (email LIKE '%@%.%')
    AND (signup_date <= CURRENT_TIMESTAMP())
) S
ON T.customer_id = S.customer_id

-- 2. Si el cliente ya existe y el evento entrante es más reciente, actualizamos (SCD Tipo 1)
WHEN MATCHED AND S.ingestion_timestamp > T.ingestion_timestamp THEN
  UPDATE SET
    T.name = S.name,
    T.email = S.email,
    T.is_active = S.is_active,
    T.signup_date = S.signup_date,
    T.ingestion_timestamp = S.ingestion_timestamp

-- 3. Si el cliente no existe, lo insertamos
WHEN NOT MATCHED THEN
  INSERT (customer_id, name, email, is_active, signup_date, ingestion_timestamp)
  VALUES (S.customer_id, S.name, S.email, S.is_active, S.signup_date, S.ingestion_timestamp);
