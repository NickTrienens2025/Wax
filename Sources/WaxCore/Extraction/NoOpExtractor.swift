import Foundation

/// A no-op `EntityExtractor` that always returns an empty `ExtractionResult`.
///
/// Use this as a default/placeholder implementation when no real extractor is
/// available, or in tests where extraction behaviour is not under test.
public struct NoOpExtractor: EntityExtractor {

    public init() {}

    /// Always returns `true` — the no-op extractor has no external dependencies.
    public var isAvailable: Bool { true }

    /// Returns an empty `ExtractionResult` without performing any analysis.
    public func extract(from text: String) async throws -> ExtractionResult {
        ExtractionResult(entities: [], facts: [])
    }
}
