bq query --use_legacy_sql=false < sql/gold_sp_run_medallion_pipeline.sql

gcloud workflows run medallion-orchestrator --location=us-central1


