# CLAUDE.md

Guidance for Claude Code (and other AI coding assistants) working in this repository.

## Project Overview

**Wax** is a Swift-native, single-file memory layer for AI agents on Apple platforms. It bundles documents, metadata, text indexes (SQLite FTS5), and vector indexes (HNSW via USearch / Metal-accelerated ANNS) into one portable `.wax` binary file — no server, no cloud.

- **Language:** Swift 6.1+ (strict concurrency enabled on every target)
- **Platforms:** iOS 18+, macOS 15+ (primary); WaxCore additionally builds on Linux
- **Build system:** Swift Package Manager (`Package.swift` at the repo root)
- **License:** Apache 2.0

## Repository Layout

```
Wax/
├── Package.swift                 # SwiftPM manifest (libraries, executables, traits, tests)
├── README.md                     # Public-facing product README
├── Sources/
│   ├── WaxCore/                  # Foundation: .wax format, WAL, IO, locks, StructuredMemory types
│   │   ├── FileFormat/           # Headers, TOC, footer, segment catalog, manifests
│   │   ├── WAL/                  # Write-ahead log ring buffer, codec, replay
│   │   ├── Concurrency/          # AsyncReadWriteLock, AsyncMutex, UnfairLock, FileLock
│   │   ├── BinaryCodec/ IO/ Compression/ Checksum/
│   │   ├── StructuredMemory/     # Entity/fact/predicate row types, EAV model
│   │   └── WaxCore.docc/         # DocC articles (FileFormat, WAL, Concurrency, StructuredMemory)
│   ├── WaxCoreCompressionC/      # C shim for lz4/zlib on Linux
│   ├── WaxTextSearch/            # GRDB/SQLite FTS5 search engine + structured memory schema
│   ├── WaxVectorSearch/          # USearch + AccelerateVectorEngine + MetalANNSVectorEngine
│   ├── WaxVectorSearchMiniLM/    # CoreML MiniLM-L6-v2 embedder (default trait)
│   ├── WaxVectorSearchArctic/    # CoreML Snowflake Arctic Embed Small (opt-in trait)
│   ├── WaxBertTokenizer/         # Bundled BERT WordPiece tokenizer + vocab
│   ├── Wax/                      # Top-level orchestration library
│   │   ├── Memory.swift          # High-level Memory actor facade
│   │   ├── Orchestrator/         # MemoryOrchestrator and extensions (File, PDF, Corpus, Maintenance, Prewarm)
│   │   ├── UnifiedSearch/        # Hybrid search, RRF fusion, query classifier, adaptive fusion
│   │   ├── RAG/                  # FastRAGContextBuilder, token counting, importance scoring
│   │   ├── VideoRAG/  PhotoRAG/  # Multimodal ingestion pipelines
│   │   ├── Broker/               # Shared broker transport + long-term/session store lifecycle
│   │   ├── Ingest/ Enrichment/ Temporal/ Maintenance/ Stats/ Adapters/ Utilities/
│   │   └── Wax.docc/             # DocC articles (Architecture, MemoryOrchestrator, UnifiedSearch, …)
│   ├── WaxCLI/                   # `wax-cli` executable (ArgumentParser-based)
│   ├── WaxMCPServer/             # `wax-mcp` stdio Model Context Protocol server
│   ├── WaxRepo/                  # `wax-repo` TUI for semantic git search (SwiftTUI + Noora)
│   └── WaxCrashHarness/          # Standalone crash-replay harness
├── Tests/
│   ├── WaxCoreTests/             # Pure WaxCore tests (runs on Linux too)
│   ├── WaxIntegrationTests/      # Full-stack tests (many macOS/iOS-only; excluded on Linux)
│   ├── WaxArcticTests/           # Arctic embedder conformance tests
│   ├── WaxMCPServerTests/        # MCP surface + process-backed MCP tests
│   ├── WaxCLITests/              # wax-cli command tests
│   └── WaxTests/                 # Top-level Wax library tests
├── Resources/
│   ├── scripts/quality/          # production_readiness_gates.sh, check_corruption_assertions.sh
│   ├── docs/                     # Public docs (benchmarks, wax-mcp setup guides, plans)
│   ├── locales/                  # Translated READMEs
│   ├── skills/public/wax/        # Bundled Wax skill shipped to AI assistants
│   ├── npm/                      # waxmcp npm package source
│   ├── website/                  # Docusaurus site
│   └── WaxDemo/                  # Sample app
├── docs/                         # Product/spec docs (wax-teams-*, superpowers plans)
├── scripts/                      # release-waxmcp.sh, convert_arctic_embed.py
├── tasks/                        # Local TODO and lessons notebook (gitignored dir)
└── .github/workflows/            # CI: quality-gates.yml, waxcore-linux.yml, release-waxmcp.yml, …
```

