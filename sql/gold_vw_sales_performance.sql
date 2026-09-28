CREATE OR REPLACE VIEW `gold.vw_sales_performance` AS
SELECT
  f.order_id,
  f.product_id,
  f.amount,
  f.order_date,
  c.customer_name,
  c.customer_email
FROM
  `gold.fact_sales` f
INNER JOIN
  `gold.dim_customers` c ON f.customer_key = c.customer_key;