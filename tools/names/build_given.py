#!/usr/bin/env python3
"""
Curated given names, each validated against JMnedict.

Every entry is multi-kanji with a conventional phonetic ending, which is where
readings are predictable. Single-kanji given names are excluded on purpose:
愛 has 52 attested readings, 翔 has 9, so no single answer is defensible.

The reading here is the intended common one; JMnedict is used to confirm it is
actually attested for that spelling. Anything it cannot confirm is dropped.
"""
import json

M = [("太郎","たろう"),("一郎","いちろう"),("次郎","じろう"),("健太","けんた"),("翔太","しょうた"),
     ("大輔","だいすけ"),("拓也","たくや"),("直樹","なおき"),("健一","けんいち"),("雄太","ゆうた"),
     ("大樹","だいき"),("亮太","りょうた"),("和也","かずや"),("智也","ともや"),("竜也","たつや"),
     ("慎二","しんじ"),("浩二","こうじ"),("洋平","ようへい"),("康平","こうへい"),("大介","だいすけ"),
     ("秀樹","ひでき"),("英樹","ひでき"),("和夫","かずお"),("正雄","まさお"),("健二","けんじ"),
     ("誠一","せいいち"),("修平","しゅうへい"),("裕樹","ひろき"),("翔平","しょうへい"),("優斗","ゆうと")]

F = [("花子","はなこ"),("恵美","えみ"),("詩織","しおり"),("直美","なおみ"),("智子","ともこ"),
     ("裕子","ゆうこ"),("久美子","くみこ"),("真由美","まゆみ"),("陽子","ようこ"),("京子","きょうこ"),
     ("愛子","あいこ"),("舞子","まいこ"),("千夏","ちなつ"),("美穂","みほ"),("彩香","あやか"),
     ("麻衣","まい"),("沙織","さおり"),("由香","ゆか"),("明日香","あすか"),("七海","ななみ"),
     ("美紀","みき"),("香織","かおり"),("恵子","けいこ"),("幸子","さちこ"),("由紀","ゆき")]

d = json.load(open("jmnedict_index.json", encoding="utf-8"))
idx, rom = d["index"], d["romaji"]
GIVEN = {"given", "fem", "masc", "person"}

out, dropped = [], []
for names, gender in ((M, "m"), (F, "f")):
    for rank, (kanji, reading) in enumerate(names, 1):
        types = idx.get(kanji, {}).get(reading)
        if not types or not (GIVEN & set(types)):
            dropped.append((kanji, reading, list(idx.get(kanji, {}))[:6]))
            continue
        out.append({"kanji": kanji, "reading": reading,
                    "romaji": rom.get(kanji, {}).get(reading, ""),
                    "type": "given", "gender": gender, "rank": rank})

json.dump(out, open("given.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"validated by JMnedict : {len(out)}/{len(M)+len(F)}")
for k, r, seen in dropped:
    print(f"  DROPPED {k} ({r}) — jmnedict has {seen}")
