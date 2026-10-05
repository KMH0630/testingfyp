from fastapi import APIRouter

from ..firebase import firebase_ready
from ..config import DEV_SKIP_AUTH

router = APIRouter(tags=["health"])


@router.get("/health")
def health():
    """手機用嚟測試連唔連到 server。"""
    return {"status": "ok", "firebase": firebase_ready(), "dev_skip_auth": DEV_SKIP_AUTH}
