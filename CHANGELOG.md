# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.2] - 2025-12-30

### Changed

- **SDK Version**: Updated minimum SDK constraint from `^3.10.0` to `^3.10.7` to fix pub.dev dependency resolution failure

### Fixed

- **SSA Builder**: Added result field versioning for `CallInstruction`, `LoadFieldInstruction`, `LoadIndexInstruction`, `NullCheckInstruction`, `CastInstruction`, `TypeCheckInstruction`
- **SSA Builder**: Implemented trivial phi use-site replacement with substitution chain resolution
- **SSA Builder**: Added `AwaitInstruction` result versioning
- **Datalog Facts**: Preserved SSA versions in `_getValueVarId` using `variable.toString()`
- **Datalog Facts**: Added flow-sensitive `*At` facts (`AssignAt`, `AllocAt`, `CallAt`, `LoadFieldAt`, `StoreFieldAt`, `PhiAt`) with block IDs
- **Abstract Interpreter**: Added missing transfer functions for `LoadField`, `Call`, `Await`, `LoadIndex`, `NullCheck`, `Cast`, `TypeCheck`
- **Abstract Interpreter**: Fixed unreachable predecessor filtering in phi transfer function

## [0.3.1] - 2025-12-29

### Changed

- **Halstead Metrics**: Renamed `N1`/`N2` fields to `operatorTotal`/`operandTotal` for Dart naming convention compliance
- **SDK Version**: Updated minimum SDK constraint from `^3.5.0` to `^3.10.0` for `dart_bert_tokenizer` compatibility
- **Async I/O**: Converted async file existence checks to sync versions for better performance

### Fixed

- **Library Documentation**: Added `library;` directive to fix dangling doc comment warning
- **Doc Comments**: Escaped angle brackets in documentation to prevent unintended HTML interpretation
- **String Interpolation**: Fixed string concatenation to use interpolation
- **Const Usage**: Applied `const` constructors and declarations throughout test files
- **Dynamic Calls**: Fixed avoid_dynamic_calls warnings in server tests
- **Unnecessary Import**: Removed redundant import in metrics_test.dart
- **Constructor Ordering**: Moved constructors before field declarations per `sort_constructors_first` lint rule

## [0.3.0] - 2025-12-29

### Added

- **Neural Analysis Setup**: Semantic clone detection using ONNX Runtime
  - Pre-trained nomic-embed-text model (~522MB) for 768-dimensional embeddings
  - WordPiece tokenization via `dart_bert_tokenizer`
  - Model file search order: `--model` option → `./model/` → `~/.anteater/`
  - Installation instructions for ONNX Runtime (`brew install onnxruntime`)
- **CLI Command**: `anteater clones --path <path>` for semantic clone detection
  - Detects semantically similar code (same functionality, different syntax)
  - Configurable similarity threshold (`--threshold`)
  - Custom model/vocab paths (`--model`, `--vocab`)
  - Fallback to `~/.anteater/` for global installation
  - Output formats: text, json
- **Technical Debt Cost Model**: Comprehensive debt tracking and cost estimation
  - `DebtItem` and `DebtType` models with 10 debt types (TODO, FIXME, ignore, as dynamic, etc.)
  - `DebtSeverity` with configurable cost multipliers (critical: 4x, high: 2x, medium: 1x, low: 0.5x)
  - `DebtDetector` for detecting debt from comments, casts, annotations, and metrics
  - `DebtCostCalculator` for item and total cost calculation
  - `DebtReport` with Markdown, JSON, and console output formats
  - `DebtAggregator` for project-level aggregation and hotspot analysis
  - `DebtTrend` for tracking debt changes over time
- **CLI Command**: `anteater debt --path <path>` for technical debt analysis
  - Output formats: text, json, markdown
  - Threshold-based CI gate with `--fail-on-threshold`
  - Customizable threshold with `--threshold` flag
- **Debt Configuration**: YAML configuration for debt costs and thresholds
  - Per-type cost configuration
  - Metrics-based debt thresholds (MI, complexity, LOC)
  - Configurable unit of measurement (hours, story points)

## [0.2.0] - 2025-12-28

### Added

- **Style Consistency Rules**: 10 production-ready lint rules
  - Safety rules: `avoid-dynamic`, `avoid-global-state`, `avoid-late-keyword`, `no-empty-block`, `no-equal-then-else`
  - Quality rules: `prefer-first-last`, `prefer-async-await`, `avoid-unnecessary-cast`, `prefer-trailing-comma`, `binary-expression-order`
- **Rule Infrastructure**
  - `StyleRule` abstract base class for custom rules
  - `RuleRunner` for coordinated rule execution
  - `RuleRegistry` for rule registration and configuration
  - `RuleConfig` for YAML-based configuration parsing
  - `AnalysisResult` and `AnalysisResultBuilder` for multi-file results
- **Rule Configuration**
  - Per-rule severity override
  - Per-rule file exclusion patterns
  - Global exclusion patterns
- **CLI Command**: `anteater rules --path <path>` for running style rules
- **Performance Optimizations**
  - RegExp pattern caching for glob matching
  - Lazy computed properties in `AnalysisResult`
  - Unmodifiable collections in `RuleSettings`
  - Const empty list returns

### Changed

- Improved error handling: rule execution failures reported as warnings instead of silent failures

## [0.1.1] - 2025-12-28

### Added

- **High-level API**: `Anteater` facade class with one-liner static methods
  - `Anteater.analyzeMetrics()` for metrics analysis with automatic cleanup
  - `Anteater.analyze()` for project diagnostics with automatic cleanup
  - `Anteater.analyzeFile()` for single file analysis
- **Documentation**: Comprehensive dartdoc for `Anteater`, `SourceLoader`, `MetricsThresholds`
- **Exit Codes**: Documented in CLI help message
- **Library Usage**: Added usage examples to README.md
- **Quiet Mode**: `--quiet` / `-q` flag to suppress progress output for CI pipelines
- **Version Constant**: Centralized version string in `lib/version.dart`
- **Single File Support**: `SourceLoader` now accepts single file paths

### Changed

- Exit code for command line usage errors changed from 1 to 64 (EX_USAGE)
- Improved barrel export with explicit show clauses for key types

## [0.1.0] - 2025-12-28

### Added

- **Core Analysis Pipeline**
  - SSA-based data flow analysis using Braun et al. algorithm
  - Control Flow Graph (CFG) construction from Dart AST
  - Datalog-based relational reasoning engine

- **Metrics Calculation**
  - Cyclomatic complexity
  - Cognitive complexity
  - Halstead metrics (volume, difficulty, effort)
  - Maintainability index

- **CLI Interface**
  - \`anteater analyze\` command with text, JSON, and HTML output
  - \`anteater metrics\` command with threshold configuration
  - \`anteater server\` for LSP mode
  - \`--watch\` mode for continuous analysis
  - \`--no-fatal-infos\` and \`--no-fatal-warnings\` flags

- **Configuration**
  - \`analysis_options.yaml\` support for threshold configuration
  - CLI options override YAML configuration

- **Reasoner**
  - Points-to analysis
  - Taint tracking infrastructure
  - Abstract interpretation with interval domain
  - Bounds checking for array access

### Changed

- Nothing yet (initial release)

### Deprecated

- Nothing yet (initial release)

### Removed

- Nothing yet (initial release)

### Fixed

- Nothing yet (initial release)

### Security

- Nothing yet (initial release)
