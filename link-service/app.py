# link_service.py
import os
import hashlib
import psycopg2
import requests
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse, RedirectResponse
from fastapi.middleware.cors import CORSMiddleware

# ---------------------------
# Load environment variables
# ---------------------------
from dotenv import load_dotenv
load_dotenv()

DB_HOST = os.environ.get("DB_HOST")
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_NAME = os.environ.get("DB_NAME")
DB_USER = os.environ.get("DB_USER")
DB_PASSWORD = os.environ.get("DB_PASSWORD")

ANALYTICS_SERVICE_URL = os.environ.get("ANALYTICS_SERVICE_URL", "")

if not all([DB_HOST, DB_NAME, DB_USER, DB_PASSWORD]):
    raise RuntimeError("Database environment variables are missing!")

# ---------------------------
# Database functions
# ---------------------------
def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )

def init_db():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute('''
        CREATE TABLE IF NOT EXISTS links (
            id SERIAL PRIMARY KEY,
            original_url TEXT NOT NULL,
            short_code VARCHAR(10) UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    cur.close()
    conn.close()

def generate_short_code(url: str) -> str:
    return hashlib.md5(url.encode()).hexdigest()[:6]

# ---------------------------
# FastAPI app
# ---------------------------
app = FastAPI(openapi_prefix="/api/links")

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"]
)

# ---------------------------
# Startup event: initialize DB
# ---------------------------
@app.on_event("startup")
def startup_event():
    init_db()

# ---------------------------
# Health check
# ---------------------------
@app.get("/health")
def health():
    return {"status": "ok"}

# ---------------------------
# Shorten URL
# ---------------------------
@app.post("/shorten")
def shorten_url(payload: dict):
    original_url = payload.get("url")
    if not original_url:
        raise HTTPException(status_code=400, detail="URL is required")
    
    short_code = generate_short_code(original_url)
    
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT short_code FROM links WHERE original_url = %s', (original_url,))
        existing = cur.fetchone()
        
        if existing:
            short_code = existing[0]
        else:
            cur.execute(
                'INSERT INTO links (original_url, short_code) VALUES (%s, %s)',
                (original_url, short_code)
            )
            conn.commit()
        
        cur.close()
        conn.close()
        return {"short_code": short_code, "short_url": f"/{short_code}"}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ---------------------------
# Redirect short URL
# ---------------------------
@app.get("/{short_code}")
def redirect_url(short_code: str):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT original_url FROM links WHERE short_code = %s', (short_code,))
        result = cur.fetchone()
        cur.close()
        conn.close()
        
        if not result:
            raise HTTPException(status_code=404, detail="URL not found")
        
        original_url = result[0]
        
        # Notify analytics service asynchronously
        if ANALYTICS_SERVICE_URL:
            try:
                requests.post(
                    f'{ANALYTICS_SERVICE_URL}/api/track',
                    json={'short_code': short_code},
                    timeout=2
                )
            except:
                pass
        
        return RedirectResponse(original_url)
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ---------------------------
# List all links
# ---------------------------
@app.get("/")
def get_all_links():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT original_url, short_code, created_at FROM links ORDER BY created_at DESC')
        rows = cur.fetchall()
        cur.close()
        conn.close()
        
        return [
            {"original_url": r[0], "short_code": r[1], "created_at": r[2].isoformat()}
            for r in rows
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