## Module Dependency Graph

```
       ┌──────────────────────────────┐
       │            Wax               │  Orchestration, RAG, Unified Search,
       │  MemoryOrchestrator, Photo/  │  Memory facade, Broker
       │  VideoRAG, HybridSearch      │
       └──┬───────────────┬───────────┘
          │               │
   ┌──────▼──────┐   ┌────▼──────────────┐
   │WaxTextSearch│   │WaxVectorSearch    │
   │(GRDB/FTS5)  │   │(USearch, Metal,   │
   │             │   │ Accelerate)       │
   └──────┬──────┘   └──────┬────────────┘
          │                 │
          │          ┌──────▼─────────────┐
          │          │WaxVectorSearchMiniLM│ (default)
          │          │WaxVectorSearchArctic│ (trait-gated)
          │          │   ← WaxBertTokenizer│
          │          └──────┬─────────────┘
          │                 │
   ┌──────▼─────────────────▼────┐
   │          WaxCore            │  .wax format, WAL, IO, locks,
   │   (+ WaxCoreCompressionC    │  StructuredMemory types
   │    on Linux)                │
   └─────────────────────────────┘
```

Executables (`wax-cli`, `wax-mcp`, `wax-repo`, `WaxCrashHarness`) depend on `Wax` + embedder targets.

## Package Traits

Traits defined in `Package.swift` let consumers opt in/out of optional modules:

| Trait | Default | Description |
|-------|---------|-------------|
| `MiniLMEmbeddings` | **on** | Bundles MiniLM-L6-v2 CoreML model (~22 MB) as the default embedder |
| `ArcticEmbeddings` | off | Bundles Snowflake Arctic Embed Small as an alternate embedder |
| `MCPServer` | off | Builds the `wax-mcp` stdio MCP server (macOS only) |
| `WaxRepo` | off | Builds the `wax-repo` semantic git search TUI (macOS only) |

When running tests or builds that exercise MCP or non-default embedders, pass the trait explicitly, e.g. `swift test --traits default,MCPServer` or `swift build --traits MCPServer,ArcticEmbeddings`.

## Key Architectural Concepts

1. **Single-file `.wax` format.** Dual header pages (A/B with generation counters), WAL ring buffer, compressed LZ4 data frames, SQLite FTS5 blob, Metal HNSW index, and TOC + footer — all inside one file. See `Sources/WaxCore/WaxCore.docc/Articles/FileFormat.md` and `WALAndCrashRecovery.md`.

2. **Actor-per-subsystem concurrency.** Every major component is a Swift actor with its own serial executor; cross-actor traffic is `Sendable`. Strict concurrency is enabled on every target (`.enableExperimentalFeature("StrictConcurrency")`). See `WaxCore.docc/Articles/ConcurrencyModel.md`.

3. **Writer leases.** Exactly one writer at a time against a `.wax` file; readers run concurrently. Controlled via `WaxWriterPolicy` (`.fail` / `.wait` / `.timeout`). Cross-process safety comes from `FileLock` (POSIX `flock`).

4. **Hybrid retrieval.** `UnifiedSearch` fuses a BM25 lane (`FTS5SearchEngine`), a vector lane (USearch CPU / MetalANNS GPU), a structured-memory lane, and a timeline lane using Reciprocal Rank Fusion. Fusion weights are adapted per-query by `RuleBasedQueryClassifier` / `AdaptiveFusionConfig`.

5. **RAG assembly.** `FastRAGContextBuilder` turns ranked hits into a `RAGContext` that fits a token budget, selecting between full/gist/micro surrogate tiers (`SurrogateTierSelector`).

6. **Structured memory.** An EAV-style entity/fact layer (`Sources/WaxCore/StructuredMemory/*` and `Sources/WaxTextSearch/StructuredMemorySchema.swift`) stores durable facts alongside unstructured text. Exposed via `entity_upsert`, `fact_assert`, `facts_query`, etc.

