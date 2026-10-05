"""驗證手機傳嚟嘅 Firebase ID token。"""
from fastapi import Header, HTTPException, status
from firebase_admin import auth

from .config import DEV_SKIP_AUTH
from .firebase import firebase_ready


def get_current_uid(authorization: str | None = Header(default=None)) -> str:
    if DEV_SKIP_AUTH:
        return "dev-user"
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "缺少 Authorization: Bearer <Firebase ID token>")
    if not firebase_ready():
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "伺服器未設定 Firebase")
    try:
        decoded = auth.verify_id_token(authorization.removeprefix("Bearer ").strip())
    except Exception as e:  # token 過期、偽造等
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, f"Token 無效：{e}")
    return decoded["uid"]
