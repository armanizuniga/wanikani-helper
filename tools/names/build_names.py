#!/usr/bin/env python3
"""Combine surnames + given names, attach segments, emit japanese_names.json."""
import json
from segment import segment

names = json.load(open("surnames.json", encoding="utf-8")) + \
        json.load(open("given.json", encoding="utf-8"))

segmented = 0
for n in names:
    s = segment(n["kanji"], n["reading"])
    if s:
        n["segments"] = s
        segmented += 1

json.dump(names, open("japanese_names.json", "w", encoding="utf-8"),
          ensure_ascii=False, separators=(",", ":"))

sur = [n for n in names if n["type"] == "surname"]
giv = [n for n in names if n["type"] == "given"]
print(f"surnames    {len(sur)}")
print(f"given       {len(giv)}  ({sum(1 for n in giv if n['gender']=='m')}m / {sum(1 for n in giv if n['gender']=='f')}f)")
print(f"total       {len(names)}")
print(f"with segments {segmented} ({100*segmented/len(names):.0f}%)")
print(f"full-name combinations: {len(sur)*len(giv):,}")
