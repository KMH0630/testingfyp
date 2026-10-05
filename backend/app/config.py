"""讀取 .env 設定。"""
import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent
FIREBASE_CREDENTIALS = os.getenv("FIREBASE_CREDENTIALS", "")
DEV_SKIP_AUTH = os.getenv("DEV_SKIP_AUTH", "0") == "1"
UPLOAD_DIR = (BASE_DIR / os.getenv("UPLOAD_DIR", "uploads")).resolve()
MAX_UPLOAD_MB = int(os.getenv("MAX_UPLOAD_MB", "20"))

UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
