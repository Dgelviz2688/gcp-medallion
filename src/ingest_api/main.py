import os
import json
# from datetime import datetime
from datetime import datetime, timezone
import requests
from google.cloud import storage
import functions_framework

# El nombre del bucket se inyectará como variable de entorno desde Terraform
BUCKET_NAME = os.environ.get("BUCKET_NAME")
API_URL = "https://jsonplaceholder.typicode.com/users"

@functions_framework.http
def ingest_api_data(request):
    """
    Función HTTP que extrae datos de una API externa y los guarda en GCS en la capa Bronze.
    """
    try:
        # 1. Obtener datos de la API externa
        print(f"Iniciando petición GET a: {API_URL}")
        response = requests.get(API_URL, timeout=10)
        response.raise_for_status()
        data = response.json()

        # 2. Generar nombre de archivo particionado por fecha/hora de ingesta
        # now = datetime.utcnow()
        now = datetime.now(timezone.utc)
        timestamp = now.strftime("%Y%m%d_%H%M%S")
        # Estructura: users/ingested_at=YYYYMMDD/users_YYYYMMDD_HHMMSS.json
        folder_date = now.strftime("%Y%m%d")
        filename = f"users/ingested_at={folder_date}/users_{timestamp}.json"

        # 3. Inicializar el cliente de Storage y subir los datos
        storage_client = storage.Client()
        bucket = storage_client.bucket(BUCKET_NAME)
        blob = bucket.blob(filename)
        
        blob.upload_from_string(
            data=json.dumps(data, indent=2),
            content_type='application/json'
        )

        success_msg = f"Ingesta exitosa. Archivo guardado en: gs://{BUCKET_NAME}/{filename}"
        print(success_msg)
        return success_msg, 200

    except requests.exceptions.RequestException as req_err:
        error_msg = f"Error al conectar con la API: {str(req_err)}"
        print(error_msg)
        return error_msg, 500
    except Exception as e:
        error_msg = f"Error inesperado en el pipeline de ingesta: {str(e)}"
        print(error_msg)
        return error_msg, 500