7. **Broker architecture.** CLI and MCP memory commands route through a shared broker (`Sources/Wax/Broker/*`, `Sources/WaxCLI/DaemonCommand.swift`) that owns the long-term store and broker-managed virtual session stores. This lets multiple clients share one store without lock contention. `wax-cli` spawns a broker automatically; `wax-mcp` is always a broker client.

## Executables

| Executable | Target | Purpose |
|------------|--------|---------|
| `wax-cli` | `Sources/WaxCLI` | Primary CLI (`remember`, `recall`, `search`, `handoff`, `facts`, `entity`, `daemon`, `stats`, `vector-health`). Broker-backed by default; `--direct-store` bypasses the broker. |
| `wax-mcp` | `Sources/WaxMCPServer` | stdio MCP server exposing unprefixed tools (`remember`, `recall`, `search`, `handoff`, `handoff_latest`, `session_start`/`session_end`, `corpus_search`, structured memory tools). Requires `MCPServer` trait. |
| `wax-repo` | `Sources/WaxRepo` | TUI for semantic search over a git repo's history. Requires `WaxRepo` trait. |
| `WaxCrashHarness` | `Sources/WaxCrashHarness` | Deterministic crash-replay harness used by stability tests. |

## Development Workflow

### Building

```bash
# Default build (libraries + wax-cli with MiniLM embedder)
swift build

# Build MCP server and CLI with explicit traits
swift build --traits default,MCPServer --product wax-cli --product wax-mcp

# Linux-only WaxCore slice (matches CI)
swift build --target WaxCore -Xswiftc -DGRDBCUSTOMSQLITE
```

### Testing

Tests use **swift-testing** (`import Testing`) for most suites and XCTest for stability/benchmark harnesses.

```bash
# Standard test run (skips benchmarks by default via filter patterns)
swift test --parallel

# Full production-readiness gate used in CI
bash Resources/scripts/quality/production_readiness_gates.sh full

# MCP-scoped tests (requires MCPServer trait)
swift test --parallel --traits default,MCPServer --filter WaxMCPServerTests
swift test --parallel --traits default,MCPServer --filter WaxCLITests

# Linux subset (mirrors waxcore-linux.yml)
swift test --filter WaxCoreTests -Xswiftc -DGRDBCUSTOMSQLITE

# Long-running stability suites (XCTest, opt-in via env vars)
bash Resources/scripts/quality/production_readiness_gates.sh soak-smoke
bash Resources/scripts/quality/production_readiness_gates.sh burn-smoke
```

`production_readiness_gates.sh` enforces: no skipped tests, 100% pass rate, corruption-assertion audit via `check_corruption_assertions.sh`. Run it before claiming a PR is ready for review.

Benchmark targets (`RAGBenchmarks`, `WALCompactionBenchmarks`, `LongMemoryBenchmarkHarness`, `BatchEmbeddingBenchmark`, `MetalVectorEngineBenchmark`, `OptimizationComparisonBenchmark`, `TokenizerBenchmark`, `BufferSerializationBenchmark`) are expensive — they're excluded from the standard gate via `--skip`.

### CI Workflows (`.github/workflows/`)

- `quality-gates.yml` — runs `production_readiness_gates.sh` in `full`, `soak-smoke`, `burn-smoke` matrix modes on `macos-latest` for every PR and push to `main`.
- `waxcore-linux.yml` — builds and tests `WaxCore` on Ubuntu with lz4/zlib/sqlite3 system packages.
- `release-waxmcp.yml` — release pipeline for the `waxmcp` npm package; driven by `scripts/release-waxmcp.sh`.
- `claude.yml`, `claude-code-review.yml` — Claude Code GitHub integration hooks.
- `deploy-website.yml` — deploys the Docusaurus site under `Resources/website/`.

## Coding Conventions

