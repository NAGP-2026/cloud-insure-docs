"""
Lambda Function: process_uploaded_document
==========================================
Triggered by an S3 PutObject event whenever a file is uploaded to the
insurance-docs S3 bucket.

Actions:
  1. Read the uploaded object's metadata from the S3 event.
  2. Extract the Content-Type.
  3. Insert file_name, content_type, and upload_timestamp into RDS (MySQL).
  4. Write structured log lines to CloudWatch Logs (via print / logging).
  5. [BONUS] Retrieve a secret from AWS Secrets Manager and log it.

Environment Variables (set in Lambda configuration):
  DB_HOST       – RDS endpoint
  DB_PORT       – RDS port (default 3306)
  DB_NAME       – Database name
  DB_USER       – Database username
  DB_SECRET_ARN – ARN of the Secrets Manager secret that holds the DB password
  SECRET_ARN    – ARN of a bonus secret to demonstrate Secrets Manager usage
"""

import json
import logging
import os
from datetime import datetime, timezone
from urllib.parse import unquote_plus

import boto3
import pymysql

# ─── Logger setup ─────────────────────────────────────────────────────────────
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ─── AWS clients (reused across warm invocations) ─────────────────────────────
s3_client      = boto3.client('s3')
secrets_client = boto3.client('secretsmanager')

# ─── Environment ──────────────────────────────────────────────────────────────
DB_HOST       = os.environ.get('DB_HOST', '')
DB_PORT       = int(os.environ.get('DB_PORT', 3306))
DB_NAME       = os.environ.get('DB_NAME', 'insurance_docs')
DB_USER       = os.environ.get('DB_USER', 'lambda_user')
DB_SECRET_ARN = os.environ.get('DB_SECRET_ARN', '')   # Secrets Manager ARN for DB password
SECRET_ARN    = os.environ.get('SECRET_ARN', '')       # Bonus: any other secret to demo


# ─── Helper: get secret from Secrets Manager ──────────────────────────────────
def get_secret(secret_arn: str) -> dict:
    """Retrieve and JSON-parse a secret from AWS Secrets Manager."""
    response = secrets_client.get_secret_value(SecretId=secret_arn)
    secret_string = response.get('SecretString', '{}')
    return json.loads(secret_string)


# ─── Helper: get DB connection ─────────────────────────────────────────────────
def get_db_connection(db_password: str):
    """Return a pymysql connection using env-configured credentials."""
    return pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=db_password,
        database=DB_NAME,
        connect_timeout=5,
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
    if SECRET_ARN:
        try:
            bonus_secret = get_secret(SECRET_ARN)
            # Log only the key names – never log secret values in production!
            logger.info("[BONUS] Secrets Manager secret keys retrieved: %s", list(bonus_secret.keys()))
            # Print to CloudWatch console (visible in Lambda logs)
            print(f"[BONUS] Secret retrieved from Secrets Manager (keys only): {list(bonus_secret.keys())}")
        except Exception as exc:
            logger.warning("[BONUS] Could not retrieve bonus secret: %s", exc)

    # ── Process each S3 record in the event ───────────────────────────────
    for record in event.get('Records', []):
        bucket = record['s3']['bucket']['name']
        key    = unquote_plus(record['s3']['object']['key'])

        logger.info("Processing s3://%s/%s", bucket, key)

        # 1. Read object metadata from S3
        try:
            head = s3_client.head_object(Bucket=bucket, Key=key)
        except Exception as exc:
            logger.error("Failed to head_object s3://%s/%s : %s", bucket, key, exc)
            raise

        content_type     = head.get('ContentType', 'application/octet-stream')
        last_modified    = head.get('LastModified', datetime.now(timezone.utc))
        upload_timestamp = last_modified.strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]  # millisecond precision

        file_name = key.split('/')[-1]   # e.g.  "1717400000000-my_doc.pdf"

        logger.info(
            "File metadata – Name: %s | ContentType: %s | Timestamp: %s",
            file_name, content_type, upload_timestamp,
        )

        # 2. Retrieve DB password from Secrets Manager
        try:
            db_secret  = get_secret(DB_SECRET_ARN)
            db_password = db_secret.get('password', '')
        except Exception as exc:
            logger.error("Could not fetch DB secret: %s", exc)
            raise

        # 3. Insert into RDS
        connection = None
        try:
            connection = get_db_connection(db_password)
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
                "DB record inserted. id=%d | file=%s | type=%s | ts=%s",
                inserted_id, file_name, content_type, upload_timestamp,
            )
            print(
                f"[DB INSERT] id={inserted_id} file_name={file_name} "
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
