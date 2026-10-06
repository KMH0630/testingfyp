"""藥物及服藥時間：users/{uid}/medications/{medId}。

由設定頁新增／修改；之後 APScheduler 會根據 times 建立 medication_events 同發提醒。
刪除係「軟刪除」（active = false），保留舊紀錄方便查看歷史。
"""
from fastapi import APIRouter, Depends, HTTPException
from google.cloud import firestore
from pydantic import BaseModel, Field, field_validator

from .. import store
from ..deps import get_current_uid

router = APIRouter(prefix="/medications", tags=["medications"])

TIME_PATTERN = r"^([01][0-9]|2[0-3]):[0-5][0-9]$"   # 24 小時制 HH:MM（香港時間）


class MedicationIn(BaseModel):
    name: str = Field(..., min_length=1, max_length=50)
    times: list[str] = Field(..., min_length=1, max_length=6)
    instructions: str = Field("", max_length=100)       # 例如「飯後」；AI 唔會建議劑量

    @field_validator("name", "instructions")
    @classmethod
    def strip(cls, v: str) -> str:
        return v.strip()

    @field_validator("times")
    @classmethod
    def check_times(cls, v: list[str]) -> list[str]:
        import re
        for t in v:
            if not re.match(TIME_PATTERN, t):
                raise ValueError(f"時間格式要係 HH:MM：{t}")
        return sorted(set(v))


def _col(uid: str):
    col = store.sub(uid, store.MEDICATIONS)
    if col is None:
        raise HTTPException(503, "伺服器未設定 Firestore")
    return col


@router.get("")
def list_medications(uid: str = Depends(get_current_uid)):
    docs = _col(uid).where(filter=firestore.FieldFilter("active", "==", True)).stream()
    items = [{"id": d.id, **store.jsonable(d.to_dict())} for d in docs]
    return sorted(items, key=lambda m: (m["times"][0] if m.get("times") else "99:99", m["name"]))


@router.post("")
def create_medication(body: MedicationIn, uid: str = Depends(get_current_uid)):
    t = store.now()
    data = body.model_dump() | {"active": True, "created_by": uid, "created_at": t, "updated_at": t}
    _, ref = _col(uid).add(data)
    return {"id": ref.id, **store.jsonable(data)}


@router.put("/{med_id}")
def update_medication(med_id: str, body: MedicationIn, uid: str = Depends(get_current_uid)):
    ref = _col(uid).document(med_id)
    snap = ref.get()
    if not snap.exists or not snap.to_dict().get("active", False):
        raise HTTPException(404, "搵唔到呢隻藥")
    changes = body.model_dump() | {"updated_at": store.now()}
    ref.update(changes)
    return {"id": med_id, **store.jsonable(snap.to_dict() | changes)}


@router.delete("/{med_id}")
def delete_medication(med_id: str, uid: str = Depends(get_current_uid)):
    ref = _col(uid).document(med_id)
    if not ref.get().exists:
        raise HTTPException(404, "搵唔到呢隻藥")
    ref.update({"active": False, "updated_at": store.now()})
    return {"ok": True}
