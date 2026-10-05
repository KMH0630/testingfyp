"""SMILECHAT（中文心理支援多輪對話，CC0）-> mlx_lm chat jsonl，並轉為香港繁體。

來源：https://github.com/qiuhuachuan/smile （先執行佢嘅 convert_to_training_set.py 得到 instruction/output 樣本）
每條樣本：{"instruction": "...对话：\n来访者：...\n咨询师：...\n咨询师：", "output": "..."}

用法：python scripts/convert_smile.py raw/smile_train.json data/processed/smile.jsonl --max 1500

注意：SMILE 部分回覆質素參差（例如叫人「題海戰術」），轉換後一定要人手抽查。
"""
import argparse
import random
import re

from common import read_json_any, write_jsonl, make_sample, is_spoken_friendly, to_hk

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("dst")
ap.add_argument("--max", type=int, default=1500)
ap.add_argument("--seed", type=int, default=42)
args = ap.parse_args()
random.seed(args.seed)

LINE = re.compile(r"^(来访者|咨询师)：(.*)$")
BAD = ["题海", "题目", "高考", "考研"]  # 同長者無關或者質素差嘅話題，按需要加

rows = []
for item in read_json_any(args.src):
    ins, out = item.get("instruction", ""), item.get("output", "").strip()
    if "对话：" not in ins or not out:
        continue
    dialog = ins.split("对话：", 1)[1]
    turns = []
    for line in dialog.splitlines():
        m = LINE.match(line.strip())
        if m:
            role = "user" if m.group(1) == "来访者" else "assistant"
            turns.append((role, m.group(2)))
        elif turns and line.strip():
            r, c = turns[-1]
            turns[-1] = (r, c + line.strip())
    # 最後一句「咨询师：」係空嘅，用 output 補返
    if turns and turns[-1][0] == "assistant" and not turns[-1][1].strip():
        turns[-1] = ("assistant", out)
    else:
        turns.append(("assistant", out))
    if len(turns) < 2 or any(b in out for b in BAD):
        continue
    turns = [(r, to_hk(c)) for r, c in turns]
    sample = make_sample(turns, source="smile")
    if sample and is_spoken_friendly(sample["messages"][-1]["content"], max_chars=180):
        rows.append(sample)

random.shuffle(rows)
write_jsonl(rows[: args.max], args.dst)
