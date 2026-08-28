#!/usr/bin/env python3
"""
Split a name's reading across its kanji.

Enumerates every split the readings allow, then scores them, because a greedy
longest-match gets 渡辺 wrong (渡=わたな instead of 渡=わた + 辺=なべ).

Handles the things names do that dictionary readings don't cover:
  rendaku   second element voices its first mora   山田 やま + た -> だ
  sokuon    final mora becomes っ
  の linker surnames insert a possessive の        木下 き + の + した
  々        iteration mark repeats the previous kanji   佐々木
"""
import json, functools

R = json.load(open("kanji_readings.json", encoding="utf-8"))

RENDAKU = {"か":"が","き":"ぎ","く":"ぐ","け":"げ","こ":"ご","さ":"ざ","し":"じ","す":"ず",
           "せ":"ぜ","そ":"ぞ","た":"だ","ち":"ぢ","つ":"づ","て":"で","と":"ど",
           "は":"ば","ひ":"び","ふ":"ぶ","へ":"べ","ほ":"ぼ"}
HANDAKU = {"は":"ぱ","ひ":"ぴ","ふ":"ぷ","へ":"ぺ","ほ":"ぽ"}

# Lower is preferred: everyday readings before name-only ones.
COST = {"kun": 0, "on": 1, "nanori": 3}
MAX_COST = 8   # above this the split is guesswork; emit nothing instead


def candidates(ch, is_first):
    """(surface form, cost) pairs for one kanji in a compound."""
    seen = {}
    for kind, cost in COST.items():
        for r in R.get(ch, {}).get(kind, []):
            forms = {(r, cost)}
            if not is_first and r:
                h, t = r[0], r[1:]
                if h in RENDAKU: forms.add((RENDAKU[h] + t, cost + 1))
                if h in HANDAKU: forms.add((HANDAKU[h] + t, cost + 1))
            if len(r) > 1:
                forms.add((r[:-1] + "っ", cost + 1))
            for f, c in forms:
                if f and (f not in seen or c < seen[f]):
                    seen[f] = c
    return sorted(seen.items(), key=lambda x: (-len(x[0]), x[1]))


def segment(kanji, reading):
    chars = []
    for i, c in enumerate(kanji):
        chars.append(chars[-1] if c == "々" and i else c)   # 々 repeats the previous kanji

    @functools.lru_cache(maxsize=None)
    def walk(i, pos):
        """-> (cost, segments) best split of chars[i:] against reading[pos:]"""
        if i == len(chars):
            return (0, ()) if pos == len(reading) else None
        ch = chars[i]
        best = None
        if ch not in R:                                       # literal kana in the name
            if reading.startswith(ch, pos):
                sub = walk(i + 1, pos + len(ch))
                if sub: best = (sub[0], ((ch, ch),) + sub[1])
            return best
        for form, cost in candidates(ch, i == 0):
            for linker in ("", "の"):                          # optional possessive の after this element
                surface = form + linker
                if not reading.startswith(surface, pos):
                    continue
                sub = walk(i + 1, pos + len(surface))
                if sub is None:
                    continue
                # Weight earlier positions harder: the first element is normally the base
                # morpheme, so a name-only reading there is more suspect than one later.
                # Without this, 渡辺 ties between 渡=わたな/辺=べ and the correct 渡=わた/辺=なべ.
                total = cost * (len(chars) - i) + sub[0] + (2 if linker else 0)
                cand = (total, ((kanji[i], surface),) + sub[1])
                if best is None or cand[0] < best[0]:
                    best = cand
        return best

    got = walk(0, 0)
    if got is None:
        return None
    # A high-cost split means the reading was only explained by stacking rare name-only
    # readings, which is where wrong splits come from. Better to show no breakdown than
    # to teach a bad one.
    if got[0] > MAX_COST:
        return None
    return [{"kanji": k, "reading": r} for k, r in got[1]]


if __name__ == "__main__":
    tests = [("田中","たなか"),("山田","やまだ"),("佐藤","さとう"),("長谷川","はせがわ"),
             ("小林","こばやし"),("渡辺","わたなべ"),("木下","きのした"),("佐々木","ささき"),
             ("井上","いのうえ"),("健太","けんた"),("太郎","たろう"),("清水","しみず")]
    for k, r in tests:
        s = segment(k, r)
        shown = " / ".join(x["kanji"] + "=" + x["reading"] for x in s) if s else "NO SPLIT"
        print("  %-5s %-8s -> %s" % (k, r, shown))
