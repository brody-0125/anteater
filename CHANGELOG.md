# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
