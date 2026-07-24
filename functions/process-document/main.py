import functions_framework
from google.cloud import vision
from google.cloud import translate_v2 as translate
from google.cloud import bigquery
import datetime

vision_client = vision.ImageAnnotatorClient()
translate_client = translate.Client()
bq_client = bigquery.Client()

PROJECT_ID = "cloud-cost-watchdog-502507"
DATASET_ID = "watchdog_data"
TABLE_ID = "processed_documents"

@functions_framework.cloud_event
def process_document(cloud_event):
    data = cloud_event.data
    bucket_name = data["bucket"]
    file_name = data["name"]

    print(f"Processing file: {file_name} from bucket: {bucket_name}")

    image_uri = f"gs://{bucket_name}/{file_name}"
    image = vision.Image()
    image.source.image_uri = image_uri

    response = vision_client.text_detection(image=image)
    extracted_text = response.text_annotations[0].description if response.text_annotations else ""

    if response.error.message:
        print(f"Vision API error: {response.error.message}")
        extracted_text = ""

    print(f"Extracted text: {extracted_text[:100]}...")

    detected_language = "unknown"
    translated_text = extracted_text

    if extracted_text.strip():
        detection = translate_client.detect_language(extracted_text)
        detected_language = detection["language"]

        if detected_language != "en":
            translation = translate_client.translate(extracted_text, target_language="en")
            translated_text = translation["translatedText"]

    table_ref = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"
    rows_to_insert = [{
        "file_name": file_name,
        "extracted_text": extracted_text,
        "detected_language": detected_language,
        "translated_text": translated_text,
        "processed_at": datetime.datetime.utcnow().isoformat()
    }]

    errors = bq_client.insert_rows_json(table_ref, rows_to_insert)
    if errors:
        print(f"BigQuery insert errors: {errors}")
    else:
        print(f"Successfully wrote results for {file_name} to BigQuery")

    return "OK"
