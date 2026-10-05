"""Firebase Admin SDK 初始化。冇設定 service account 時，Firestore 功能會自動停用（方便本機測試）。"""
import logging
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore

from .config import FIREBASE_CREDENTIALS, BASE_DIR

log = logging.getLogger("caremate.firebase")
_db = None


def init_firebase():
    global _db
    if firebase_admin._apps:
        return
    cred_path = (BASE_DIR / FIREBASE_CREDENTIALS).resolve() if FIREBASE_CREDENTIALS else None
    if not cred_path or not cred_path.exists():
        log.warning("搵唔到 FIREBASE_CREDENTIALS，Firestore 已停用（只可以用 DEV_SKIP_AUTH=1 測試）")
        return
    firebase_admin.initialize_app(credentials.Certificate(str(cred_path)))
    _db = firestore.client()
    log.info("Firebase Admin 已初始化")


def get_db():
    """回傳 Firestore client；未設定時回傳 None。"""
    return _db


def firebase_ready() -> bool:
    return bool(firebase_admin._apps)
