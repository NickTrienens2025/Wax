import Foundation
import Testing
import Wax

// MARK: - Test 1: edges() returns outbound entity relationships

@Test func edgesReturnsOutboundEntityRelationships() async throws {
    let url = temporaryGraphStoreURL(prefix: "wax-graph-edges")
    defer { try? FileManager.default.removeItem(at: url) }

    var config = OrchestratorConfig.default
    config.enableVectorSearch = false
    config.enableStructuredMemory = true

    let memory = try await MemoryOrchestrator(at: url, config: config)
    defer { Task { try? await memory.close() } }

    // Create entities
    _ = try await memory.upsertEntity(key: EntityKey("user:chris"), kind: "person")
    _ = try await memory.upsertEntity(key: EntityKey("project:wax"), kind: "project")

    // Assert fact: chris works_on project:wax (entity-valued edge)
    _ = try await memory.assertFact(
        subject: EntityKey("user:chris"),
        predicate: PredicateKey("works_on"),
        object: .entity(EntityKey("project:wax"))
    )

    // Query outbound edges from user:chris
    let result = try await memory.edges(
        from: EntityKey("user:chris"),
        direction: .outbound,
        limit: 10
    )

    #expect(result.hits.count == 1)
    let hit = try #require(result.hits.first)
    #expect(hit.predicate == PredicateKey("works_on"))
    #expect(hit.neighbor == EntityKey("project:wax"))
    #expect(hit.direction == .outbound)
    #expect(result.wasTruncated == false)
}

// MARK: - Test 2: inbound edges resolve from the object side

@Test func edgesReturnsInboundEntityRelationships() async throws {
    let url = temporaryGraphStoreURL(prefix: "wax-graph-inbound")
    defer { try? FileManager.default.removeItem(at: url) }

    var config = OrchestratorConfig.default
    config.enableVectorSearch = false
    config.enableStructuredMemory = true

    let memory = try await MemoryOrchestrator(at: url, config: config)
    defer { Task { try? await memory.close() } }

    _ = try await memory.upsertEntity(key: EntityKey("user:chris"), kind: "person")
    _ = try await memory.upsertEntity(key: EntityKey("project:wax"), kind: "project")

    _ = try await memory.assertFact(
        subject: EntityKey("user:chris"),
        predicate: PredicateKey("works_on"),
        object: .entity(EntityKey("project:wax"))
    )

    // Query inbound edges into project:wax
    let result = try await memory.edges(
        from: EntityKey("project:wax"),
        direction: .inbound,
        limit: 10
    )

    #expect(result.hits.count == 1)
    let hit = try #require(result.hits.first)
    #expect(hit.predicate == PredicateKey("works_on"))
    #expect(hit.neighbor == EntityKey("user:chris"))
    #expect(hit.direction == .inbound)
}

// MARK: - Test 3: walkGraph returns 2-hop facts

@Test func walkGraphReturns2HopFacts() async throws {
    let url = temporaryGraphStoreURL(prefix: "wax-graph-walk")
    defer { try? FileManager.default.removeItem(at: url) }

    var config = OrchestratorConfig.default
    config.enableVectorSearch = false
    config.enableStructuredMemory = true

    let memory = try await MemoryOrchestrator(at: url, config: config)
    defer { Task { try? await memory.close() } }

    // Create entities
    _ = try await memory.upsertEntity(key: EntityKey("user:chris"), kind: "person")
    _ = try await memory.upsertEntity(key: EntityKey("project:wax"), kind: "project")

    // Hop 0 facts about user:chris:
    // - chris prefers "guard clauses" (string fact)
    _ = try await memory.assertFact(
        subject: EntityKey("user:chris"),
        predicate: PredicateKey("prefers"),
        object: .string("guard clauses")
    )
    // - chris works_on project:wax (entity edge -> creates hop 1 frontier)
    _ = try await memory.assertFact(
        subject: EntityKey("user:chris"),
        predicate: PredicateKey("works_on"),
        object: .entity(EntityKey("project:wax"))
    )

    // Hop 1 fact about project:wax:
    // - project:wax uses "SQLite" (string fact)
    _ = try await memory.assertFact(
        subject: EntityKey("project:wax"),
        predicate: PredicateKey("uses"),
        object: .string("SQLite")
    )

    let context = StructuredMemoryQueryContext(
        asOf: .latest,
        maxResults: 100,
        maxTraversalEdges: 50,
        maxDepth: 2
    )

    let walkResult = try await memory.walkGraph(
        from: EntityKey("user:chris"),
        context: context
    )

    // Expect 3 hits total: 2 at hop 0, 1 at hop 1
    #expect(walkResult.hits.count == 3)
    #expect(walkResult.resolvedEntities == [EntityKey("user:chris")])

    let hop0Hits = walkResult.hits.filter { $0.hopDistance == 0 }
    let hop1Hits = walkResult.hits.filter { $0.hopDistance == 1 }

    #expect(hop0Hits.count == 2)
    #expect(hop1Hits.count == 1)

    // Verify hop 0 predicates
    let hop0Predicates = Set(hop0Hits.map(\.predicate))
    #expect(hop0Predicates.contains(PredicateKey("prefers")))
    #expect(hop0Predicates.contains(PredicateKey("works_on")))

    // Verify hop 1 predicate
    let hop1Hit = try #require(hop1Hits.first)
    #expect(hop1Hit.predicate == PredicateKey("uses"))
    #expect(hop1Hit.subject == EntityKey("project:wax"))
    #expect(hop1Hit.object == .string("SQLite"))

    // Verify hop decay values
    for hit in hop0Hits {
        #expect(hit.hopDecay == 1.0 / Float(1 + 0))
    }
    for hit in hop1Hits {
        #expect(hit.hopDecay == 1.0 / Float(1 + 1))
    }
}

