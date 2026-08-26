// Static data source containing all hiragana and katakana characters with their accepted
// romanization variants. Used by KanaSRSStore to seed the kana practice database on first launch.
import Foundation

struct KanaEntry {
    let character: String
    let romaji: [String]
}

enum KanaData {
    static let allHiragana: [KanaEntry] = [
        // Vowels
        .init(character: "あ", romaji: ["a"]),
        .init(character: "い", romaji: ["i"]),
        .init(character: "う", romaji: ["u"]),
        .init(character: "え", romaji: ["e"]),
        .init(character: "お", romaji: ["o"]),
        // K
        .init(character: "か", romaji: ["ka"]),
        .init(character: "き", romaji: ["ki"]),
        .init(character: "く", romaji: ["ku"]),
        .init(character: "け", romaji: ["ke"]),
        .init(character: "こ", romaji: ["ko"]),
        // S
        .init(character: "さ", romaji: ["sa"]),
        .init(character: "し", romaji: ["shi", "si"]),
        .init(character: "す", romaji: ["su"]),
        .init(character: "せ", romaji: ["se"]),
        .init(character: "そ", romaji: ["so"]),
        // T
        .init(character: "た", romaji: ["ta"]),
        .init(character: "ち", romaji: ["chi", "ti"]),
        .init(character: "つ", romaji: ["tsu", "tu"]),
        .init(character: "て", romaji: ["te"]),
        .init(character: "と", romaji: ["to"]),
        // N
        .init(character: "な", romaji: ["na"]),
        .init(character: "に", romaji: ["ni"]),
        .init(character: "ぬ", romaji: ["nu"]),
        .init(character: "ね", romaji: ["ne"]),
        .init(character: "の", romaji: ["no"]),
        // H
        .init(character: "は", romaji: ["ha"]),
        .init(character: "ひ", romaji: ["hi"]),
        .init(character: "ふ", romaji: ["fu", "hu"]),
        .init(character: "へ", romaji: ["he"]),
        .init(character: "ほ", romaji: ["ho"]),
        // M
        .init(character: "ま", romaji: ["ma"]),
        .init(character: "み", romaji: ["mi"]),
        .init(character: "む", romaji: ["mu"]),
        .init(character: "め", romaji: ["me"]),
        .init(character: "も", romaji: ["mo"]),
        // Y
        .init(character: "や", romaji: ["ya"]),
        .init(character: "ゆ", romaji: ["yu"]),
        .init(character: "よ", romaji: ["yo"]),
        // R
        .init(character: "ら", romaji: ["ra"]),
        .init(character: "り", romaji: ["ri"]),
        .init(character: "る", romaji: ["ru"]),
        .init(character: "れ", romaji: ["re"]),
        .init(character: "ろ", romaji: ["ro"]),
        // W + N
        .init(character: "わ", romaji: ["wa"]),
        .init(character: "を", romaji: ["wo", "o"]),
        .init(character: "ん", romaji: ["n", "nn"]),
        // Dakuten G
        .init(character: "が", romaji: ["ga"]),
        .init(character: "ぎ", romaji: ["gi"]),
        .init(character: "ぐ", romaji: ["gu"]),
        .init(character: "げ", romaji: ["ge"]),
        .init(character: "ご", romaji: ["go"]),
        // Dakuten Z
        .init(character: "ざ", romaji: ["za"]),
        .init(character: "じ", romaji: ["ji", "zi"]),
        .init(character: "ず", romaji: ["zu"]),
        .init(character: "ぜ", romaji: ["ze"]),
        .init(character: "ぞ", romaji: ["zo"]),
        // Dakuten D
        .init(character: "だ", romaji: ["da"]),
        .init(character: "ぢ", romaji: ["di", "ji"]),
        .init(character: "づ", romaji: ["du", "zu"]),
        .init(character: "で", romaji: ["de"]),
        .init(character: "ど", romaji: ["do"]),
        // Dakuten B
        .init(character: "ば", romaji: ["ba"]),
        .init(character: "び", romaji: ["bi"]),
        .init(character: "ぶ", romaji: ["bu"]),
        .init(character: "べ", romaji: ["be"]),
        .init(character: "ぼ", romaji: ["bo"]),
        // Handakuten P
        .init(character: "ぱ", romaji: ["pa"]),
        .init(character: "ぴ", romaji: ["pi"]),
        .init(character: "ぷ", romaji: ["pu"]),
        .init(character: "ぺ", romaji: ["pe"]),
        .init(character: "ぽ", romaji: ["po"]),
        // Combinations
        .init(character: "きゃ", romaji: ["kya"]),
        .init(character: "きゅ", romaji: ["kyu"]),
        .init(character: "きょ", romaji: ["kyo"]),
        .init(character: "しゃ", romaji: ["sha", "sya"]),
        .init(character: "しゅ", romaji: ["shu", "syu"]),
        .init(character: "しょ", romaji: ["sho", "syo"]),
        .init(character: "ちゃ", romaji: ["cha", "tya"]),
        .init(character: "ちゅ", romaji: ["chu", "tyu"]),
        .init(character: "ちょ", romaji: ["cho", "tyo"]),
        .init(character: "にゃ", romaji: ["nya"]),
        .init(character: "にゅ", romaji: ["nyu"]),
        .init(character: "にょ", romaji: ["nyo"]),
        .init(character: "ひゃ", romaji: ["hya"]),
        .init(character: "ひゅ", romaji: ["hyu"]),
        .init(character: "ひょ", romaji: ["hyo"]),
        .init(character: "みゃ", romaji: ["mya"]),
        .init(character: "みゅ", romaji: ["myu"]),
        .init(character: "みょ", romaji: ["myo"]),
        .init(character: "りゃ", romaji: ["rya"]),
        .init(character: "りゅ", romaji: ["ryu"]),
        .init(character: "りょ", romaji: ["ryo"]),
        .init(character: "ぎゃ", romaji: ["gya"]),
        .init(character: "ぎゅ", romaji: ["gyu"]),
        .init(character: "ぎょ", romaji: ["gyo"]),
        .init(character: "じゃ", romaji: ["ja", "jya"]),
        .init(character: "じゅ", romaji: ["ju", "jyu"]),
        .init(character: "じょ", romaji: ["jo", "jyo"]),
        .init(character: "びゃ", romaji: ["bya"]),
        .init(character: "びゅ", romaji: ["byu"]),
        .init(character: "びょ", romaji: ["byo"]),
        .init(character: "ぴゃ", romaji: ["pya"]),
        .init(character: "ぴゅ", romaji: ["pyu"]),
        .init(character: "ぴょ", romaji: ["pyo"]),
    ]

