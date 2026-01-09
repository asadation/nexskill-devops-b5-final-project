import os
import boto3
import json
import psycopg2
from flask import Flask, jsonify

# --- Helper Function to Get Database Connection ---

def get_db_connection():
    # Using .get() is safer. It returns None if the variable is missing, instead of crashing.
    aws_region = os.environ.get('AWS_REGION')
    secret_arn = os.environ.get('DB_SECRET_ARN')
    db_host = os.environ.get('DB_HOST')

    # Add print statements for debugging. These will show up in the CloudWatch logs.
    print(f"AWS Region: {aws_region}")
    print(f"DB Secret ARN: {secret_arn}")
    print(f"DB Host: {db_host}")

    if not all([aws_region, secret_arn, db_host]):
        raise ValueError("One or more required environment variables (AWS_REGION, DB_SECRET_ARN, DB_HOST) are missing.")

    # Let Boto3 find credentials from the execution role, which is more robust.
    secrets_client = boto3.client('secretsmanager', region_name=aws_region)
    secret_response = secrets_client.get_secret_value(SecretId=secret_arn)
    password = json.loads(secret_response['SecretString'])['password']

    conn = psycopg2.connect(
        host=db_host,
        database="projectdb",
        user="projectadmin",
        password=password
    )
    return conn

# --- Flask Application Definition ---

app = Flask(__name__)

# --- API Endpoints ---

@app.route('/api/data')
def get_data():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS greetings (
                id SERIAL PRIMARY KEY,
                message TEXT NOT NULL
            );
        """)
        cur.execute("SELECT COUNT(*) FROM greetings;")
        if cur.fetchone()[0] == 0:
            cur.execute("INSERT INTO greetings (message) VALUES (%s);", ('Hello from the Final, Working RDS Database!',))
        conn.commit()
        cur.execute("SELECT message FROM greetings ORDER BY id DESC LIMIT 1;")
        db_message = cur.fetchone()[0]
        cur.close()
        conn.close()
        return jsonify({'message': db_message, 'status': 'success'})
    except Exception as e:
        # This will now print the exact database error to the logs.
        print(f"An error occurred in get_data: {e}")
        return jsonify({'message': 'An error occurred connecting to the database.', 'status': 'error'}), 500

@app.route('/health')
def health_check():
    return jsonify({'status': 'healthy'}), 200

# --- Main Execution ---
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

