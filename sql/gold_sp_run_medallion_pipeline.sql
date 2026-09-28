CREATE OR REPLACE PROCEDURE `gold.sp_run_medallion_pipeline`()
BEGIN
  -- ==========================================
  -- 1. FASE DE CALIDAD Y AUDITORÍA (CUARENTENA)
  -- ==========================================
  
  -- Auditoría de Clientes Corruptos
  INSERT INTO `quarantine.invalid_records` (table_name, record_key, error_reason, rejected_payload, rejected_at)
  SELECT
    'customers' AS table_name,
    document_id AS record_key,
    CASE
      WHEN TRIM(JSON_VALUE(data.fields.name.stringValue)) IS NULL OR TRIM(JSON_VALUE(data.fields.name.stringValue)) = "" THEN "El nombre está vacío o es nulo"
      WHEN LOWER(TRIM(JSON_VALUE(data.fields.email.stringValue))) NOT LIKE '%@%.%' THEN "Formato de correo electrónico inválido"
      WHEN TIMESTAMP(JSON_VALUE(data.fields.signup_date.timestampValue)) > CURRENT_TIMESTAMP() THEN "Fecha de registro en el futuro"
    END AS error_reason,
    TO_JSON_STRING(data) AS rejected_payload,
    CURRENT_TIMESTAMP() AS rejected_at
  FROM `bronze.firestore_customers_raw`
  WHERE
    (TRIM(JSON_VALUE(data.fields.name.stringValue)) IS NULL OR TRIM(JSON_VALUE(data.fields.name.stringValue)) = "") OR
    (LOWER(TRIM(JSON_VALUE(data.fields.email.stringValue))) NOT LIKE '%@%.%') OR
    (TIMESTAMP(JSON_VALUE(data.fields.signup_date.timestampValue)) > CURRENT_TIMESTAMP());

  -- Auditoría de Órdenes Huérfanas
  INSERT INTO `quarantine.invalid_records` (table_name, record_key, error_reason, rejected_payload, rejected_at)
  SELECT
    'orders' AS table_name,
    id AS record_key,
    "Violación de Integridad Referencial: El customer_id no existe" AS error_reason,
    TO_JSON_STRING(STRUCT(customer_id, product_id, amount, order_date)) AS rejected_payload,
    CURRENT_TIMESTAMP() AS rejected_at
  FROM `bronze.orders_raw`
  WHERE customer_id NOT IN (SELECT customer_id FROM `silver.customers`);

  -- ==========================================
  -- 2. FASE DE PROCESAMIENTO INCREMENTAL (SILVER)
  -- ==========================================

  -- Merge Incremental Clientes (SCD Tipo 1) [4]
  MERGE `silver.customers` T
  USING (
    WITH latest_bronze_customers AS (
      SELECT
        document_id AS customer_id,
        TRIM(JSON_VALUE(data.fields.name.stringValue)) AS name,
        LOWER(TRIM(JSON_VALUE(data.fields.email.stringValue))) AS email,
        CAST(JSON_VALUE(data.fields.active.booleanValue) AS BOOL) AS is_active,
        TIMESTAMP(JSON_VALUE(data.fields.signup_date.timestampValue)) AS signup_date,
        event_timestamp AS ingestion_timestamp,
        ROW_NUMBER() OVER (PARTITION BY document_id ORDER BY event_timestamp DESC) as rn
      FROM `bronze.firestore_customers_raw`
    )
    SELECT * EXCEPT(rn) FROM latest_bronze_customers 
    WHERE rn = 1
      AND (name IS NOT NULL AND name != "")
      AND (email LIKE '%@%.%')
      AND (signup_date <= CURRENT_TIMESTAMP())
  ) S
  ON T.customer_id = S.customer_id
  WHEN MATCHED AND S.ingestion_timestamp > T.ingestion_timestamp THEN
    UPDATE SET
      T.name = S.name,
      T.email = S.email,
      T.is_active = S.is_active,
      T.signup_date = S.signup_date,
      T.ingestion_timestamp = S.ingestion_timestamp
  WHEN NOT MATCHED THEN
    INSERT (customer_id, name, email, is_active, signup_date, ingestion_timestamp)
    VALUES (S.customer_id, S.name, S.email, S.is_active, S.signup_date, S.ingestion_timestamp);

  -- Merge Incremental Órdenes (De-duplicación)
  MERGE `silver.orders` T
  USING (
    WITH deduped_orders AS (
      SELECT
        UPPER(TRIM(id)) AS order_id,
        TRIM(customer_id) AS customer_id,
        UPPER(TRIM(product_id)) AS product_id,
        CAST(amount AS FLOAT64) AS amount,
        PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', TRIM(order_date)) AS order_date,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY order_date DESC) as rn
      FROM `bronze.orders_raw`
      WHERE amount > 0
    )
    SELECT * EXCEPT(rn) FROM deduped_orders 
    WHERE rn = 1
      AND customer_id IN (SELECT customer_id FROM `silver.customers`)
  ) S
  ON T.order_id = S.order_id
  WHEN NOT MATCHED THEN
    INSERT (order_id, customer_id, product_id, amount, order_date, ingestion_timestamp)
    VALUES (S.order_id, S.customer_id, S.product_id, S.amount, S.order_date, CURRENT_TIMESTAMP());

  -- ==========================================
  -- 3. FASE DE MODELADO DIMENSIONAL (GOLD) [5]
  -- ==========================================

  -- Actualizar Dimensión de Clientes Activos
  CREATE OR REPLACE TABLE `gold.dim_customers` AS
  SELECT
    customer_id AS customer_key,
    customer_id,
    name AS customer_name,
    email AS customer_email,
    signup_date,
    CURRENT_TIMESTAMP() AS ingestion_timestamp
  FROM `silver.customers`
  WHERE is_active = true;

  -- Actualizar Tabla de Hechos de Ventas
  CREATE OR REPLACE TABLE `gold.fact_sales`
  PARTITION BY order_date
  CLUSTER BY product_id, customer_key AS
  SELECT
    order_id,
    customer_id AS customer_key,
    product_id,
    amount,
    order_date AS order_timestamp,
    DATE(order_date) AS order_date,
    CURRENT_TIMESTAMP() AS ingestion_timestamp
  FROM `silver.orders`
  WHERE customer_id IN (SELECT customer_id FROM `gold.dim_customers`);

END;