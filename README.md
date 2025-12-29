# Anteater

---

<p align="center">
  <img src="resource/logo.png" alt="Anteater Logo" width="300">
</p>

### **Static Analysis Engine for Dart**

Anteater is a static analyzer for Dart that provides SSA-based data flow analysis, Datalog-based reasoning, code metrics, and configurable lint rules.

## Features

- **Technical Debt Analysis**: Detect and quantify technical debt with configurable cost model
- **Style Consistency Rules**: 10 lint rules for code quality and safety
- **SSA-Based Data Flow Analysis**: Braun et al. algorithm for efficient SSA construction with lazy phi insertion
- **Datalog Reasoning Engine**: Points-to analysis, taint tracking, and immutability verification
- **Abstract Interpretation**: Interval domain analysis with widening/narrowing for loop bounds
- **Code Metrics**: Cyclomatic complexity, cognitive complexity, Halstead metrics, maintainability index
- **LSP Server**: IDE integration via Language Server Protocol
- **Taint Tracking**: Security vulnerability detection with source-sink analysis

## Installation

```bash
# Clone the repository
git clone https://github.com/hyeonLewis/anteater.git
cd anteater

# Install dependencies
dart pub get
```

### Neural Analysis Setup (Optional)

For semantic clone detection using neural embeddings:

```bash
# macOS
brew install onnxruntime

# Linux (Ubuntu/Debian)
apt install libonnxruntime-dev

# Or download from GitHub releases
# https://github.com/microsoft/onnxruntime/releases
```

Download model files to `~/.anteater/` (recommended for global installation):

```bash
mkdir -p ~/.anteater

# Download ONNX model (~522MB)
curl -L -o ~/.anteater/model.onnx https://huggingface.co/michael-sigamani/nomic-embed-text-onnx/resolve/main/model.onnx

# Download vocabulary (~226KB)
curl -L -o ~/.anteater/vocab.txt https://huggingface.co/nomic-ai/nomic-embed-text-v1/resolve/main/vocab.txt
```

Anteater searches for model files in this order:
1. Custom path via `--model`/`--vocab` options
2. Current directory: `./model/model.onnx`
3. Home directory: `~/.anteater/model.onnx`

## Usage

After installation, you can run Anteater using:

```bash
# Local development (without global activation)
dart run :anteater <command>

# After global activation
anteater <command>
```

### Analyze Code

```bash
# Analyze current directory
anteater analyze --path lib

# Output as JSON
anteater analyze --path lib --format json

# Save to file
anteater analyze --path lib --output report.html --format html

# Watch mode - re-analyze on file changes
anteater analyze --path lib --watch

# Control exit codes for CI pipelines
anteater analyze --path lib --no-fatal-warnings
anteater analyze --path lib --no-fatal-infos
```

### Calculate Metrics

```bash
# Calculate metrics with default thresholds
anteater metrics --path lib

# Custom thresholds (overrides analysis_options.yaml)
anteater metrics --path lib --threshold-cc 15 --threshold-mi 60
anteater metrics --path lib --threshold-cognitive 10 --threshold-loc 80

# Watch mode for continuous development
anteater metrics --path lib --watch
```

### Analyze Technical Debt

```bash
# Analyze technical debt with default cost model
anteater debt --path lib

# Output as JSON
anteater debt --path lib --format json

# Generate markdown report
anteater debt --path lib --format markdown --output debt-report.md

# Custom threshold for CI gate
anteater debt --path lib --threshold 100 --fail-on-threshold

# Quiet mode for CI pipelines
anteater debt --path lib --quiet
```

### Detect Semantic Clones

