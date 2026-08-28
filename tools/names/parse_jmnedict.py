#!/usr/bin/env python3
"""Index JMnedict by kanji spelling, keeping surname/given entries only."""
import re, json, collections

TYPES = {"surname", "given", "fem", "masc", "person"}
entry_re = re.compile(r"<entry>(.*?)</entry>", re.S)
keb_re   = re.compile(r"<keb>(.*?)</keb>")
reb_re   = re.compile(r"<reb>(.*?)</reb>")
type_re  = re.compile(r"<name_type>&(\w+);</name_type>")
trans_re = re.compile(r"<trans_det>(.*?)</trans_det>")

index = collections.defaultdict(lambda: collections.defaultdict(set))  # kanji -> reading -> types
romaji = collections.defaultdict(dict)                                  # kanji -> reading -> romaji

raw = open("JMnedict.xml", encoding="utf-8").read()
n = 0
for m in entry_re.finditer(raw):
    body = m.group(1)
    kebs = keb_re.findall(body)
    rebs = reb_re.findall(body)
    types = set(type_re.findall(body)) & TYPES
    if not kebs or not rebs or not types:
        continue
    trans = trans_re.findall(body)
    n += 1
    for k in kebs:
        for r in rebs:
            index[k][r] |= types
            if trans:
                romaji[k][r] = trans[0]

out = {k: {r: sorted(t) for r, t in v.items()} for k, v in index.items()}
json.dump({"index": out, "romaji": {k: v for k, v in romaji.items()}},
          open("jmnedict_index.json", "w", encoding="utf-8"), ensure_ascii=False)
print(f"entries indexed: {n}")
print(f"distinct kanji spellings: {len(index)}")
