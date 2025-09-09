//
//  AIService.swift
//  Fathom
//
//  Created by Cascade on 9/8/25.
//

import Foundation
import NaturalLanguage

// MARK: - AI Abstractions

@MainActor
protocol AIService: AnyObject {
    func summarizeJournal(text: String, maxCharacters: Int) async throws -> String
    func rewriteInsight(message: String, styleHint: String?) async throws -> String
}

// MARK: - On-device Fallback (no network, privacy-first)

@MainActor
final class OnDeviceAIService: AIService {
    func summarizeJournal(text: String, maxCharacters: Int) async throws -> String {
        // Extractive summarization: rank sentences by keyword frequency and sentiment, then select best in original order.
        let sentences = Self.splitIntoSentences(text)
        guard !sentences.isEmpty else { return "" }

        // Build token frequency excluding stopwords
        let stopwords: Set<String> = [
            "the","a","an","and","or","but","if","while","with","to","of","in","on","for","at","by","from","as","that","this","it","is","was","are","be","been","i","we","you","they","he","she","my","our","your","their","me","us","them"
        ]
        let tokenizer = NLTokenizer(unit: .word)
        let lower = text.lowercased()
        tokenizer.string = lower
        var freq: [String:Int] = [:]
        tokenizer.enumerateTokens(in: lower.startIndex..<lower.endIndex) { range, _ in
            let token = String(lower[range]).trimmingCharacters(in: .alphanumerics.inverted)
            guard token.count > 1, !stopwords.contains(token) else { return true }
            freq[token, default: 0] += 1
            return true
        }

        // Sentiment score per sentence
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        var scored: [(index: Int, sentence: String, score: Double)] = []
        for (i, s) in sentences.enumerated() {
            // Keyword score
            let words = s.lowercased().split{ !$0.isLetter }
            var wordScore = 0.0
            for w in words { wordScore += Double(freq[String(w)] ?? 0) }
            // Sentiment (range roughly -1...1)
            tagger.string = s
            let raw = tagger.tag(at: s.startIndex, unit: .paragraph, scheme: .sentimentScore).0?.rawValue ?? "0"
            let sentiment = Double(raw) ?? 0
            // Length normalization favors concise sentences
            let lengthPenalty = max(1.0, Double(s.count) / 120.0)
            let total = (wordScore * 1.0 + sentiment * 2.0) / lengthPenalty
            scored.append((i, s, total))
        }

        // Pick top N sentences within the character budget, preserving original order
        let topCount = min(4, max(2, sentences.count / 3))
        let topSorted = scored.sorted { $0.score > $1.score }.prefix(topCount).sorted { $0.index < $1.index }
        var assembled = topSorted.map { $0.sentence }

        // Light compression: remove common fillers
        assembled = assembled.map { s in
            var t = s.replacingOccurrences(of: "I think ", with: "")
            t = t.replacingOccurrences(of: "I feel ", with: "")
            t = t.replacingOccurrences(of: "In my opinion, ", with: "")
            return t
        }

        var result = assembled.joined(separator: " ")
        if result.count > maxCharacters {
            // Trim at sentence boundary if possible
            while result.count > maxCharacters, assembled.count > 1 {
                assembled.removeLast()
                result = assembled.joined(separator: " ")
            }
            if result.count > maxCharacters { result = String(result.prefix(maxCharacters)) + "…" }
        }
        return result
    }

    func rewriteInsight(message: String, styleHint: String?) async throws -> String {
        // Minimal on-device rewrite: add a hint prefix and ensure active voice.
        let prefix: String
        switch styleHint?.lowercased() {
        case "stress": prefix = "For stress relief, "
        case "productivity": prefix = "To boost productivity, "
        case "connection": prefix = "For better connection, "
        case "mindfulness": prefix = "To cultivate mindfulness, "
        default: prefix = ""
        }
        let rewritten = message.replacingOccurrences(of: "Consider ", with: "Try ")
        return prefix + rewritten
    }

    private static func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let s = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { sentences.append(s) }
            return true
        }
        return sentences
    }
}

// MARK: - Firebase Vertex AI (remote, higher-quality)

