import Foundation
import NaturalLanguage

private struct Group: Decodable {
    struct Candidate: Decodable {
        let id: String
        let text: String
    }
    let query: String
    let candidates: [Candidate]
}

private func number(_ value: Double?) -> Any {
    if let value, value.isFinite { return value }
    return NSNull()
}

private func normalized(_ text: String) -> String {
    text.precomposedStringWithCanonicalMapping
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
}

private func cosineDistance(_ a: [Double]?, _ b: [Double]?) -> Double? {
    guard let a, let b, !a.isEmpty, a.count == b.count else { return nil }
    var dot = 0.0, a2 = 0.0, b2 = 0.0
    for (x, y) in zip(a, b) {
        dot += x * y
        a2 += x * x
        b2 += y * y
    }
    let norm = sqrt(a2) * sqrt(b2)
    guard norm.isFinite, norm > 0, dot.isFinite else { return nil }
    return 1 - min(1, max(-1, dot / norm))
}

@main struct MeasureNative {
    static func main() throws {
        let groups = try JSONDecoder().decode(
            [Group].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        )
        let model = NLEmbedding.sentenceEmbedding(for: .english)
        let matcher = OnDeviceMemorySemanticMatcher()
        var rows: [[String: Any]] = []
        for group in groups {
            let queryVector = model?.vector(for: group.query)
            let terms = MemoryRetrieval.lexicalQueryTerms(group.query)
            for candidate in group.candidates {
                let noteVector = model?.vector(for: candidate.text)
                let raw = model?.distance(between: group.query, and: candidate.text, distanceType: .cosine)
                let clean = matcher.distance(query: normalized(group.query), note: normalized(candidate.text))
                rows.append([
                    "id": candidate.id,
                    "lexical": MemoryRetrieval.lexicalCoverage(terms: terms, note: candidate.text),
                    "distance": number(matcher.distance(query: group.query, note: candidate.text)),
                    "framework_raw": number(raw),
                    "cosine_from_vectors": number(cosineDistance(queryVector, noteVector)),
                    "normalized": number(clean),
                    "query_vector": queryVector != nil,
                    "note_vector": noteVector != nil
                ])
            }
        }
        var metadata: [String: Any] = [
            "available": model != nil,
            "supported_revisions": Array(NLEmbedding.supportedSentenceEmbeddingRevisions(for: .english)),
            "current_revision": NLEmbedding.currentSentenceEmbeddingRevision(for: .english),
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "language": "en",
            "metric": "cosine",
            "self_distance": number(matcher.distance(query: groups[0].query, note: groups[0].query))
        ]
        if let model {
            metadata["revision"] = model.revision
            metadata["dimension"] = model.dimension
        }
        let data = try JSONSerialization.data(withJSONObject: ["metadata": metadata, "rows": rows], options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]), options: .atomic)
    }
}
