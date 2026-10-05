"""每一輪對話記錄：users/{uid}/messages/{messageId}（之後用嚟做風險判斷同每日總結）。"""
from typing import Literal

from fastapi import APIRouter, Depends, Query
from google.cloud import firestore

from pydantic import BaseModel, Field

from .. import store
from ..deps import get_current_uid

router = APIRouter(prefix="/chat", tags=["chat"])


class ChatLog(BaseModel):
    user_text: str = Field(..., max_length=2000)
    ai_text: str = Field(..., max_length=4000)
    audio_id: str | None = Field(None, pattern=r"^[0-9a-f]{32}$")   # 對應 users/{uid}/audio/{audioId}
    model_tier: Literal[0, 1, 2] = 1     # 0 = 預設回覆, 1 = Apple Foundation Model, 2 = 自訓模型
    fallback_reason: str | None = None
    input_type: Literal["voice", "text"] = "voice"


@router.post("/log")
def log_chat(body: ChatLog, uid: str = Depends(get_current_uid)):
    data = body.model_dump() | {
        "risk_level": "none",            # 之後由危機偵測填：none / low / medium / high
        "created_at": store.now(),
    }
    col = store.sub(uid, store.MESSAGES)
    if col is None:
        return {"ok": True, "id": None, "saved_to_firestore": False}
    _, ref = col.add(data)
    return {"ok": True, "id": ref.id, "saved_to_firestore": True}


@router.get("/messages")
def list_messages(limit: int = Query(50, ge=1, le=200), uid: str = Depends(get_current_uid)):
    col = store.sub(uid, store.MESSAGES)
    if col is None:
        return []
    docs = col.order_by("created_at", direction=firestore.Query.DESCENDING).limit(limit).stream()
    return [{"id": d.id, **store.jsonable(d.to_dict())} for d in docs]
