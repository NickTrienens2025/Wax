import Foundation
import WaxCore

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Generable output types

@available(macOS 26, iOS 26, *)
@Generable
struct ExtractionOutput {
    @Guide(description: "Entities found in the text")
    var entities: [EntityOutput]
    @Guide(description: "Facts/relationships found in the text")
    var facts: [FactOutput]
}

@available(macOS 26, iOS 26, *)
@Generable
struct EntityOutput {
    @Guide(description: "Namespaced key like 'person:name' or 'project:name'")
    var key: String
    @Guide(description: "Entity kind: person, project, tool, language, concept")
    var kind: String
    @Guide(description: "Alternative names for this entity")
    var aliases: [String]
}

@available(macOS 26, iOS 26, *)
@Generable
struct FactOutput {
    @Guide(description: "Subject entity key")
    var subject: String
    @Guide(description: "Relationship predicate like prefers, uses, works_on")
    var predicate: String
    @Guide(description: "Object value as string")
    var object: String
    @Guide(description: "True if the object refers to another entity key")
    var objectIsEntity: Bool
}

// MARK: - FoundationModelExtractor (available)

/// An `EntityExtractor` backed by Apple's on-device Foundation Models framework.
///
/// Performs guided generation using `@Generable` structured output to extract
/// entities and fact triples from text. Requires macOS 26 / iOS 26 or later and
/// an Apple Intelligence–capable device.
///
/// When the model is unavailable (older OS, unsupported hardware, or in CI),
/// `isAvailable` returns `false` and `extract(from:)` returns an empty result
/// without throwing.
public final class FoundationModelExtractor: EntityExtractor, @unchecked Sendable {

    private let systemPrompt = """
        Extract entities and factual relationships from text.
        Use namespaced keys: person:name, project:name, tool:name, language:name.
        Facts are subject-predicate-object triples.
        Common predicates: prefers, uses, works_on, knows, dislikes, configured_with.
        Only extract clearly stated facts. Do not speculate.
        """

    public init() {}

    public var isAvailable: Bool {
        if #available(macOS 26, iOS 26, *) {
            return SystemLanguageModel.default != nil
        }
        return false
    }

    public func extract(from text: String) async throws -> ExtractionResult {
        guard isAvailable else { return ExtractionResult(entities: [], facts: []) }

        if #available(macOS 26, iOS 26, *) {
            let session = LanguageModelSession(instructions: systemPrompt)
            let output = try await session.respond(
                to: "Extract entities and facts from:\n\n\(text)",
                generating: ExtractionOutput.self
            )

            let entities = output.content.entities.map { e in
                ExtractedEntity(
                    key: EntityKey(e.key),
                    kind: e.kind,
                    aliases: e.aliases
                )
            }
            let facts = output.content.facts.map { f in
                ExtractedFact(
                    subject: EntityKey(f.subject),
                    predicate: PredicateKey(f.predicate),
                    object: f.objectIsEntity
                        ? .entity(EntityKey(f.object))
                        : .string(f.object),
                    confidence: 0.85
                )
            }
            return ExtractionResult(entities: entities, facts: facts)
        }

        return ExtractionResult(entities: [], facts: [])
    }
}

#else

// MARK: - FoundationModelExtractor (stub — FoundationModels not available)

/// Stub implementation of `FoundationModelExtractor` for platforms where
/// `FoundationModels` is not importable (macOS < 26, Linux, CI).
///
/// Always reports `isAvailable == false` and returns empty extraction results.
public final class FoundationModelExtractor: EntityExtractor, @unchecked Sendable {

    public init() {}

    /// Always `false` — Foundation Models framework is not available on this platform.
    public var isAvailable: Bool { false }

    /// Returns an empty `ExtractionResult` without performing any analysis.
    public func extract(from text: String) async throws -> ExtractionResult {
        ExtractionResult(entities: [], facts: [])
    }
}

#endif
