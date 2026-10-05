"""ElderBench（長者個人化對話，英文，523 條）-> mlx_lm chat jsonl。

來源：https://github.com/AmEskandari/ElderBench
欄位：graph_context（長者背景知識圖）、chat_history（"User: ...\nAssistant: ..."）、question、answer
split：train 366 / val 52 / test 105  —— test.jsonl 只可用嚟評估，唔可以攞嚟 train！

用法：
  python scripts/convert_elderbench.py raw/ElderBench/data/train.jsonl data/processed/elderbench_train.jsonl
  python scripts/convert_elderbench.py raw/ElderBench/data/val.jsonl   data/processed/elderbench_val.jsonl
"""
import argparse
import re

from common import read_json_any, write_jsonl, make_sample, SYSTEM_PROMPT

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("dst")
args = ap.parse_args()

SPK = re.compile(r"^(User|Assistant):\s*(.*)$")

rows = []
for item in read_json_any(args.src):
    turns = []
    for line in item.get("chat_history", "").splitlines():
        m = SPK.match(line.strip())
        if m:
            turns.append(("user" if m.group(1) == "User" else "assistant", m.group(2)))
        elif turns and line.strip():
            r, c = turns[-1]
            turns[-1] = (r, c + " " + line.strip())
    turns += [("user", item["question"]), ("assistant", item["answer"])]
    system = SYSTEM_PROMPT + "\n\n【長者背景資料】\n" + item.get("graph_context", "").strip()
    sample = make_sample(turns, system=system, source="elderbench")
    if sample:
        rows.append(sample)

write_jsonl(rows, args.dst)
