"""ESConv（英文情緒支援對話）-> mlx_lm chat jsonl。

來源：https://github.com/thu-coai/Emotional-Support-Conversation （ESConv.json）
格式：list of {emotion_type, problem_type, situation, dialog: [{speaker, content, annotation:{strategy}}]}

用法：python scripts/convert_esconv.py raw/ESConv.json data/processed/esconv.jsonl --max 300
"""
import argparse
import random

from common import read_json_any, write_jsonl, make_sample, is_spoken_friendly

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("dst")
ap.add_argument("--max", type=int, default=300)
ap.add_argument("--seed", type=int, default=42)
args = ap.parse_args()
random.seed(args.seed)

rows = []
for conv in read_json_any(args.src):
    turns = []
    for t in conv.get("dialog", []):
        role = "user" if t.get("speaker", "").lower() == "seeker" else "assistant"
        turns.append((role, t.get("content", "")))
    # 喺第 4–10 句之間隨機揀一個 supporter 回覆做「答案」，令模型學識對話中段嘅技巧
    idx = [i for i, (r, _) in enumerate(turns) if r == "assistant" and 3 <= i <= 12]
    if not idx:
        continue
    cut = random.choice(idx)
    sample = make_sample(turns[: cut + 1], source="esconv")
    if sample and is_spoken_friendly(sample["messages"][-1]["content"], max_chars=300):
        rows.append(sample)

random.shuffle(rows)
write_jsonl(rows[: args.max], args.dst)
