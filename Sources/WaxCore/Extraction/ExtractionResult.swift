import Foundation

/// An entity extracted from text, ready to be upserted into structured memory.
public struct ExtractedEntity: Sendable, Equatable {
    /// The stable identifier for this entity.
    public let key: EntityKey
    /// Human-readable kind label (e.g. "person", "organisation", "project").
    public let kind: String
    /// Alternative names or spellings for this entity.
    public let aliases: [String]

    public init(key: EntityKey, kind: String, aliases: [String]) {
        self.key = key
        self.kind = kind
        self.aliases = aliases
    }
}

/// A fact triple extracted from text, ready to be asserted into structured memory.
public struct ExtractedFact: Sendable, Equatable {
    /// The entity the fact is about.
    public let subject: EntityKey
    /// The relationship or attribute being described.
    public let predicate: PredicateKey
    /// The value of the fact.
    public let object: FactValue
    /// Optional extractor confidence score in the range 0.0–1.0.
    public let confidence: Double?

    public init(
        subject: EntityKey,
        predicate: PredicateKey,
        object: FactValue,
        confidence: Double?
    ) {
        self.subject = subject
        self.predicate = predicate
        self.object = object
        self.confidence = confidence
    }
}

/// The aggregate output from a single extraction pass over a piece of text.
public struct ExtractionResult: Sendable, Equatable {
    /// All entities identified in the text.
    public let entities: [ExtractedEntity]
    /// All facts identified in the text.
    public let facts: [ExtractedFact]

    /// `true` when no entities or facts were extracted.
    public var isEmpty: Bool {
        entities.isEmpty && facts.isEmpty
    }

    public init(entities: [ExtractedEntity], facts: [ExtractedFact]) {
        self.entities = entities
        self.facts = facts
    }
}