// MARK: - Test 4: walkGraph with maxDepth=1 stops at hop 0 facts only

@Test func walkGraphRespectsMaxDepth() async throws {
    let url = temporaryGraphStoreURL(prefix: "wax-graph-depth")
    defer { try? FileManager.default.removeItem(at: url) }

    var config = OrchestratorConfig.default
    config.enableVectorSearch = false
    config.enableStructuredMemory = true

    let memory = try await MemoryOrchestrator(at: url, config: config)
    defer { Task { try? await memory.close() } }

    _ = try await memory.upsertEntity(key: EntityKey("user:alice"), kind: "person")
    _ = try await memory.upsertEntity(key: EntityKey("project:foo"), kind: "project")

    _ = try await memory.assertFact(
        subject: EntityKey("user:alice"),
        predicate: PredicateKey("owns"),
        object: .entity(EntityKey("project:foo"))
    )
    _ = try await memory.assertFact(
        subject: EntityKey("project:foo"),
        predicate: PredicateKey("language"),
        object: .string("Swift")
    )

    let context = StructuredMemoryQueryContext(
        asOf: .latest,
        maxResults: 100,
        maxTraversalEdges: 50,
        maxDepth: 1  // Only hop 0
    )

    let result = try await memory.walkGraph(from: EntityKey("user:alice"), context: context)

    // maxDepth=1 means range 0..<1, only hop 0 is processed
    #expect(result.hits.count == 1)
    #expect(result.hits[0].hopDistance == 0)
    #expect(result.hits[0].predicate == PredicateKey("owns"))
}

// MARK: - Test 5: GraphWalkHit hopDecay computed property

@Test func graphWalkHitHopDecayIsCorrect() {
    let hit0 = GraphWalkHit(
        factId: FactRowID(rawValue: 1),
        subject: EntityKey("a"),
        predicate: PredicateKey("p"),
        object: .string("v"),
        hopDistance: 0,
        confidence: nil,
        evidenceFrameIds: []
    )
    let hit1 = GraphWalkHit(
        factId: FactRowID(rawValue: 2),
        subject: EntityKey("a"),
        predicate: PredicateKey("p"),
        object: .string("v"),
        hopDistance: 1,
        confidence: nil,
        evidenceFrameIds: []
    )
    let hit2 = GraphWalkHit(
        factId: FactRowID(rawValue: 3),
        subject: EntityKey("a"),
        predicate: PredicateKey("p"),
        object: .string("v"),
        hopDistance: 2,
        confidence: nil,
        evidenceFrameIds: []
    )

    #expect(hit0.hopDecay == 1.0)
    #expect(hit1.hopDecay == 0.5)
    #expect(abs(hit2.hopDecay - (1.0 / 3.0)) < 0.001)
}

// MARK: - Test 6: GraphWalkResult allEvidenceFrameIds aggregates all frame IDs

@Test func graphWalkResultAggregatesEvidenceFrameIds() {
    let hit1 = GraphWalkHit(
        factId: FactRowID(rawValue: 1),
        subject: EntityKey("a"),
        predicate: PredicateKey("p"),
        object: .string("v"),
        hopDistance: 0,
        confidence: nil,
        evidenceFrameIds: [10, 20]
    )
    let hit2 = GraphWalkHit(
        factId: FactRowID(rawValue: 2),
        subject: EntityKey("b"),
        predicate: PredicateKey("q"),
        object: .string("w"),
        hopDistance: 1,
        confidence: 0.9,
        evidenceFrameIds: [20, 30]
    )
    let result = GraphWalkResult(resolvedEntities: [EntityKey("a")], hits: [hit1, hit2])
    #expect(result.allEvidenceFrameIds == [10, 20, 30])
}

// MARK: - Helpers

private func temporaryGraphStoreURL(prefix: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        .appendingPathExtension("wax")
}
