"""合併所有來源 -> data/final/{train,valid,test}.jsonl（mlx_lm chat 格式）。

用法：python scripts/build_dataset.py
會讀取：
  data/seed/cantonese_support_seed.jsonl   （自己寫，最重要，會 oversample）
  data/seed/risk_seed.jsonl                （自己寫嘅風險分類樣本）
  data/processed/*.jsonl                   （convert_*.py 嘅輸出）
"""
import json
import random
from collections import Counter
from pathlib import Path

from common import ROOT, SYSTEM_PROMPT, RISK_PROMPT, read_json_any, write_jsonl, make_sample

random.seed(42)
SEED_OVERSAMPLE = 3          # 自寫粵語樣本重複次數（少量高質數據要加權）
CAPS = {                     # 每個來源最多用幾多條，控制比例
    "esconv": 300,
    "smile": 1500,
    "elderbench": 366,
}

rows = []

# 1) 自寫粵語對話
for item in read_json_any(ROOT / "data/seed/cantonese_support_seed.jsonl"):
    s = make_sample([tuple(t) for t in item["turns"]], source="seed_" + item.get("tag", "misc"))
    if s:
        s["weight"] = SEED_OVERSAMPLE
        rows.append(s)

# 2) 風險分類（輸出 JSON）
for item in read_json_any(ROOT / "data/seed/risk_seed.jsonl"):
    user = "長者說話：" + item["text"]
    if item.get("vitals"):
        user += "\n生理數據：" + item["vitals"]
    answer = json.dumps(item["label"], ensure_ascii=False)
    s = make_sample([("user", user), ("assistant", answer)], system=RISK_PROMPT, source="risk")
    s["weight"] = SEED_OVERSAMPLE
    rows.append(s)

# 3) 公開數據集（已轉換）
for f in sorted((ROOT / "data/processed").glob("*.jsonl")):
    if "test" in f.name:          # 保護測試集，唔好混入訓練
        continue
    items = read_json_any(f)
    src = items[0].get("source", f.stem) if items else f.stem
    cap = CAPS.get(src, len(items))
    random.shuffle(items)
    rows += items[:cap]

# 去重（以最後兩句做 key）
seen, uniq = set(), []
for r in rows:
    key = json.dumps(r["messages"][-2:], ensure_ascii=False)
    if key in seen:
        continue
    seen.add(key)
    uniq.append(r)

random.shuffle(uniq)
n = len(uniq)
n_valid = max(1, int(n * 0.1))
n_test = max(1, int(n * 0.1))
splits = {
    "valid": uniq[:n_valid],
    "test": uniq[n_valid:n_valid + n_test],
    "train": uniq[n_valid + n_test:],
}
# 先 split 再 oversample，避免同一條自寫樣本同時出現喺 train 同 test（data leakage）
splits["train"] = [r for r in splits["train"] for _ in range(r.get("weight", 1))]
random.shuffle(splits["train"])

out_dir = ROOT / "data/final"
for name, data in splits.items():
    # mlx_lm 只需要 messages 欄位；source 另存方便報告統計
    write_jsonl([{"messages": r["messages"]} for r in data], out_dir / f"{name}.jsonl")

print("來源分佈（train）：", Counter(r["source"].split("_")[0] for r in splits["train"]))
