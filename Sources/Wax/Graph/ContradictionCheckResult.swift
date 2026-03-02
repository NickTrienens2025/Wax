import Foundation
import WaxCore

/// The result of asserting a fact with automatic contradiction detection.
///
/// When asserting a new fact, any existing facts that share the same
/// subject and predicate but differ in object value are automatically
/// retracted. This type describes what happened during the operation.
public struct ContradictionCheckResult: Sendable, Equatable {
    /// The row ID of the newly asserted fact.
    public let factId: FactRowID

    /// The row IDs of any facts that were retracted because they
    /// contradicted the newly asserted fact (same subject+predicate,
    /// different object).
    public let retractedFactIds: [FactRowID]

    /// True when at least one contradicting fact was retracted.
    public var hadContradiction: Bool { !retractedFactIds.isEmpty }

    public init(factId: FactRowID, retractedFactIds: [FactRowID]) {
        self.factId = factId
        self.retractedFactIds = retractedFactIds
    }
}