- **Strict concurrency.** Every target sets `.enableExperimentalFeature("StrictConcurrency")`. New code must be `Sendable`-clean; do not silence warnings with `@unchecked Sendable` without a written justification.
- **Actor boundaries.** Prefer adding methods to existing actors rather than introducing new shared mutable state. Use the lock types in `Sources/WaxCore/Concurrency/` instead of hand-rolling synchronization.
- **Swift Testing first.** New tests should use `import Testing` with `@Test` / `#expect`. Keep XCTest only where stability/benchmark harnesses already rely on its runner semantics (`--enable-xctest --disable-swift-testing`).
- **Platform guards.** Metal/CoreML code is Apple-only; gate it with `#if canImport(Metal)` / `#if os(macOS) || os(iOS)` and keep the Linux path compiling (see the `waxIntegrationLinuxExcludes` list in `Package.swift`).
- **DocC for new public surface.** When adding a public type or a significant concept, add or extend an article under `Sources/Wax/Wax.docc/Articles/` or `Sources/WaxCore/WaxCore.docc/Articles/`.
- **Single-file discipline.** The `.wax` format is append-friendly and crash-safe; never introduce out-of-band sidecar files for persistent state.

## Working on MCP Tools (guidance from `tasks/lessons.md`)

When adding or modifying an MCP tool in `Sources/WaxMCPServer/`, every new tool needs these explicit checks before considering it done:

1. **Strict argument validation.** Extend `validateArgumentSurface` so typoed top-level keys fail fast instead of silently falling back to defaults. Do not put `session_id` inside `metadata` — reject it as a reserved key on broker-backed paths.
2. **Mode-specific resource policy.** Audit `mode=text` paths so they do not load embedders or rebuild vector data unnecessarily. If a broker-backed path cannot honor a CLI flag, fail loudly rather than silently ignoring it.
3. **Feature scoping.** If the user says a feature is "for the MCP tool", implement it behind MCP schemas, handlers, and MCP-focused tests first. Only add CLI affordances if explicitly requested.
4. **Regression coverage.** Keep broker-backed tests for lifecycle, reserved metadata keys, renamed tool aliases (e.g. `wax_flush` → guidance). Compatibility-only tests are not enough.
5. **Process-backed tests.** Keep stdin open until `tools/list` responds; apply explicit time limits so a stuck subprocess cannot wedge the suite.
6. **CLI JSON assertions.** Parse the JSON or match the exact pretty-printed form; do not assume compact formatting.

## Git & PR Hygiene

- `.gitignore` excludes several "internal tooling" paths (including this `CLAUDE.md` itself, `AUDIT_REPORT.md`, `docs/plans/`, `Resources/skills/internal/`, `tasks/`, and `Package.resolved`). Respect those exclusions.
- Prefer creating new commits over amending. Never run destructive git (`reset --hard`, `push --force`, `branch -D`) or bypass hooks (`--no-verify`) without an explicit instruction.
- Branch names for Claude-authored work follow `claude/<slug>-<suffix>`. Push only to the branch assigned in the task instructions.
- Do **not** open a pull request unless the user asks for one explicitly.

## Where to Look First

| If you need to… | Start in… |
|------------------|-----------|
| Understand the binary format | `Sources/WaxCore/WaxCore.docc/Articles/FileFormat.md`, `Sources/WaxCore/FileFormat/` |
| Trace ingest/recall end-to-end | `Sources/Wax/Wax.docc/Articles/Architecture.md`, `Sources/Wax/Orchestrator/MemoryOrchestrator.swift` |
| Add a new high-level user API | `Sources/Wax/Memory.swift` + its DocC article |
| Touch search fusion | `Sources/Wax/UnifiedSearch/`, especially `HybridSearch.swift` and `AdaptiveFusionConfig.swift` |
| Modify embeddings | `Sources/WaxVectorSearch/Embeddings/`, `Sources/WaxVectorSearchMiniLM/`, `Sources/WaxVectorSearchArctic/` |
| Change the CLI surface | `Sources/WaxCLI/WaxCLICommand.swift` + per-command files |
| Change the MCP surface | `Sources/WaxMCPServer/WaxMCPTools.swift`, `ToolSchemas.swift`, `main.swift` |
| Debug crash recovery | `Sources/WaxCore/WAL/`, `Sources/WaxCrashHarness/`, `ProductionReadinessStabilityTests` |
| Run the full quality gate | `Resources/scripts/quality/production_readiness_gates.sh` |

## Release Notes

- The npm-published MCP installer lives in `Resources/npm/` and is cut by `scripts/release-waxmcp.sh`. When editing that script, remember the lesson in `tasks/lessons.md`: use single backslashes in `perl` regexes inside shell single-quoted strings, or the version bump will silently no-op.
- Swift package releases are tagged against `main`; consumers pin via `.package(url: ..., from: "0.1.x")` in their own `Package.swift`.
