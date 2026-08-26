//
//  WaniKaniHelperTests.swift
//  WaniKaniHelperTests
//
//  Created by Armani Zuniga on 5/4/26.
//

import Testing
@testable import WaniKaniHelper

// MARK: - SubjectType

// SubjectType drives two key product decisions:
//   isVocab  → whether to show example sentences, include in sentence generation
//   hasReading → whether to create a reading review card for this subject
//
// kanaVocabulary is the tricky edge case: it IS vocab (so it gets example sentences)
// but has NO reading card (because the word is already written in kana — testing the
// reading would be trivially answerable just by looking at the word itself).
//
// Radicals have no reading for a different reason: they are WaniKani's internal
// building blocks for learning kanji, not real Japanese words, so no reading exists.
//
// These tests ensure all four cases are correct, and that any future change to the
// enum — or a new subject type WaniKani might add — doesn't silently break review
// card generation or sentence generation eligibility.

// MARK: - PromptLibrary

// compose() builds the final system prompt by injecting the vocabulary word into a
// grammar-specific template. The placeholder {{VOCAB_WORD}} must be fully replaced —
// if it isn't, the model receives the literal string "{{VOCAB_WORD}}" and generates
// a sentence about the placeholder instead of the actual vocabulary word.
//
// Two cases: with a reading (kanji vocabulary) and without (kana vocabulary where
// the word is already written in kana and no separate reading exists).

struct PromptLibraryTests {

    // Kanji vocabulary with a reading — wordEntry becomes "食べる (たべる) — to eat"
    @Test func compose_withReading_replacesPlaceholder() {
        let result = PromptLibrary.shared.compose(
            word: "食べる", reading: "たべる", meaning: "to eat", userLevel: 1
        )
        #expect(!result.contains("{{VOCAB_WORD}}"))
        #expect(result.contains("食べる"))
    }

    // Kana vocabulary with no reading — wordEntry becomes "ありがとう — thank you"
    @Test func compose_withoutReading_replacesPlaceholder() {
        let result = PromptLibrary.shared.compose(
            word: "ありがとう", reading: nil, meaning: "thank you", userLevel: 1
        )
        #expect(!result.contains("{{VOCAB_WORD}}"))
        #expect(result.contains("ありがとう"))
    }
}

// MARK: - SubjectType

struct SubjectTypeTests {

    // Radicals are not vocab and have no reading.
    // They exist only as kanji-building components, not reviewable words.
    @Test func radical_isNotVocab() {
        #expect(SubjectType.radical.isVocab == false)
    }

    @Test func radical_hasNoReading() {
        #expect(SubjectType.radical.hasReading == false)
    }

    // Kanji is not vocab but does have a reading.
    // The reading card tests whether the user knows how to pronounce the kanji.
    @Test func kanji_isNotVocab() {
        #expect(SubjectType.kanji.isVocab == false)
    }

    @Test func kanji_hasReading() {
        #expect(SubjectType.kanji.hasReading == true)
    }

    // Regular vocabulary is vocab and has a reading.
    // Both a meaning card and a reading card are generated in review sessions.
    @Test func vocabulary_isVocab() {
        #expect(SubjectType.vocabulary.isVocab == true)
    }

    @Test func vocabulary_hasReading() {
        #expect(SubjectType.vocabulary.hasReading == true)
    }

    // kanaVocabulary is the edge case: it IS vocab (gets example sentences,
    // counts toward learned words) but has NO reading card. The word is already
    // written in hiragana or katakana, so there is no separate reading to quiz —
    // the answer would always just be the word itself.
    @Test func kanaVocabulary_isVocab() {
        #expect(SubjectType.kanaVocabulary.isVocab == true)
    }

    @Test func kanaVocabulary_hasNoReading() {
        #expect(SubjectType.kanaVocabulary.hasReading == false)
    }
}
