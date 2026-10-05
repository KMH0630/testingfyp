"""CareMate 數據處理共用工具。"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SYSTEM_PROMPT = (ROOT / "prompts" / "system_prompt.txt").read_text(encoding="utf-8").strip()
RISK_PROMPT = (ROOT / "prompts" / "risk_prompt.txt").read_text(encoding="utf-8").strip()

try:
    import opencc
    _s2hk = opencc.OpenCC("s2hk")
except Exception:  # opencc 未安裝時唔轉換
    _s2hk = None


def to_hk(text: str) -> str:
    """簡體轉香港繁體。"""
    return _s2hk.convert(text) if _s2hk else text


def read_json_any(path):
    """讀 .json（list）或 .jsonl。"""
    path = Path(path)
    text = path.read_text(encoding="utf-8").strip()
    if text.startswith("["):
        return json.loads(text)
    return [json.loads(line) for line in text.splitlines() if line.strip()]


def write_jsonl(rows, path):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    print(f"寫入 {len(rows)} 條 -> {path}")


def merge_turns(turns):
    """合併連續同一角色嘅訊息，確保 user / assistant 交替。"""
    merged = []
    for role, content in turns:
        content = content.strip()
        if not content:
            continue
        if merged and merged[-1]["role"] == role:
            merged[-1]["content"] += " " + content
        else:
            merged.append({"role": role, "content": content})
    return merged


def make_sample(turns, system=SYSTEM_PROMPT, source="unknown"):
    """turns: [(role, content), ...]，回傳 mlx_lm chat 格式；最後一句必須係 assistant。"""
    msgs = merge_turns(turns)
    while msgs and msgs[0]["role"] != "user":
        msgs.pop(0)
    if len(msgs) < 2 or msgs[-1]["role"] != "assistant":
        return None
    return {"messages": [{"role": "system", "content": system}] + msgs, "source": source}


_MD = re.compile(r"(\*\*|__|^#+\s|^\s*[-*]\s|https?://)", re.M)
_EMOJI = re.compile("[\U0001F300-\U0001FAFF\u2600-\u27BF]")


def is_spoken_friendly(text: str, max_chars: int = 180) -> bool:
    """過濾唔適合 TTS 讀出嘅回覆。"""
    return len(text) <= max_chars and not _MD.search(text) and not _EMOJI.search(text)
