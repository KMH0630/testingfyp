"""用戶資料：users/{uid}。App 開啟時呼叫 GET /users/me，第一次會自動建立。"""
from typing import Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from .. import store
from ..deps import get_current_uid

router = APIRouter(prefix="/users", tags=["users"])


class EmergencyContact(BaseModel):
    name: str = Field(..., max_length=50)
    phone: str = Field(..., pattern=r"^\+?[0-9 ]{8,16}$")
    relation: str = Field("", max_length=20)


class Settings(BaseModel):
    font_scale: float = Field(1.35, ge=1.0, le=2.5)


class ProfileUpdate(BaseModel):
    role: Literal["elder", "caregiver"] | None = None
    display_name: str | None = Field(None, max_length=50)
    locale: str | None = Field(None, max_length=10)
    settings: Settings | None = None
    emergency_contacts: list[EmergencyContact] | None = Field(None, max_length=5)


@router.get("/me")
def get_me(uid: str = Depends(get_current_uid)):
    ref = store.ensure_user(uid)
    if ref is None:
        return {"uid": uid, **store.jsonable(store.default_profile()), "saved_to_firestore": False}
    return {"uid": uid, **store.jsonable(ref.get().to_dict()), "saved_to_firestore": True}


@router.put("/me")
def update_me(body: ProfileUpdate, uid: str = Depends(get_current_uid)):
    changes = body.model_dump(exclude_none=True)
    ref = store.ensure_user(uid)
    if ref is None:
        return {"ok": True, "saved_to_firestore": False, "changes": changes}
    ref.update(changes | {"updated_at": store.now()})
    return {"ok": True, "saved_to_firestore": True, "changes": changes}
