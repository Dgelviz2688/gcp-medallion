# lab03
curl -X PATCH \
  "https://firestore.googleapis.com/v1/projects/gcp-medallion-509321/databases/(default)/documents/customers/cust-1001" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "fields": {
      "name": { "stringValue": "Juan Perez" },
      "email": { "stringValue": "juan.perez@example.com" },
      "active": { "booleanValue": true },
      "signup_date": { "timestampValue": "2026-06-12T12:00:00Z" }
    }
  }'

curl -X PATCH \
  "https://firestore.googleapis.com/v1/projects/gcp-medallion-509321/databases/(default)/documents/customers/cust-1002" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "fields": {
      "name": { "stringValue": "Maria Rodriguez" },
      "email": { "stringValue": "maria.rodriguez@example.com" },
      "active": { "booleanValue": true },
      "signup_date": { "timestampValue": "2026-06-12T12:00:00Z" }
    }
  }'


gcloud storage cp orders.csv gs://gcp-medallion-509321-bronze-raw/batch_uploads/orders/orders_20260612.csv