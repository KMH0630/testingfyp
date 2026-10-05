"""Firestore 資料結構（全部路徑集中喺呢度，改結構只需要改呢個檔）。

users/{uid}                              用戶資料（長者或照顧者）
  ├─ audio/{audioId}                     錄音記錄（mp3 存喺 FastAPI 伺服器）
  ├─ messages/{messageId}                每一輪對話：長者講咗咩、AI 答咗咩
  ├─ medications/{medId}                 藥物及服藥時間
  ├─ medication_events/{date_medId_HHMM} 每一次應該食藥嘅紀錄（scheduled / taken / missed）
  ├─ health_samples/{sampleId}           Apple Watch 心跳、呼吸頻率
  ├─ daily_logs/{YYYY-MM-DD}             每日總結
  └─ alerts/{alertId}                    警報（高風險對話、漏食藥、健康數據異常）
link_codes/{code}                        長者畀照顧者嘅配對碼（只限後端讀寫）
"""
from datetime import datetime, timezone
from typing import Any

from .firebase import get_db

USERS = "users"
AUDIO = "audio"
MESSAGES = "messages"
MEDICATIONS = "medications"
MEDICATION_EVENTS = "medication_events"
HEALTH_SAMPLES = "health_samples"
DAILY_LOGS = "daily_logs"
ALERTS = "alerts"
LINK_CODES = "link_codes"

_known_users: set[str] = set()   # 已確認存在嘅 users/{uid}，避免每次都讀 Firestore


def now() -> datetime:
    return datetime.now(timezone.utc)


def default_profile() -> dict[str, Any]:
    t = now()
    return {
        "role": "elder",                 # elder = 長者；caregiver = 照顧者
        "display_name": "",
        "locale": "zh-HK",
        "settings": {"font_scale": 1.35},
        "emergency_contacts": [],        # [{name, phone, relation}]
        "caregiver_uids": [],            # 可以睇呢位長者資料嘅照顧者（Firestore rules 會用到）
        "elder_uids": [],                # 照顧者照顧緊邊幾位長者
        "created_at": t,
        "updated_at": t,
    }


def user_ref(uid: str):
    db = get_db()
    return db.collection(USERS).document(uid) if db is not None else None


def ensure_user(uid: str):
    """確保 users/{uid} 存在（第一次用就建立預設資料），回傳 DocumentReference；未設定 Firebase 時回傳 None。"""
    ref = user_ref(uid)
    if ref is None:
        return None
    if uid not in _known_users:
        if not ref.get().exists:
            ref.set(default_profile())
        _known_users.add(uid)
    return ref


def sub(uid: str, name: str):
    """users/{uid}/{name} 子集合；未設定 Firebase 時回傳 None。"""
    ref = ensure_user(uid)
    return ref.collection(name) if ref is not None else None


def jsonable(value: Any) -> Any:
    """將 Firestore 讀出嚟嘅 datetime 轉成 ISO 字串，方便回傳 JSON。"""
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, dict):
        return {k: jsonable(v) for k, v in value.items()}
    if isinstance(value, list):
        return [jsonable(v) for v in value]
    return value
