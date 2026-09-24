import os
from cloudevents.http import CloudEvent
import functions_framework
from google.cloud import bigquery

# Inicializar cliente de BigQuery
bq_client = bigquery.Client()

DATASET_ID = os.environ.get("DATASET_ID", "bronze")
TABLE_ID = os.environ.get("TABLE_ID", "orders_raw")

@functions_framework.cloud_event
def ingest_gcs_to_bq(cloud_event: CloudEvent) -> None:
    """
    Función de GCS Event Trigger que detecta la subida de archivos CSV
    de órdenes de compra y lanza de forma nativa un BigQuery Load Job.
    """
    try:
        # 1. Obtener detalles del archivo desde el evento de Storage
        data = cloud_event.data
        bucket_name = data.get("bucket")
        file_name = data.get("name")
        content_type = data.get("contentType")

        print(f"Detectado nuevo archivo en GCS: gs://{bucket_name}/{file_name} ({content_type})")

        # 2. Filtrar para procesar únicamente CSVs colocados en la ruta de órdenes
        # Ruta esperada: batch_uploads/orders/archivo.csv
        if not file_name.startswith("batch_uploads/orders/") or not file_name.endswith(".csv"):
            print("El archivo no coincide con la ruta u extensión esperada. Omitiendo procesamiento.")
            return

        print(f"Iniciando flujo de ingesta por lote para: {file_name}")

        # 3. Construir URIs y referencias de destino
        gcs_uri = f"gs://{bucket_name}/{file_name}"
        table_ref = bq_client.dataset(DATASET_ID).table(TABLE_ID)

        # 4. Configurar el BigQuery Load Job
        # Esto delega la carga masiva y computación de parseo directamente a BigQuery sin consumir CPU local
        job_config = bigquery.LoadJobConfig(
            source_format=bigquery.SourceFormat.CSV,
            skip_leading_rows=1,      # Salta la cabecera (Header row) del CSV
            autodetect=False,         # Desactivado para forzar que respete el esquema que definiremos en Terraform
            write_disposition=bigquery.WriteDisposition.WRITE_APPEND, # Anexa datos históricos
        )

        # 5. Lanzar el Job asíncronamente
        load_job = bq_client.load_table_from_uri(
            gcs_uri,
            table_ref,
            job_config=job_config
        )

        print(f"Job de carga en BigQuery iniciado con ID: {load_job.job_id}")
        
        # Bloquea temporalmente para esperar de forma síncrona el resultado de la carga masiva
        load_job.result()  

        print(f"Carga por lote completada con éxito. Datos importados en {DATASET_ID}.{TABLE_ID}")

    except Exception as e:
        print(f"Fallo durante el proceso de carga masiva: {str(e)}")
        raise e