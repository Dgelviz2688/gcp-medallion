bq query --use_legacy_sql=false < sql/gold_dim_customers.sql
bq query --use_legacy_sql=false < sql/gold_fact_sales.sql

bq show --format=prettyjson gold.fact_sales

bq query --use_legacy_sql=false \
  'SELECT 
     f.order_id, 
     c.customer_name, 
     f.product_id, 
     f.amount, 
     f.order_date 
   FROM `gold.fact_sales` f
   JOIN `gold.dim_customers` c ON f.customer_key = c.customer_key
   LIMIT 10'