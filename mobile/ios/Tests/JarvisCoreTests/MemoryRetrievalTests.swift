import XCTest
@testable import JarvisCore

final class MemoryRetrievalTests: XCTestCase {
    func testSemanticDistanceFindsParaphraseAndRejectsUnrelatedNote() {
        let germination = Note("The sprouting process starts after hydration awakens an embryo.")
        let battery = Note("A battery stores chemical energy and converts it into electrical energy.")
        let ranked = MemoryRetrieval.rank(
            query: "How does germination proceed?",
            notes: [battery, germination],
            semanticDistance: { _, note in note == germination.text ? 0.2 : 0.9 }
        )
        XCTAssertEqual(ranked, [germination])
    }

    func testLexicalSearchRemainsAvailableWhenEmbeddingsAreUnavailable() {
        let germination = Note("Germination begins when a seed absorbs water.")
        let unrelated = Note("A battery stores electrical energy.")
        let ranked = MemoryRetrieval.rank(query: "Explain germination", notes: [unrelated, germination])
        XCTAssertEqual(ranked, [germination])
    }

    func testWeakSemanticMatchesAreNotInjected() {
        let note = Note("A battery stores electrical energy.")
        let ranked = MemoryRetrieval.rank(query: "How does a seed begin growing", notes: [note], semanticDistance: { _, _ in 0.8 })
        XCTAssertTrue(ranked.isEmpty)
    }

    func testExplicitRequestPolicies() {
        let noTools = "Explain how a seed grows. Do not use tools or memory."
        XCTAssertTrue(RequestToolPolicy.deniesTools(in: noTools))
        XCTAssertTrue(RequestToolPolicy.deniesMemory(in: noTools))

        let noMemory = "What time is it? Don't consult memory."
        XCTAssertFalse(RequestToolPolicy.deniesTools(in: noMemory))
        XCTAssertTrue(RequestToolPolicy.deniesMemory(in: noMemory))
        XCTAssertFalse(RequestToolPolicy.deniesTools(in: "What time is it?"))
        XCTAssertFalse(RequestToolPolicy.deniesMemory(in: "What time is it?"))
    }
}

#if canImport(NaturalLanguage)
import NaturalLanguage

final class NativeMemoryEmbeddingTests: XCTestCase {
    func testSentenceEmbeddingRanksSeedGerminationCloserThanBattery() throws {
        let matcher = OnDeviceMemorySemanticMatcher()
        let query = "How does germination proceed?"
        let germination = try XCTUnwrap(matcher.distance(
            query: query,
            note: "The sprouting process starts after hydration awakens an embryo."
        ))
        let battery = try XCTUnwrap(matcher.distance(
            query: query,
            note: "A battery stores chemical energy and converts it into electrical energy."
        ))
        XCTAssertLessThan(germination, battery)
        XCTAssertLessThanOrEqual(germination, MemoryRetrieval.maximumSemanticDistance)
    }
}
#endif
