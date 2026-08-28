#!/usr/bin/env python3
"""KANJIDIC2 -> {kanji: {"kun": [...], "on": [...], "nanori": [...]}}"""
import re, json

char_re    = re.compile(r"<character>(.*?)</character>", re.S)
literal_re = re.compile(r"<literal>(.)</literal>")
kun_re     = re.compile(r'<reading r_type="ja_kun">(.*?)</reading>')
on_re      = re.compile(r'<reading r_type="ja_on">(.*?)</reading>')
nanori_re  = re.compile(r"<nanori>(.*?)</nanori>")

KATA_TO_HIRA = {chr(c): chr(c - 0x60) for c in range(0x30A1, 0x30F7)}
def to_hira(s): return "".join(KATA_TO_HIRA.get(c, c) for c in s)

out = {}
raw = open("kanjidic2.xml", encoding="utf-8").read()
for m in char_re.finditer(raw):
    body = m.group(1)
    lit = literal_re.search(body)
    if not lit: continue
    kun = {to_hira(r.split(".")[0].replace("-", "")) for r in kun_re.findall(body)}
    on  = {to_hira(r) for r in on_re.findall(body)}
    nan = {to_hira(r) for r in nanori_re.findall(body)}
    out[lit.group(1)] = {"kun": sorted(x for x in kun if x),
                         "on":  sorted(x for x in on  if x),
                         "nanori": sorted(x for x in nan if x)}
json.dump(out, open("kanji_readings.json", "w", encoding="utf-8"), ensure_ascii=False)
print(f"kanji indexed: {len(out)}")
