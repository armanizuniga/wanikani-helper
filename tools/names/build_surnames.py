#!/usr/bin/env python3
"""
Join the Wikipedia frequency ranking against JMnedict.

Wikipedia says which surname is common and how it's normally read; JMnedict says
which readings are actually attested. Taking the intersection gives one canonical
reading per name, backed by both sources, and sidesteps JMnedict listing rare
variants (佐藤 also has さいう, さとあ, さどう) with no frequency information.
"""
import json, unicodedata

WIKI = [
 ("佐藤","Satō"),("鈴木","Suzuki"),("高橋","Takahashi"),("田中","Tanaka"),("渡辺","Watanabe"),
 ("伊藤","Itō"),("中村","Nakamura"),("小林","Kobayashi"),("山本","Yamamoto"),("加藤","Katō"),
 ("吉田","Yoshida"),("山田","Yamada"),("佐々木","Sasaki"),("山口","Yamaguchi"),("松本","Matsumoto"),
 ("井上","Inoue"),("木村","Kimura"),("清水","Shimizu"),("林","Hayashi"),("斉藤","Saitō"),
 ("斎藤","Saitō"),("山崎","Yamazaki"),("中島","Nakajima"),("森","Mori"),("阿部","Abe"),
 ("池田","Ikeda"),("橋本","Hashimoto"),("石川","Ishikawa"),("山下","Yamashita"),("小川","Ogawa"),
 ("石井","Ishii"),("長谷川","Hasegawa"),("後藤","Gotō"),("岡田","Okada"),("近藤","Kondō"),
 ("前田","Maeda"),("藤田","Fujita"),("遠藤","Endō"),("青木","Aoki"),("坂本","Sakamoto"),
 ("村上","Murakami"),("太田","Ōta"),("金子","Kaneko"),("藤井","Fujii"),("福田","Fukuda"),
 ("西村","Nishimura"),("三浦","Miura"),("竹内","Takeuchi"),("中川","Nakagawa"),("岡本","Okamoto"),
 ("松田","Matsuda"),("原田","Harada"),("中野","Nakano"),("小野","Ono"),("田村","Tamura"),
 ("藤原","Fujiwara"),("中山","Nakayama"),("石田","Ishida"),("小島","Kojima"),("和田","Wada"),
 ("森田","Morita"),("内田","Uchida"),("柴田","Shibata"),("酒井","Sakai"),("原","Hara"),
 ("高木","Takagi"),("横山","Yokoyama"),("安藤","Andō"),("宮崎","Miyazaki"),("上田","Ueda"),
 ("島田","Shimada"),("工藤","Kudō"),("大野","Ōno"),("宮本","Miyamoto"),("杉山","Sugiyama"),
 ("今井","Imai"),("丸山","Maruyama"),("増田","Masuda"),("高田","Takada"),("村田","Murata"),
 ("平野","Hirano"),("大塚","Ōtsuka"),("菅原","Sugawara"),("武田","Takeda"),("新井","Arai"),
 ("小山","Koyama"),("野口","Noguchi"),("桜井","Sakurai"),("千葉","Chiba"),("岩崎","Iwasaki"),
 ("佐野","Sano"),("谷口","Taniguchi"),("上野","Ueno"),("松井","Matsui"),("河野","Kōno"),
 ("市川","Ichikawa"),("渡部","Watanabe"),("野村","Nomura"),("菊地","Kikuchi"),("木下","Kinoshita"),
]

def norm(s):
    """Fold macrons and long-vowel spellings so Satō / Satou / Sato all compare equal."""
    s = unicodedata.normalize("NFD", s)
    s = "".join(c for c in s if unicodedata.category(c) != "Mn").lower()
    return s.replace("ou", "o").replace("oo", "o").replace("uu", "u").replace("ee", "e")

d = json.load(open("jmnedict_index.json", encoding="utf-8"))
idx, rom = d["index"], d["romaji"]

out, unmatched = [], []
for rank, (kanji, wiki_romaji) in enumerate(WIKI, 1):
    entry = idx.get(kanji, {})
    hits = [r for r, types in entry.items()
            if "surname" in types and norm(rom.get(kanji, {}).get(r, "")) == norm(wiki_romaji)]
    if not hits:
        unmatched.append((kanji, wiki_romaji, list(entry)[:5]))
        continue
    reading = min(hits, key=len)          # shortest attested spelling of that romanization
    out.append({"kanji": kanji, "reading": reading,
                "romaji": rom[kanji][reading], "type": "surname", "rank": rank})

json.dump(out, open("surnames.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"verified by both sources : {len(out)}/100")
print(f"unmatched                : {len(unmatched)}")
for k, r, cand in unmatched:
    print(f"   {k} (wiki {r}) jmnedict has {cand}")
