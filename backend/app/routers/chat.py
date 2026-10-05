"""手機將 AI 對話記錄傳上嚟（之後用嚟做風險判斷同 daily log）。"""
from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from ..deps import get_current_uid
from ..firebase import get_db

router = APIRouter(prefix="/chat", tags=["chat"])


class ChatLog(BaseModel):
    user_text: str = Field(..., max_length=2000)
    ai_text: str = Field(..., max_length=4000)
    model_tier: Literal[0, 1, 2] = 1     # 0 = 預設回覆, 1 = Apple Foundation Model, 2 = 自訓模型
    fallback_reason: str | None = None


@router.post("/log")
def log_chat(body: ChatLog, uid: str = Depends(get_current_uid)):
    data = body.model_dump() | {"uid": uid, "created_at": datetime.now(timezone.utc)}
    db = get_db()
    doc_id = None
    if db is not None:
        _, ref = db.collection("users").document(uid).collection("messages").add(data)
        doc_id = ref.id
    return {"ok": True, "id": doc_id, "saved_to_firestore": db is not None}
