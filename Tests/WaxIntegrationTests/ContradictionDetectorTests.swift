import Foundation
import Testing
import Wax
import WaxCore

// MARK: - Helpers

private func makeOrchestrator() async throws -> (MemoryOrchestrator, URL) {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("wax-contradiction-\(UUID().uuidString)")
        .appendingPathExtension("wax")
    var config = OrchestratorConfig.default
    config.enableVectorSearch = false
    config.enableStructuredMemory = true
    let orchestrator = try await MemoryOrchestrator(at: url, config: config)
    return (orchestrator, url)
}

// MARK: - Tests

struct ContradictionDetectorTests {

    /// Asserting a fact with a different object for the same subject+predicate
    /// should retract the old fact and leave only the new one.
    @Test func detectsConflictingFacts() async throws {
        let (memory, url) = try await makeOrchestrator()
        defer { try? FileManager.default.removeItem(at: url) }

        let subject = EntityKey("user:chris")
        let predicate = PredicateKey("prefers_editor")

        _ = try await memory.upsertEntity(key: subject, kind: "user", aliases: ["chris"])

        // Assert original fact
        _ = try await memory.assertFact(
            subject: subject,
            predicate: predicate,
            object: .string("Vim")
        )

        // Assert contradicting fact
        let result = try await memory.assertFactWithContradictionCheck(
            subject: subject,
            predicate: predicate,
            object: .string("Neovim")
        )

        // Exactly one old fact should have been retracted
        #expect(result.hadContradiction == true)
        #expect(result.retractedFactIds.count == 1)

        // Query current facts — only the new one should survive
        let current = try await memory.facts(about: subject, predicate: predicate)
        #expect(current.hits.count == 1)
        if case .string(let val) = current.hits.first?.fact.object {
            #expect(val == "Neovim")
        } else {
            Issue.record("Expected string object value 'Neovim'")
        }

        try await memory.close()
    }

    /// Facts with different predicates should coexist — no retraction should occur.
    @Test func allowsMultipleFactsWithDifferentPredicates() async throws {
        let (memory, url) = try await makeOrchestrator()
        defer { try? FileManager.default.removeItem(at: url) }

        let subject = EntityKey("user:chris")

        _ = try await memory.upsertEntity(key: subject, kind: "user", aliases: ["chris"])

        let r1 = try await memory.assertFactWithContradictionCheck(
            subject: subject,
            predicate: PredicateKey("prefers_editor"),
            object: .string("Neovim")
        )
        let r2 = try await memory.assertFactWithContradictionCheck(
            subject: subject,
            predicate: PredicateKey("prefers_language"),
            object: .string("Swift")
        )

        // Neither call should have caused a retraction
        #expect(r1.hadContradiction == false)
        #expect(r2.hadContradiction == false)

        // Both facts should be present
        let all = try await memory.facts(about: subject)
        #expect(all.hits.count == 2)

        try await memory.close()
    }

    /// Re-asserting the exact same subject+predicate+object should not retract anything.
    @Test func doesNotRetractWhenObjectIsSame() async throws {
        let (memory, url) = try await makeOrchestrator()
        defer { try? FileManager.default.removeItem(at: url) }

        let subject = EntityKey("user:chris")
        let predicate = PredicateKey("prefers")

        _ = try await memory.upsertEntity(key: subject, kind: "user", aliases: ["chris"])

        _ = try await memory.assertFact(
            subject: subject,
            predicate: predicate,
            object: .string("Swift")
        )

        let result = try await memory.assertFactWithContradictionCheck(
            subject: subject,
            predicate: predicate,
            object: .string("Swift")
        )

        // No contradiction — object is identical
        #expect(result.hadContradiction == false)
        #expect(result.retractedFactIds.isEmpty == true)

        // The query returns exactly one valid fact (the re-asserted one;
        // the original may or may not still be active depending on the
        // engine, but there must be at least one with the correct value)
        let current = try await memory.facts(about: subject, predicate: predicate)
        #expect(current.hits.isEmpty == false)
        let allAreSwift = current.hits.allSatisfy { hit in
            if case .string(let v) = hit.fact.object { return v == "Swift" }
            return false
        }
        #expect(allAreSwift == true)

        try await memory.close()
    }
}
