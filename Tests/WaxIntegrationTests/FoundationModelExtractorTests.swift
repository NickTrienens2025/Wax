import Testing
@testable import Wax
@testable import WaxCore

struct FoundationModelExtractorTests {

    // MARK: - Availability

    @Test("extractor reports isAvailable without crashing on any platform")
    func extractorReportsAvailabilityWithoutCrashing() {
        let extractor = FoundationModelExtractor()
        // Merely reading the property must not crash on any supported OS
        _ = extractor.isAvailable
    }

    // MARK: - Unavailable / stub path

    @Test("NoOpExtractor always returns an empty result")
    func unavailableExtractorReturnsEmpty() async throws {
        let extractor = NoOpExtractor()
        let result = try await extractor.extract(from: "Chris prefers Swift")
        #expect(result.isEmpty)
    }

    @Test("FoundationModelExtractor returns empty result when unavailable")
    func foundationModelExtractorReturnsEmptyWhenUnavailable() async throws {
        let extractor = FoundationModelExtractor()
        guard !extractor.isAvailable else { return }
        let result = try await extractor.extract(from: "Chris prefers Swift")
        #expect(result.isEmpty)
    }

    // MARK: - Available path (skipped when Foundation Models not present)

    @Test(
        "available extractor extracts at least one entity from a clear statement",
        .enabled(if: FoundationModelExtractor().isAvailable)
    )
    func availableExtractorExtractsEntities() async throws {
        let extractor = FoundationModelExtractor()
        let result = try await extractor.extract(
            from: "Chris prefers guard clauses for error handling."
        )
        #expect(!result.isEmpty)
    }

    @Test(
        "available extractor extracts at least one fact from a clear statement",
        .enabled(if: FoundationModelExtractor().isAvailable)
    )
    func availableExtractorExtractsFacts() async throws {
        let extractor = FoundationModelExtractor()
        let result = try await extractor.extract(
            from: "Alice works on the Wax project using Swift."
        )
        #expect(!result.facts.isEmpty || !result.entities.isEmpty)
    }

    // MARK: - ExtractionResult semantics

    @Test("ExtractionResult isEmpty when both entities and facts are empty")
    func extractionResultIsEmptyWhenBothEmpty() {
        let result = ExtractionResult(entities: [], facts: [])
        #expect(result.isEmpty)
    }

    @Test("ExtractionResult is not empty when entities present")
    func extractionResultNotEmptyWithEntities() {
        let entity = ExtractedEntity(
            key: EntityKey("person:chris"),
            kind: "person",
            aliases: ["Chris"]
        )
        let result = ExtractionResult(entities: [entity], facts: [])
        #expect(!result.isEmpty)
    }

    @Test("ExtractionResult is not empty when facts present")
    func extractionResultNotEmptyWithFacts() {
        let fact = ExtractedFact(
            subject: EntityKey("person:chris"),
            predicate: PredicateKey("prefers"),
            object: .string("Swift"),
            confidence: nil
        )
        let result = ExtractionResult(entities: [], facts: [fact])
        #expect(!result.isEmpty)
    }

    // MARK: - Protocol conformance via existential

    @Test("EntityExtractor existential accepts NoOpExtractor and FoundationModelExtractor")
    func protocolExistentialConformance() {
        let extractors: [any EntityExtractor] = [
            NoOpExtractor(),
            FoundationModelExtractor(),
        ]
        for extractor in extractors {
            _ = extractor.isAvailable
        }
    }
}
