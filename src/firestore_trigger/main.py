import os
import json
from cloudevents.http import CloudEvent
import functions_framework
from google.events.cloud import firestore as firestore_events
from google.protobuf.json_format import MessageToDict
from google.cloud import bigquery

# Inicializar clientes
bq_client = bigquery.Client()

# Capturar configuración de variables de entorno
DATASET_ID = os.environ.get("DATASET_ID", "bronze")
TABLE_ID = os.environ.get("TABLE_ID", "firestore_customers_raw")

@functions_framework.cloud_event
def sync_firestore_to_bq(cloud_event: CloudEvent) -> None:
    """
    Función que reacciona a eventos de Firestore, procesa el payload
    y lo almacena como registro crudo en formato JSON en BigQuery (Bronze).
    """
    try:
        # 1. Obtener metadatos básicos del evento
        event_subject = cloud_event.get("subject", "unknown")
        # El subject tiene el formato: documents/customers/CUSTOMER_ID
        document_id = event_subject.split("/")[-1] if "/" in event_subject else "unknown"
        event_type = cloud_event.get("type", "unknown")
        event_timestamp = cloud_event.get("time", None)

        print(f"Evento recibido de Firestore. Doc ID: {document_id} | Tipo: {event_type}")

        # 2. Deserializar el payload binario Protobuf de Firestore
        firestore_payload = firestore_events.DocumentEventData()
        firestore_payload._pb.ParseFromString(cloud_event.data)

        # 3. Extraer el valor del documento (nuevo estado tras la escritura)
        new_data = {}
        if firestore_payload.value:
            # Convierte el formato binario a un diccionario limpio de Python
            new_data = MessageToDict(firestore_payload.value._pb)

        # 4. Construir el registro para la capa Bronze de BigQuery
        # Almacenamos el JSON crudo para mantener el estado original en Bronze (Schema-on-Read)
        record = {
            "document_id": document_id,
            "event_type": event_type,
            "event_timestamp": event_timestamp,
            "data": json.dumps(new_data) # BigQuery lo interpretará como tipo JSON natively
        }

        # 5. Insertar el registro (Streaming Insert) en la tabla raw
        table_ref = bq_client.dataset(DATASET_ID).table(TABLE_ID)
        errors = bq_client.insert_rows_json(table_ref, [record])

        if errors:
            print(f"Errores al insertar en BigQuery: {errors}")
            raise RuntimeError(f"Error de inserción en BQ: {errors}")

        print(f"Sincronización exitosa en BigQuery para el documento: {document_id}")

    except Exception as e:
        print(f"Fallo crítico en la sincronización: {str(e)}")
        # Propagamos el error para que Eventarc/PubSub pueda reintentar la entrega si es necesario
        raise e