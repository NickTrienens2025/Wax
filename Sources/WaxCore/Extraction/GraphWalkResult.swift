import Foundation

/// A single fact encountered during a BFS graph walk, tagged with hop distance and evidence.
public struct GraphWalkHit: Sendable, Equatable {
    public let factId: FactRowID
    public let subject: EntityKey
    public let predicate: PredicateKey
    public let object: FactValue
    /// Number of hops from the root entity (0 = directly asserted about root).
    public let hopDistance: Int
    public let confidence: Double?
    public let evidenceFrameIds: [UInt64]

    /// Decay factor applied to relevance scores: 1.0 at hop 0, 0.5 at hop 1, etc.
    public var hopDecay: Float { 1.0 / Float(1 + hopDistance) }

    public init(
        factId: FactRowID,
        subject: EntityKey,
        predicate: PredicateKey,
        object: FactValue,
        hopDistance: Int,
        confidence: Double?,
        evidenceFrameIds: [UInt64]
    ) {
        self.factId = factId
        self.subject = subject
        self.predicate = predicate
        self.object = object
        self.hopDistance = hopDistance
        self.confidence = confidence
        self.evidenceFrameIds = evidenceFrameIds
    }
}

/// The result of a BFS graph walk starting from one or more seed entities.
public struct GraphWalkResult: Sendable, Equatable {
    /// The entity keys used as seeds for the walk.
    public let resolvedEntities: [EntityKey]
    /// All facts collected across all hops, ordered by (hopDistance ASC, factId ASC).
    public let hits: [GraphWalkHit]

    /// Union of all evidence frame IDs referenced by any hit.
    public var allEvidenceFrameIds: Set<UInt64> {
        Set(hits.flatMap(\.evidenceFrameIds))
    }

    public init(resolvedEntities: [EntityKey], hits: [GraphWalkHit]) {
        self.resolvedEntities = resolvedEntities
        self.hits = hits
    }
}
