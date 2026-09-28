MERGE `silver.orders` T
USING (
  -- Deduplicamos compras de Bronze con el ID por si se subió el mismo archivo dos veces
  WITH deduped_orders AS (
    SELECT
      UPPER(TRIM(id)) AS order_id,
      TRIM(customer_id) AS customer_id,
      UPPER(TRIM(product_id)) AS product_id,
      CAST(amount AS FLOAT64) AS amount,
      PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', TRIM(order_date)) AS order_date,
      ROW_NUMBER() OVER (
        PARTITION BY id 
        ORDER BY order_date DESC
      ) as rn
    FROM
      `bronze.orders_raw`
    WHERE
      amount > 0
  )
SELECT * EXCEPT(rn) FROM deduped_orders 
    WHERE rn = 1
    AND customer_id IN (SELECT customer_id FROM `silver.customers`)
) S
ON T.order_id = S.order_id

-- Si la orden no existe, la registramos. Si ya existe, la ignoramos (ya que es inmutable)
WHEN NOT MATCHED THEN
  INSERT (order_id, customer_id, product_id, amount, order_date, ingestion_timestamp)
  VALUES (S.order_id, S.customer_id, S.product_id, S.amount, S.order_date, CURRENT_TIMESTAMP());