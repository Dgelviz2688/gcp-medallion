curl -X PATCH \
  "https://firestore.googleapis.com/v1/projects/gcp-medallion-509321/databases/(default)/documents/customers/cust-1003" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "fields": {
      "name": { "stringValue": "Usuario Corrupto" },
      "email": { "stringValue": "correo_sin_formato" },
      "active": { "booleanValue": true },
      "signup_date": { "timestampValue": "2026-06-12T12:00:00Z" }
    }
  }'


echo "id,customer_id,product_id,amount,order_date
ord-999,cust-9999,prod-99,800.00,2026-06-12 15:00:00" > orders_erroneas.csv

gcloud storage cp orders_erroneas.csv gs://gcp-medallion-509321-bronze-raw/batch_uploads/orders/orders_erroneas.csv


# 1. Clientes: auditoría a cuarentena y actualización incremental en Silver
bq query --use_legacy_sql=false < sql/quality_customers_audit.sql
bq query --use_legacy_sql=false < sql/silver_customers_merge.sql

# 2. Órdenes: se validan después de cargar los clientes para evitar falsos huérfanos
bq query --use_legacy_sql=false < sql/quality_orders_audit.sql
bq query --use_legacy_sql=false < sql/silver_orders_merge.sql

bq query --use_legacy_sql=false \
  'SELECT table_name, record_key, error_reason FROM `quarantine.invalid_records` LIMIT 10'

bq query --use_legacy_sql=false \
  'SELECT customer_id, email FROM `silver.customers` WHERE customer_id = "cust-erroneo"'