"""用 ffmpeg 將任何音訊（m4a / wav / aac ...）轉成 mp3。"""
import shutil
import subprocess
from pathlib import Path


class ConvertError(RuntimeError):
    pass


def ensure_ffmpeg():
    if not shutil.which("ffmpeg"):
        raise ConvertError("伺服器未安裝 ffmpeg（macOS：brew install ffmpeg）")


def to_mp3(src: Path, dst: Path, bitrate: str = "64k") -> Path:
    """語音用 64kbps 單聲道已經夠清楚，檔案細。"""
    ensure_ffmpeg()
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(src),
           "-vn", "-ac", "1", "-ar", "16000", "-b:a", bitrate, str(dst)]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise ConvertError(proc.stderr.strip() or "ffmpeg 轉換失敗")
    return dst


def duration_seconds(path: Path) -> float | None:
    if not shutil.which("ffprobe"):
        return None
    proc = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
        capture_output=True, text=True)
    try:
        return round(float(proc.stdout.strip()), 2)
    except ValueError:
        return None
