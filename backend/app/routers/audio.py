"""錄音上載：手機 → FastAPI → 存檔 + 轉 mp3 → Firestore 記錄。"""
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse
from google.cloud.firestore_v1.base_query import FieldFilter

from ..config import UPLOAD_DIR, MAX_UPLOAD_MB
from ..deps import get_current_uid
from ..firebase import get_db
from ..services.audio_convert import to_mp3, duration_seconds, ConvertError

router = APIRouter(prefix="/audio", tags=["audio"])

ALLOWED_EXT = {".mp3", ".m4a", ".aac", ".wav", ".caf", ".mp4", ".ogg", ".opus", ".flac"}
CHUNK = 1024 * 1024


@router.post("/upload")
async def upload_audio(
    file: UploadFile = File(...),
    source: str = Form("record"),          # record = App 錄音；file = 揀現有檔案
    uid: str = Depends(get_current_uid),
):
    ext = Path(file.filename or "").suffix.lower()
    if ext not in ALLOWED_EXT:
        raise HTTPException(400, f"唔支援嘅格式：{ext or '冇副檔名'}")

    audio_id = uuid.uuid4().hex
    user_dir = UPLOAD_DIR / uid
    user_dir.mkdir(parents=True, exist_ok=True)
    raw_path = user_dir / f"{audio_id}_raw{ext}"
    mp3_path = user_dir / f"{audio_id}.mp3"

    # 分段寫入，同時檢查大小
    size = 0
    with raw_path.open("wb") as f:
        while chunk := await file.read(CHUNK):
            size += len(chunk)
            if size > MAX_UPLOAD_MB * CHUNK:
                f.close()
                raw_path.unlink(missing_ok=True)
                raise HTTPException(413, f"檔案超過 {MAX_UPLOAD_MB}MB")
            f.write(chunk)

    try:
        if ext == ".mp3":
            raw_path.rename(mp3_path)
        else:
            to_mp3(raw_path, mp3_path)
            raw_path.unlink(missing_ok=True)   # 轉完刪原檔；如需保留可以註解呢行
    except ConvertError as e:
        raw_path.unlink(missing_ok=True)
        raise HTTPException(422, f"轉換 mp3 失敗：{e}")

    record = {
        "id": audio_id,
        "uid": uid,
        "original_filename": file.filename,
        "source": source,
        "size_bytes": mp3_path.stat().st_size,
        "duration_sec": duration_seconds(mp3_path),
        "mp3_path": str(mp3_path.relative_to(UPLOAD_DIR)),
        "status": "uploaded",              # 之後做 STT 會改成 transcribed
        "created_at": datetime.now(timezone.utc),
    }

    db = get_db()
    if db is not None:
        db.collection("audio_uploads").document(audio_id).set(record)

    return {**record, "created_at": record["created_at"].isoformat(),
            "url": f"/audio/{audio_id}.mp3", "saved_to_firestore": db is not None}


@router.get("/{audio_id}.mp3")
def get_audio(audio_id: str, uid: str = Depends(get_current_uid)):
    """只可以攞返自己上載嘅檔案。"""
    if not audio_id.isalnum():
        raise HTTPException(400, "id 無效")
    path = UPLOAD_DIR / uid / f"{audio_id}.mp3"
    if not path.exists():
        raise HTTPException(404, "搵唔到檔案")
    return FileResponse(path, media_type="audio/mpeg", filename=f"{audio_id}.mp3")


@router.get("")
def list_audio(uid: str = Depends(get_current_uid)):
    """列出自己上載過嘅錄音（由 Firestore 讀；未設定 Firebase 就讀資料夾）。"""
    db = get_db()
    if db is not None:
        docs = db.collection("audio_uploads").where(filter=FieldFilter("uid", "==", uid)).stream()
        items = [d.to_dict() for d in docs]
        for i in items:
            i["created_at"] = i["created_at"].isoformat()
        return sorted(items, key=lambda x: x["created_at"], reverse=True)
    user_dir = UPLOAD_DIR / uid
    return [{"id": p.stem, "url": f"/audio/{p.name}"} for p in sorted(user_dir.glob("*.mp3"))] if user_dir.exists() else []
