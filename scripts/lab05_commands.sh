bq query --use_legacy_sql=false < sql/silver_customers.sql
bq query --use_legacy_sql=false < sql/silver_orders.sql
bq show --format=prettyjson silver.customers
bq query --use_legacy_sql=false \
  'SELECT order_id, customer_id, amount, order_date FROM `silver.orders` LIMIT 5'