#if canImport(FirebaseVertexAI)
import FirebaseVertexAI

@MainActor
final class VertexAIService: AIService {
    private let modelName: String
    private let model: GenerativeModel
    private let onDeviceFallback = OnDeviceAIService()

    init(modelName: String = "gemini-1.5-pro") {
        self.modelName = modelName
        // Create a Vertex AI GenerativeModel instance (FirebaseApp.configure() is called at app startup)
        self.model = VertexAI.vertexAI().generativeModel(modelName: modelName)
    }

    func summarizeJournal(text: String, maxCharacters: Int) async throws -> String {
        let prompt = """
        Summarize the following workplace journal entry in no more than \(maxCharacters) characters.
        Focus on key takeaways and an actionable suggestion. Avoid emojis and names.

        Journal entry:
        \(text)
        """
        do {
            let response = try await model.generateContent(prompt)
            let output = response.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if output.isEmpty {
                return try await onDeviceFallback.summarizeJournal(text: text, maxCharacters: maxCharacters)
            }
            return output.count > maxCharacters ? String(output.prefix(maxCharacters)) + "…" : output
        } catch {
            return try await onDeviceFallback.summarizeJournal(text: text, maxCharacters: maxCharacters)
        }
    }

    func rewriteInsight(message: String, styleHint: String?) async throws -> String {
        let hint = (styleHint ?? "productivity").lowercased()
        let prompt = """
        Rewrite the following insight in a concise, encouraging tone optimized for \(hint).
        Keep it a single sentence under 160 characters. Avoid emojis and names.

        Insight:
        \(message)
        """
        do {
            let response = try await model.generateContent(prompt)
            let output = response.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return output.isEmpty ? message : output
        } catch {
            return message
        }
    }
}
#endif

// MARK: - Factory

@MainActor
enum AIServiceFactory {
    static func make() -> AIService {
        #if canImport(FirebaseVertexAI)
        // Return a gated service that respects user opt-in and Remote Config flags
        return GatedAIService(remote: VertexAIService(), local: OnDeviceAIService())
        #else
        return OnDeviceAIService()
        #endif
    }
}

// MARK: - Gated service that checks AIFeatureGate per-call
@MainActor
final class GatedAIService: AIService {
    private let remote: AIService
    private let local: AIService
    private var gate: AIFeatureGate { AIFeatureGate.shared }

    init(remote: AIService, local: AIService) {
        self.remote = remote
        self.local = local
    }

    func summarizeJournal(text: String, maxCharacters: Int) async throws -> String {
        let start = Date()
        let inputChars = text.count
        var source = "local"
        let output: String
        if gate.allowsCloudSummarization {
            do {
                output = try await remote.summarizeJournal(text: text, maxCharacters: maxCharacters)
                source = "cloud"
            } catch {
                output = try await local.summarizeJournal(text: text, maxCharacters: maxCharacters)
                source = "local"
            }
        } else {
            output = try await local.summarizeJournal(text: text, maxCharacters: maxCharacters)
            source = "local"
        }
        let durationMs = Int(Date().timeIntervalSince(start) * 1000)
        AnalyticsService.shared.logEvent("ai_summarize", parameters: [
            "source": source,
            "duration_ms": durationMs,
            "input_chars": inputChars,
            "output_chars": output.count
        ])
        return output
    }

    func rewriteInsight(message: String, styleHint: String?) async throws -> String {
        let start = Date()
        var source = "local"
        let output: String
        if gate.allowsCloudRewrite {
            do {
                output = try await remote.rewriteInsight(message: message, styleHint: styleHint)
                source = "cloud"
            } catch {
                output = try await local.rewriteInsight(message: message, styleHint: styleHint)
                source = "local"
            }
        } else {
            output = try await local.rewriteInsight(message: message, styleHint: styleHint)
            source = "local"
        }
        let durationMs = Int(Date().timeIntervalSince(start) * 1000)
        AnalyticsService.shared.logEvent("ai_rewrite", parameters: [
            "source": source,
            "duration_ms": durationMs,
            "message_chars": message.count,
            "output_chars": output.count,
            "style_hint": styleHint ?? ""
        ])
        return output
    }
}