    static let allKatakana: [KanaEntry] = [
        // Vowels
        .init(character: "ア", romaji: ["a"]),
        .init(character: "イ", romaji: ["i"]),
        .init(character: "ウ", romaji: ["u"]),
        .init(character: "エ", romaji: ["e"]),
        .init(character: "オ", romaji: ["o"]),
        // K
        .init(character: "カ", romaji: ["ka"]),
        .init(character: "キ", romaji: ["ki"]),
        .init(character: "ク", romaji: ["ku"]),
        .init(character: "ケ", romaji: ["ke"]),
        .init(character: "コ", romaji: ["ko"]),
        // S
        .init(character: "サ", romaji: ["sa"]),
        .init(character: "シ", romaji: ["shi", "si"]),
        .init(character: "ス", romaji: ["su"]),
        .init(character: "セ", romaji: ["se"]),
        .init(character: "ソ", romaji: ["so"]),
        // T
        .init(character: "タ", romaji: ["ta"]),
        .init(character: "チ", romaji: ["chi", "ti"]),
        .init(character: "ツ", romaji: ["tsu", "tu"]),
        .init(character: "テ", romaji: ["te"]),
        .init(character: "ト", romaji: ["to"]),
        // N
        .init(character: "ナ", romaji: ["na"]),
        .init(character: "ニ", romaji: ["ni"]),
        .init(character: "ヌ", romaji: ["nu"]),
        .init(character: "ネ", romaji: ["ne"]),
        .init(character: "ノ", romaji: ["no"]),
        // H
        .init(character: "ハ", romaji: ["ha"]),
        .init(character: "ヒ", romaji: ["hi"]),
        .init(character: "フ", romaji: ["fu", "hu"]),
        .init(character: "ヘ", romaji: ["he"]),
        .init(character: "ホ", romaji: ["ho"]),
        // M
        .init(character: "マ", romaji: ["ma"]),
        .init(character: "ミ", romaji: ["mi"]),
        .init(character: "ム", romaji: ["mu"]),
        .init(character: "メ", romaji: ["me"]),
        .init(character: "モ", romaji: ["mo"]),
        // Y
        .init(character: "ヤ", romaji: ["ya"]),
        .init(character: "ユ", romaji: ["yu"]),
        .init(character: "ヨ", romaji: ["yo"]),
        // R
        .init(character: "ラ", romaji: ["ra"]),
        .init(character: "リ", romaji: ["ri"]),
        .init(character: "ル", romaji: ["ru"]),
        .init(character: "レ", romaji: ["re"]),
        .init(character: "ロ", romaji: ["ro"]),
        // W + N
        .init(character: "ワ", romaji: ["wa"]),
        .init(character: "ヲ", romaji: ["wo", "o"]),
        .init(character: "ン", romaji: ["n", "nn"]),
        // Dakuten G
        .init(character: "ガ", romaji: ["ga"]),
        .init(character: "ギ", romaji: ["gi"]),
        .init(character: "グ", romaji: ["gu"]),
        .init(character: "ゲ", romaji: ["ge"]),
        .init(character: "ゴ", romaji: ["go"]),
        // Dakuten Z
        .init(character: "ザ", romaji: ["za"]),
        .init(character: "ジ", romaji: ["ji", "zi"]),
        .init(character: "ズ", romaji: ["zu"]),
        .init(character: "ゼ", romaji: ["ze"]),
        .init(character: "ゾ", romaji: ["zo"]),
        // Dakuten D
        .init(character: "ダ", romaji: ["da"]),
        .init(character: "ヂ", romaji: ["di", "ji"]),
        .init(character: "ヅ", romaji: ["du", "zu"]),
        .init(character: "デ", romaji: ["de"]),
        .init(character: "ド", romaji: ["do"]),
        // Dakuten B
        .init(character: "バ", romaji: ["ba"]),
        .init(character: "ビ", romaji: ["bi"]),
        .init(character: "ブ", romaji: ["bu"]),
        .init(character: "ベ", romaji: ["be"]),
        .init(character: "ボ", romaji: ["bo"]),
        // Handakuten P
        .init(character: "パ", romaji: ["pa"]),
        .init(character: "ピ", romaji: ["pi"]),
        .init(character: "プ", romaji: ["pu"]),
        .init(character: "ペ", romaji: ["pe"]),
        .init(character: "ポ", romaji: ["po"]),
        // Combinations
        .init(character: "キャ", romaji: ["kya"]),
        .init(character: "キュ", romaji: ["kyu"]),
        .init(character: "キョ", romaji: ["kyo"]),
        .init(character: "シャ", romaji: ["sha", "sya"]),
        .init(character: "シュ", romaji: ["shu", "syu"]),
        .init(character: "ショ", romaji: ["sho", "syo"]),
        .init(character: "チャ", romaji: ["cha", "tya"]),
        .init(character: "チュ", romaji: ["chu", "tyu"]),
        .init(character: "チョ", romaji: ["cho", "tyo"]),
        .init(character: "ニャ", romaji: ["nya"]),
        .init(character: "ニュ", romaji: ["nyu"]),
        .init(character: "ニョ", romaji: ["nyo"]),
        .init(character: "ヒャ", romaji: ["hya"]),
        .init(character: "ヒュ", romaji: ["hyu"]),
        .init(character: "ヒョ", romaji: ["hyo"]),
        .init(character: "ミャ", romaji: ["mya"]),
        .init(character: "ミュ", romaji: ["myu"]),
        .init(character: "ミョ", romaji: ["myo"]),
        .init(character: "リャ", romaji: ["rya"]),
        .init(character: "リュ", romaji: ["ryu"]),
        .init(character: "リョ", romaji: ["ryo"]),
        .init(character: "ギャ", romaji: ["gya"]),
        .init(character: "ギュ", romaji: ["gyu"]),
        .init(character: "ギョ", romaji: ["gyo"]),
        .init(character: "ジャ", romaji: ["ja", "jya"]),
        .init(character: "ジュ", romaji: ["ju", "jyu"]),
        .init(character: "ジョ", romaji: ["jo", "jyo"]),
        .init(character: "ビャ", romaji: ["bya"]),
        .init(character: "ビュ", romaji: ["byu"]),
        .init(character: "ビョ", romaji: ["byo"]),
        .init(character: "ピャ", romaji: ["pya"]),
        .init(character: "ピュ", romaji: ["pyu"]),
        .init(character: "ピョ", romaji: ["pyo"]),
    ]

    static func romaji(for character: String) -> [String] {
        (allHiragana + allKatakana).first(where: { $0.character == character })?.romaji ?? []
    }

    static func primaryRomaji(for character: String) -> String {
        romaji(for: character).first ?? "?"
    }
}
