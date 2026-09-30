
bq query --use_legacy_sql=false \
  'SELECT customer_id, name, email, is_active FROM `silver.customers` WHERE customer_id = "cust-1001"'

bq query --use_legacy_sql=false \
  'SELECT customer_id, name, email, is_active FROM `silver.customers` WHERE customer_id = "cust-1002"'

curl -X PATCH \
  "https://firestore.googleapis.com/v1/projects/gcp-medallion-509321/databases/(default)/documents/customers/cust-1001" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "fields": {
      "name": { "stringValue": "Juan Perez" },
      "email": { "stringValue": "juan.perez.nuevo@example.com" },
      "active": { "booleanValue": false },
      "signup_date": { "timestampValue": "2026-06-12T12:00:00Z" }
    }
  }'

bq query --use_legacy_sql=false \
  'SELECT document_id, event_timestamp, JSON_VALUE(data.fields.email.stringValue) as email FROM `bronze.firestore_customers_raw` WHERE document_id = "cust-1001"'

bq query --use_legacy_sql=false < sql/silver_customers_merge.sql

bq query --use_legacy_sql=false \
  'SELECT customer_id, name, email, is_active FROM `silver.customers` WHERE customer_id = "cust-1001"'