Requires ONNX Runtime and model files (see [Neural Analysis Setup](#neural-analysis-setup-optional)).

```bash
# Detect semantically similar code
anteater clones --path lib

# Custom similarity threshold (default: 0.85)
anteater clones --path lib --threshold 0.90

# Output as JSON
anteater clones --path lib --format json

# Custom model paths
anteater clones --path lib --model path/to/model.onnx --vocab path/to/vocab.txt
```

### Start Language Server

```bash
anteater server
```

## Technical Debt

Anteater detects and quantifies 10 types of technical debt:

| Debt Type | Default Severity | Base Cost (hours) |
|-----------|------------------|-------------------|
| TODO comments | Medium | 4 |
| FIXME comments | High | 8 |
| `// ignore:` comments | High | 8 |
| `// ignore_for_file:` comments | Critical | 16 |
| `as dynamic` casts | High | 16 |
| `@deprecated` usage | Medium | 4 |
| Low maintainability (MI < 50) | High | 8 |
| High complexity (CC > 20) | Medium | 4 |
| Long methods (LOC > 50) | Medium | 4 |
| Duplicate code | Medium | 8 |

### Cost Calculation

Total cost = Base Cost x Severity Multiplier

| Severity | Multiplier |
|----------|------------|
| Critical | 4.0x |
| High | 2.0x |
| Medium | 1.0x |
| Low | 0.5x |

## Style Rules

Anteater includes 10 production-ready style rules:

### Safety Rules

| Rule | Description |
|------|-------------|
| `avoid-dynamic` | Detects explicit `dynamic` type usage |
| `avoid-global-state` | Detects mutable top-level/static variables |
| `avoid-late-keyword` | Detects `late` keyword (except lazy init pattern) |
| `no-empty-block` | Detects empty blocks without comments |
| `no-equal-then-else` | Detects identical if/else branches |

### Quality Rules

| Rule | Description |
|------|-------------|
| `prefer-first-last` | Suggests `.first`/`.last` over `[0]`/`[length-1]` |
| `prefer-async-await` | Suggests async/await over chained `.then()` |
| `avoid-unnecessary-cast` | Detects redundant type casts |
| `prefer-trailing-comma` | Enforces trailing commas in multi-line constructs |
| `binary-expression-order` | Detects Yoda conditions (`0 == x`) |

### Running Style Rules

```bash
# Run all enabled rules
anteater rules --path lib

# Output as JSON
anteater rules --path lib --format json
```

## Configuration

Anteater can be configured via `analysis_options.yaml`:

```yaml
anteater:
  # Global file exclusions
  exclude:
    - '**.g.dart'
    - '**.freezed.dart'
    - 'build/**'

  # Style rules configuration
  rules:
    # Simple enable
    - avoid-dynamic
    - avoid-global-state
    - no-empty-block

    # With options
    - prefer-first-last:
        severity: info
        exclude:
          - '**/string_utils.dart'

    - prefer-trailing-comma:
        severity: warning

  # Metrics thresholds
  metrics:
    cyclomatic-complexity: 20
    maintainability-index: 50
    cognitive-complexity: 15
    lines-of-code: 100
```

CLI options override the configuration file settings.

For comprehensive configuration examples, see [EXAMPLE.md](EXAMPLE.md).

## Exit Codes

Anteater uses standard exit codes for CI/CD integration:

| Code | Meaning |
|------|---------|
| 0 | Success (no issues above threshold) |
| 1 | Issues found above threshold |
| 64 | Command line usage error |
| 66 | Path not found |

## Global Installation

```bash
# Install globally from pub.dev (when published)
dart pub global activate anteater

# Or install from local source
dart pub global activate --source path .

# Then run from anywhere
anteater analyze --path /path/to/project
anteater metrics --path /path/to/project
anteater rules --path /path/to/project
anteater debt --path /path/to/project
```

## Library Usage

Anteater can also be used as a library in your Dart/Flutter projects:

```dart
import 'package:anteater/anteater.dart';

// Simple one-liner API
final report = await Anteater.analyzeMetrics('lib');
print('Health Score: ${report.healthScore}');
print('Violations: ${report.violations.length}');

// Run full diagnostics
final result = await Anteater.analyze('lib');
print('Errors: ${result.errorCount}');
print('Warnings: ${result.warningCount}');

// With custom thresholds
final customReport = await Anteater.analyzeMetrics(
  'lib',
  thresholds: MetricsThresholds(
    maxCyclomatic: 15,
    minMaintainability: 60,
    maxCognitive: 10,
    maxLinesOfCode: 80,
  ),
);
```

## Architecture

Anteater uses a 4-stage analysis pipeline:

```
┌─────────────┐    ┌─────────────┐    ┌─────────────────┐    ┌───────────────┐
│  Frontend   │ -> │  IR Builder │ -> │ Semantic Reasoner│ -> │Neural Analyzer│
│ (Dart AST)  │    │   (SSA/CFG) │    │    (Datalog)    │    │   (CodeBERT)  │
└─────────────┘    └─────────────┘    └─────────────────┘    └───────────────┘
```

### Directory Structure

```
lib/
├── frontend/          # Dart source parsing via analyzer package
│   ├── source_loader.dart
│   ├── kernel_reader.dart
│   └── ir_generator.dart
├── ir/
│   ├── cfg/           # Control Flow Graph construction
│   └── ssa/           # SSA transformation (Braun algorithm)
├── reasoner/
│   ├── datalog/       # Datalog engine, points-to, taint tracking
│   └── abstract/      # Abstract interpretation domains
├── rules/             # Style consistency rules
│   ├── rule.dart      # Core types (StyleRule, Violation)
│   ├── rule_runner.dart
│   ├── rule_registry.dart
│   └── rules/         # Rule implementations
├── debt/              # Technical debt analysis
│   ├── debt_item.dart
│   ├── debt_detector.dart
│   ├── cost_calculator.dart
│   └── debt_report.dart
├── metrics/           # Code complexity metrics
├── neural/            # CodeBERT tokenization (planned)
└── server/            # LSP server implementation
```

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| SourceLoader | `lib/frontend/source_loader.dart` | Resolves Dart files using analyzer package |
| CfgBuilder | `lib/ir/cfg/cfg_builder.dart` | Converts AST to Control Flow Graph |
| SsaBuilder | `lib/ir/ssa/ssa_builder.dart` | Transforms CFG to SSA form |
| DatalogEngine | `lib/reasoner/datalog/datalog_engine.dart` | Stratified Datalog evaluation |
| PointsToAnalysis | `lib/reasoner/datalog/points_to_analysis.dart` | Points-to and alias analysis |
| TaintEngineFactory | `lib/reasoner/datalog/datalog_engine.dart` | Security taint tracking |
| AbstractInterpreter | `lib/reasoner/abstract/abstract_interpreter.dart` | Interval analysis with widening/narrowing |

## Analysis Capabilities

### Points-To Analysis

Tracks what heap objects each variable may point to:

```dart
final engine = PointsToEngineFactory.createWithImmutability();
engine.loadFacts(facts);
engine.run();

final pointsTo = engine.query('VarPointsTo');
final immutable = engine.query('DeepImmutable');
```

### Taint Tracking

Detects when untrusted data flows to security-sensitive sinks:

```dart
final engine = TaintEngineFactory.createWithPointsTo();
engine.loadFacts([
  Fact('TaintSource', [userInputVar, 'user_input']),
  Fact('TaintSink', [sqlQueryVar, 'sql_query']),
  // ... assignment facts
]);
engine.run();

final violations = engine.query('TaintViolation');
// Reports: sink reached by tainted data
```

### Abstract Interpretation

Proves array bounds safety and detects potential overflows:

```dart
final analyzer = IntervalAnalyzer(wideningThreshold: 3);
final result = analyzer.analyze(cfg);

// Check if array access is provably safe
final isSafe = analyzer.isArrayAccessSafe(result, blockId, 'index', arrayLength);
```

## Development

### Running Tests

```bash
# Run all tests
dart test

# Run specific test file
dart test test/reasoner/datalog_test.dart

# Run with verbose output
dart test --reporter expanded
```

### Code Style

```bash
# Format code
dart format .

# Analyze for issues
dart analyze
```

The project follows Effective Dart conventions with strict mode enabled.

## Technical References

- **SSA Construction**: Braun et al. "Simple and Efficient Construction of SSA Form"
- **Datalog**: Based on Soufflé semantics with stratified negation
- **Abstract Interpretation**: Cousot & Cousot lattice-theoretic framework
- **Metrics**: McCabe cyclomatic complexity, Halstead science metrics

## License

MIT License
