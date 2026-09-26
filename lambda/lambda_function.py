"""
Lambda Function: process_uploaded_document
==========================================
Triggered by an S3 PutObject event whenever a file is uploaded to the
insurance-docs S3 bucket.

Actions:
  1. Read the uploaded object's metadata from the S3 event.
  2. Extract the Content-Type (from file extension via mimetypes).
  3. Insert file_name, content_type, and upload_timestamp into RDS (MySQL).
  4. Write structured log lines to CloudWatch Logs (via print / logging).
  5. [BONUS] Retrieve a secret from AWS Secrets Manager and log it.

Environment Variables (set in Lambda configuration):
  DB_HOST       – RDS endpoint
  DB_PORT       – RDS port (default 3306)
  DB_NAME       – Database name
  DB_USER       – Database username
  DB_PASSWORD   – Database password (direct env var)
  SECRET_ARN    – ARN of a bonus secret to demonstrate Secrets Manager usage
"""

import json
import logging
import mimetypes
import os
from datetime import datetime, timezone
from urllib.parse import unquote_plus

import boto3
import pymysql
from botocore.config import Config

# ─── Logger setup ─────────────────────────────────────────────────────────────
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ─── Environment ──────────────────────────────────────────────────────────────
DB_HOST     = os.environ.get('DB_HOST', '')
DB_PORT     = int(os.environ.get('DB_PORT', 3306))
DB_NAME     = os.environ.get('DB_NAME', 'insurance_docs')
DB_USER     = os.environ.get('DB_USER', 'lambda_user')
DB_PASSWORD = os.environ.get('DB_PASSWORD', '')          # DB password as env var
SECRET_ARN  = os.environ.get('SECRET_ARN', '')           # Bonus: Secrets Manager demo ARN
REGION      = os.environ.get('AWS_REGION', 'ap-south-1')


# ─── Helper: get DB connection ─────────────────────────────────────────────────
def get_db_connection():
    """Return a pymysql connection using env-configured credentials."""
    return pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        connect_timeout=10,
        cursorclass=pymysql.cursors.DictCursor,
    )


# ─── Helper: ensure table exists ──────────────────────────────────────────────
CREATE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS uploaded_documents (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    file_name        VARCHAR(500)  NOT NULL,
    content_type     VARCHAR(200)  NOT NULL,
    upload_timestamp DATETIME(3)   NOT NULL,
    s3_bucket        VARCHAR(200)  NOT NULL,
    s3_key           VARCHAR(1000) NOT NULL,
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
"""


def ensure_table(cursor):
    cursor.execute(CREATE_TABLE_SQL)


# ─── Main handler ─────────────────────────────────────────────────────────────
def lambda_handler(event, context):
    logger.info("Lambda invoked. RequestId: %s", context.aws_request_id)
    logger.info("Event: %s", json.dumps(event))

    # ── BONUS: Retrieve and log a demo secret from Secrets Manager ─────────
    # Lambda is in VPC; if no VPC endpoint for Secrets Manager, this may fail.
    # Handled gracefully – core functionality does NOT depend on this.
    if SECRET_ARN:
        try:
            # Short timeout so Lambda doesn't hang if no VPC endpoint for Secrets Manager
            _sm_config = Config(connect_timeout=3, read_timeout=3, retries={'max_attempts': 0})
            secrets_client = boto3.client('secretsmanager', region_name=REGION, config=_sm_config)
            response = secrets_client.get_secret_value(SecretId=SECRET_ARN)
            bonus_secret = json.loads(response.get('SecretString', '{}'))
            # Log only the key names – never log secret values in production!
            logger.info(
                "[BONUS] Secrets Manager secret '%s' retrieved. Keys: %s",
                SECRET_ARN.split(':')[-1], list(bonus_secret.keys())
            )
            print(f"[BONUS] Secret retrieved from Secrets Manager. Keys: {list(bonus_secret.keys())}")
        except Exception as exc:
            logger.warning(
                "[BONUS] Could not retrieve bonus secret (no VPC endpoint for Secrets Manager): %s", exc
            )
            print(f"[BONUS] Secrets Manager unavailable from VPC (no NAT/endpoint): {type(exc).__name__}")

    # ── Process each S3 record in the event ───────────────────────────────
    for record in event.get('Records', []):
        bucket         = record['s3']['bucket']['name']
        key            = unquote_plus(record['s3']['object']['key'])
        file_size      = record['s3']['object'].get('size', 0)
        event_time_str = record.get('eventTime', datetime.now(timezone.utc).isoformat())

        logger.info("Processing s3://%s/%s (size: %d bytes)", bucket, key, file_size)

        # 1. Extract file name and Content-Type from key (no S3 API call needed)
        file_name    = key.split('/')[-1]   # e.g. "1717400000000-my_doc.pdf"
        content_type, _ = mimetypes.guess_type(file_name)
        if not content_type:
            content_type = 'application/octet-stream'

        # 2. Parse upload timestamp from event (reliable, no S3 API call)
        try:
            dt = datetime.fromisoformat(event_time_str.replace('Z', '+00:00'))
        except Exception:
            dt = datetime.now(timezone.utc)
        upload_timestamp = dt.strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]

        logger.info(
            "File metadata – Name: %s | ContentType: %s | Timestamp: %s | Size: %d bytes",
            file_name, content_type, upload_timestamp, file_size,
        )
        print(
            f"[FILE] name={file_name} content_type={content_type} "
            f"timestamp={upload_timestamp} size={file_size} bucket={bucket} key={key}"
        )

        # 3. Insert into RDS (Lambda connects to RDS within VPC)
        if not DB_HOST or not DB_PASSWORD:
            logger.error("DB_HOST or DB_PASSWORD not configured. Skipping DB insert.")
            continue

        connection = None
        try:
            connection = get_db_connection()
            with connection.cursor() as cursor:
                ensure_table(cursor)
                insert_sql = """
                    INSERT INTO uploaded_documents
                        (file_name, content_type, upload_timestamp, s3_bucket, s3_key)
                    VALUES (%s, %s, %s, %s, %s)
                """
                cursor.execute(insert_sql, (file_name, content_type, upload_timestamp, bucket, key))
                inserted_id = cursor.lastrowid
            connection.commit()
            logger.info(
                "DB record inserted successfully. id=%d | file=%s | type=%s | ts=%s",
                inserted_id, file_name, content_type, upload_timestamp,
            )
            print(
                f"[DB INSERT] SUCCESS id={inserted_id} file_name={file_name} "
                f"content_type={content_type} upload_timestamp={upload_timestamp} "
                f"s3_key={key}"
            )
        except Exception as exc:
            logger.error("DB insert failed: %s", exc)
            raise
        finally:
            if connection:
                connection.close()

    logger.info("Lambda execution complete.")
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Processing complete'}),
    }
