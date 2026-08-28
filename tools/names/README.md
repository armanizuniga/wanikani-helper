# Name data pipeline

Builds `WaniKaniHelper/WaniKaniHelper/japanese_names.json`, the bundled name list behind
Name Practice. Nothing here runs in the app; it's an offline pipeline you re-run only when
you want to extend or refresh the list.

## Why it works this way

Name readings can't be derived. 中 is `なか` in 田中 but `ちゅう` elsewhere, and 愛 alone has
52 attested readings, so a name assembled at runtime could never be quizzed with a single
correct answer. Every name ships with one reading, confirmed by two independent sources:

- **A published frequency ranking** supplies the candidate name and the reading people
  actually use. `build_surnames.py` carries the top 100 surnames inline; `build_given.py`
  carries a curated given-name list.
- **JMnedict** confirms that reading is genuinely attested for that spelling. It can't be
  used alone: it lists 佐藤 as さいう / さとあ / さどう alongside さとう with no frequency
  information, so it says what is *valid*, never what is *common*.

Given names are deliberately limited to multi-kanji names with conventional endings
(-太, -也, -樹, -子, -織). Single-kanji given names are excluded on purpose — they're the
ones with a dozen-plus readings and no dominant one.

## Running it

```bash
cd tools/names
curl -O http://ftp.edrdg.org/pub/Nihongo/JMnedict.xml.gz && gunzip -k JMnedict.xml.gz
curl -O http://www.edrdg.org/kanjidic/kanjidic2.xml.gz && gunzip -k kanjidic2.xml.gz

python3 parse_jmnedict.py     # -> jmnedict_index.json   (kanji -> readings -> name types)
python3 kanji_readings.py     # -> kanji_readings.json   (kanji -> kun/on/nanori)
python3 build_surnames.py     # -> surnames.json         (ranking x JMnedict)
python3 build_given.py        # -> given.json            (curated x JMnedict)
python3 build_names.py        # -> japanese_names.json   (+ per-kanji segments)

cp japanese_names.json ../../WaniKaniHelper/WaniKaniHelper/
```

Only `japanese_names.json` is committed to the app. The two source dictionaries and the
intermediate indexes are large and regenerable, so they're gitignored.

## Segmentation

`segment.py` splits a reading across a name's kanji for the breakdown shown after answering.
It enumerates every split the KANJIDIC2 readings allow and scores them, rather than matching
greedily, and accounts for what names do that dictionary readings don't:

| | |
|---|---|
| rendaku | second element voices its first mora — 山田 やま + た → **だ** |
| sokuon | final mora becomes っ |
| の linker | surnames insert a possessive — 木下 き**の**した |
| 々 | iteration mark repeats the previous kanji — 佐々木 |

Everyday (kun/on) readings are preferred over name-only (nanori) ones, and earlier positions
are weighted more heavily since the first element is usually the base morpheme. Without that
weighting 渡辺 ties between the correct 渡=わた / 辺=なべ and the wrong 渡=わたな / 辺=べ.

Splits above `MAX_COST` are discarded and the name ships with no breakdown. 長谷川 はせがわ is
the usual casualty: 長 = は is irregular enough that any split would be teaching a bad rule.
About 97% of the list segments cleanly.

## Extending the list

Add rows to the `WIKI` table in `build_surnames.py` (kanji, Hepburn romaji — macrons are
folded when matching) or to `M` / `F` in `build_given.py` (kanji, intended reading), then
re-run. Anything JMnedict can't confirm is dropped and reported, so a typo shows up as a
dropped row rather than a wrong reading in the app.

## Licensing

JMnedict and KANJIDIC2 are from [EDRDG](https://www.edrdg.org/) under CC BY-SA 4.0.
Derived data ships with attribution in the app README's Credits section — keep it there.
