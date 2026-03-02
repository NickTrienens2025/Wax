import Foundation

/// Protocol for extracting entities and facts from text content.
public protocol EntityExtractor: Sendable {
    /// Extract entities and facts from the provided text.
    /// - Parameter text: The raw text to analyse.
    /// - Returns: An `ExtractionResult` containing any entities and facts found.
    func extract(from text: String) async throws -> ExtractionResult

    /// Whether this extractor is currently available for use.
    ///
    /// Extractors that depend on on-device models (e.g. Foundation Models) may
    /// report `false` when the required model is unavailable or the device does
    /// not meet minimum requirements.
    var isAvailable: Bool { get }
}
