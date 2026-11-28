import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

public protocol MemorySemanticMatcher: Sendable {
    /// Returns a cosine distance in [0, 2], or nil when local embeddings are unavailable.
    func distance(query: String, note: String) -> Double?
}

/// Uses the OS-provided sentence embedding when available. This implementation
/// makes no app network requests or off-device calls; callers fall back to lexical search.
public struct OnDeviceMemorySemanticMatcher: MemorySemanticMatcher {
    public init() {}

    public func distance(query: String, note: String) -> Double? {
        #if canImport(NaturalLanguage)
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else { return nil }
        let value = embedding.distance(between: query, and: note, distanceType: .cosine)
        return value.isFinite && (0...2).contains(value) ? value : nil
        #else
        return nil
        #endif
    }
}

enum MemoryRetrieval {
    // Cosine distance is 0 for identical sentences; larger values are less similar.
    // Keep the semantic threshold conservative to avoid injecting unrelated notes.
    static let maximumSemanticDistance = 0.45

    private static let stopWords: Set<String> = [
        "about", "after", "again", "also", "answer", "are", "can", "could", "describe",
        "does", "explain", "from", "give", "have", "how", "into", "just", "make", "please",
        "show", "some", "that", "the", "their", "them", "then", "there", "these", "this",
        "those", "through", "what", "when", "where", "which", "while", "with", "would", "your"
    ]

    static func lexicalQueryTerms(_ text: String) -> Set<String> {
        Set(tokens(text).filter { $0.count > 2 && !stopWords.contains($0) })
    }

    static func lexicalCoverage(terms: Set<String>, note: String) -> Double {
        guard !terms.isEmpty else { return 0 }
        return Double(terms.intersection(tokens(note)).count) / Double(terms.count)
    }

    static func rank(
        query: String,
        notes: [Note],
        semanticDistance: (String, String) -> Double? = { _, _ in nil }
    ) -> [Note] {
        let queryTerms = lexicalQueryTerms(query)
        guard !queryTerms.isEmpty else { return [] }

        return notes.enumerated().compactMap { index, note -> (note: Note, score: Double, recency: Int)? in
            let lexical = lexicalCoverage(terms: queryTerms, note: note.text)
            let distance = semanticDistance(query, note.text)
            let semantic: Double
            if let distance, distance.isFinite, (0...maximumSemanticDistance).contains(distance) {
                semantic = 0.5 * (1 - distance / maximumSemanticDistance)
            } else {
                semantic = 0
            }
            let score = max(lexical, semantic)
            guard score > 0 else { return nil }
            return (note, score, index)
        }
        .sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.recency < $1.recency
        }
        .map(\.note)
    }

    private static func tokens(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }
}

enum RequestToolPolicy {
    private static let toolDenyPatterns = [
        #"\b(?:do\s+not|don't|dont|never|without)\s+(?:(?:use|using|run|call|invoke)\s+)?(?:any\s+)?tools?\b"#,
        #"\bno\s+tools?\b"#
    ]

    static func deniesTools(in request: String) -> Bool {
        let normalized = request.replacingOccurrences(of: "’", with: "'")
        return toolDenyPatterns.contains { normalized.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }

    static func deniesMemory(in request: String) -> Bool {
        let normalized = request.replacingOccurrences(of: "’", with: "'")
        let patterns = [
            #"\b(?:do\s+not|don't|dont|never|without)\s+(?:(?:use|using|access|search|consult|read|rely\s+on)\s+)?(?:any\s+)?(?:tools?\s+(?:and|or)\s+)?(?:memory|memories)\b"#,
            #"\bno\s+(?:memory|memories)\b"#
        ]
        return patterns.contains { normalized.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }
}
