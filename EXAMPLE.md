# Anteater Configuration Examples

This document provides comprehensive configuration examples and usage patterns for Anteater.

## Table of Contents

- [Quick Start](#quick-start)
- [Configuration File](#configuration-file)
- [Style Rules](#style-rules)
- [Metrics Thresholds](#metrics-thresholds)
- [CLI Usage](#cli-usage)
- [Library Usage](#library-usage)
- [CI/CD Integration](#cicd-integration)

---

## Quick Start

### Minimal Configuration

Add to your `analysis_options.yaml`:

```yaml
anteater:
  rules:
    - avoid-dynamic
    - avoid-global-state
    - no-empty-block
```

Run analysis:

```bash
anteater rules --path lib
```

---

## Configuration File

Anteater is configured via `analysis_options.yaml` in your project root.

### Full Configuration Example

```yaml
anteater:
  # Global file exclusions (applied to all rules)
  exclude:
    - '**.g.dart'           # Generated files
    - '**.freezed.dart'     # Freezed generated
    - '**.mocks.dart'       # Mockito mocks
    - 'build/**'            # Build output
    - '.dart_tool/**'       # Dart tooling

  # Style rules configuration
  rules:
    # Safety rules - recommended for all projects
    - avoid-dynamic
    - avoid-global-state
    - avoid-late-keyword
    - no-empty-block
    - no-equal-then-else

    # Quality rules - enable based on project needs
    - prefer-first-last
    - prefer-async-await
    - avoid-unnecessary-cast
    - prefer-trailing-comma
    - binary-expression-order

  # Metrics thresholds
  metrics:
    cyclomatic-complexity: 20    # Max cyclomatic complexity
    cognitive-complexity: 15     # Max cognitive complexity
    maintainability-index: 50    # Min maintainability index (0-100)
    source-lines-of-code: 50     # Max lines per function
    maximum-nesting: 5           # Max nesting depth
    number-of-parameters: 4      # Max function parameters
    number-of-methods: 20        # Max methods per class
    halstead-volume: 150         # Max Halstead volume
```

---

## Style Rules

### Safety Rules

#### avoid-dynamic

Detects explicit `dynamic` type usage.

```yaml
anteater:
  rules:
    - avoid-dynamic
```

**Detected:**
```dart
dynamic value;                    // Warning
Map<String, dynamic> json;        // Warning (nested)
void process(dynamic input) {}    // Warning
value as dynamic;                 // Warning
```

**Not detected (by design):**
```dart
var x = json['key'];              // Inferred dynamic - not detected
Object? value;                    // OK - use Object? instead
```

---

#### avoid-global-state

Detects mutable top-level and static variables.

```yaml
anteater:
  rules:
    - avoid-global-state
```

**Detected:**
```dart
var globalCounter = 0;            // Warning
int mutableState = 0;             // Warning

class Service {
  static int instanceCount = 0;   // Warning
}
```

**Allowed:**
```dart
final globalConfig = Config();    // OK - final
const maxRetries = 3;             // OK - const
late final logger = Logger();     // OK - late final (lazy init)
```

---

#### avoid-late-keyword

Detects `late` keyword except for lazy initialization pattern.

```yaml
anteater:
  rules:
    - avoid-late-keyword
```

**Detected:**
```dart
late String name;                 // Warning - no initializer
late int count;                   // Warning
```

**Allowed:**
```dart
late final logger = Logger();     // OK - lazy initialization
late final config = loadConfig(); // OK - lazy initialization
```

---

#### no-empty-block

Detects empty blocks without comments.

```yaml
anteater:
  rules:
    - no-empty-block
```

**Detected:**
```dart
if (condition) {}                 // Warning

try {
  risky();
} catch (e) {}                    // Warning - empty catch

for (var i = 0; i < 10; i++) {}   // Warning
```

**Allowed:**
```dart
if (condition) {
  // TODO: implement later
}

try {
  risky();
} catch (e) {
  // Intentionally ignored
}
```

---

#### no-equal-then-else

Detects identical if/else branches.

```yaml
anteater:
  rules:
    - no-equal-then-else
```

**Detected:**
```dart
if (condition) {
  doSomething();
} else {
  doSomething();                  // Warning - identical to then branch
}
```

---

### Quality Rules

#### prefer-first-last

Suggests `.first`/`.last` over index access.

```yaml
anteater:
  rules:
    - prefer-first-last:
        severity: info
        exclude:
          - '**/string_utils.dart'  # Exclude string manipulation files
```

**Detected:**
```dart
final first = list[0];            // Info - use list.first
final last = list[list.length - 1]; // Info - use list.last
```

**Note:** May false-positive on String indexing (Strings don't have `.first`/`.last`).

---

#### prefer-async-await

Suggests async/await over chained `.then()` calls.

```yaml
anteater:
  rules:
    - prefer-async-await
```

**Detected:**
```dart
fetchData().then((data) {
  process(data);
}).then((result) {                // Warning - use async/await
  return result;
});
```

**Preferred:**
```dart
final data = await fetchData();
final result = await process(data);
return result;
```

---

#### avoid-unnecessary-cast

Detects redundant type casts.

```yaml
anteater:
  rules:
    - avoid-unnecessary-cast
```

**Detected:**
```dart
final x = 42 as int;              // Warning - literal already int
final y = (value as String) as String; // Warning - double cast

if (obj is String) {
  print(obj as String);           // Warning - already promoted
}
```

---

#### prefer-trailing-comma

Enforces trailing commas in multi-line constructs.

```yaml
anteater:
  rules:
    - prefer-trailing-comma:
        severity: warning
```

**Detected:**
```dart
final list = [
  'item1',
  'item2',
  'item3'                         // Warning - add trailing comma
];

Widget build() {
  return Container(
    child: Text('Hello')          // Warning - add trailing comma
  );
}
```

**Preferred:**
```dart
final list = [
  'item1',
  'item2',
  'item3',                        // OK - trailing comma
];
```

---

#### binary-expression-order

Detects Yoda conditions (literal on left side).

```yaml
anteater:
  rules:
    - binary-expression-order
```

**Detected:**
```dart
if (0 == count) {}                // Info - prefer: count == 0
if (null == value) {}             // Info - prefer: value == null
if ('admin' == role) {}           // Info - prefer: role == 'admin'
```

---

## Metrics Thresholds

### Default Values

| Metric | Default | Description |
|--------|---------|-------------|
| `cyclomatic-complexity` | 20 | Max branches per function |
| `cognitive-complexity` | 15 | Max cognitive load |
| `maintainability-index` | 50 | Min maintainability (0-100) |
| `source-lines-of-code` | 50 | Max lines per function |
| `maximum-nesting` | 5 | Max nesting depth |
| `number-of-parameters` | 4 | Max function parameters |
| `number-of-methods` | 20 | Max methods per class |
| `halstead-volume` | 150 | Max Halstead volume |

### Strict Configuration

For high-quality codebases:

```yaml
anteater:
  metrics:
    cyclomatic-complexity: 10
    cognitive-complexity: 8
    maintainability-index: 70
    source-lines-of-code: 30
    maximum-nesting: 3
    number-of-parameters: 3
    number-of-methods: 15
    halstead-volume: 100
```

### Relaxed Configuration

For legacy or generated code:

```yaml
anteater:
  metrics:
    cyclomatic-complexity: 30
    cognitive-complexity: 25
    maintainability-index: 40
    source-lines-of-code: 100
    maximum-nesting: 7
    number-of-parameters: 6
    number-of-methods: 30
    halstead-volume: 200
```

---

## CLI Usage

### Basic Commands

```bash
# Run style rules
anteater rules --path lib

# Calculate metrics
anteater metrics --path lib

# Full analysis
anteater analyze --path lib

# Start LSP server
anteater server
```

### Output Formats

```bash
# Text output (default)
anteater rules --path lib --format text

# JSON output (for programmatic processing)
anteater rules --path lib --format json

# HTML report
anteater analyze --path lib --format html --output report.html
```

### Watch Mode

```bash
# Re-run on file changes
anteater rules --path lib --watch
anteater metrics --path lib --watch
```

### CI/CD Flags

```bash
# Exit code control
anteater analyze --path lib --no-fatal-warnings  # Warnings don't fail
anteater analyze --path lib --no-fatal-infos     # Info don't fail

# Quiet mode (suppress progress output)
anteater analyze --path lib --quiet

# Custom thresholds (override config)
anteater metrics --path lib --threshold-cc 15 --threshold-mi 60
```

---

## Library Usage

### Basic Usage

```dart
import 'package:anteater/anteater.dart';

// One-liner metrics analysis
final report = await Anteater.analyzeMetrics('lib');
print('Health Score: ${report.healthScore}');
print('Violations: ${report.violations.length}');

// Full diagnostics
final result = await Anteater.analyze('lib');
print('Errors: ${result.errorCount}');
print('Warnings: ${result.warningCount}');
```

### Custom Thresholds

```dart
final report = await Anteater.analyzeMetrics(
  'lib',
  thresholds: MetricsThresholds(
    maxCyclomatic: 15,
    minMaintainability: 60,
    maxCognitive: 10,
    maxLinesOfCode: 80,
  ),
);
```

### Using Style Rules Directly

```dart
import 'package:anteater/rules.dart';

// Create registry with default rules
final registry = RuleRegistry.withDefaults();

// Configure rules
registry.disable('prefer-trailing-comma');
registry.setSeverity('avoid-dynamic', RuleSeverity.error);

// Create runner
final runner = RuleRunner(registry: registry);

// Analyze a compilation unit
final violations = runner.analyze(unit, lineInfo: lineInfo);

for (final v in violations) {
  print('${v.ruleId}: ${v.message} at ${v.location}');
}
```

### Loading Configuration

```dart
import 'package:anteater/rules.dart';

// Load from YAML file
final config = await RuleConfig.loadFromFile('analysis_options.yaml');

// Apply to registry
final registry = RuleRegistry.withDefaults();
config.applyTo(registry);

// Or load from directory
final config2 = await RuleConfig.loadFromDirectory('/path/to/project');
```

---

## CI/CD Integration

### GitHub Actions

```yaml
name: Anteater Analysis

on: [push, pull_request]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1

      - name: Install dependencies
        run: dart pub get

      - name: Install Anteater
        run: dart pub global activate anteater

      - name: Run style rules
        run: anteater rules --path lib --format json > rules-report.json

      - name: Run metrics
        run: anteater metrics --path lib --format json > metrics-report.json

      - name: Check for violations
        run: anteater analyze --path lib --no-fatal-infos
```

### GitLab CI

```yaml
anteater:
  image: dart:stable
  script:
    - dart pub get
    - dart pub global activate anteater
    - anteater rules --path lib
    - anteater metrics --path lib
  artifacts:
    reports:
      codequality: anteater-report.json
```

### Pre-commit Hook

```bash
#!/bin/sh
# .git/hooks/pre-commit

echo "Running Anteater..."
anteater rules --path lib --quiet

if [ $? -ne 0 ]; then
  echo "Anteater found issues. Please fix before committing."
  exit 1
fi
```

---

## Project-Specific Examples

### Flutter Project

```yaml
anteater:
  exclude:
    - '**.g.dart'
    - '**.freezed.dart'
    - 'lib/generated/**'
    - 'test/**'

  rules:
    - avoid-dynamic
    - avoid-global-state
    - prefer-trailing-comma:
        severity: warning
    - no-empty-block

  metrics:
    cyclomatic-complexity: 15
    cognitive-complexity: 10
```

### Backend/Server Project

```yaml
anteater:
  exclude:
    - '**.g.dart'
    - 'bin/**'

  rules:
    - avoid-dynamic:
        severity: error
    - avoid-global-state:
        severity: error
    - avoid-late-keyword
    - no-empty-block
    - prefer-async-await

  metrics:
    cyclomatic-complexity: 20
    maintainability-index: 60
```

### Library Package

```yaml
anteater:
  exclude:
    - 'example/**'
    - 'test/**'

  rules:
    - avoid-dynamic:
        severity: error
    - avoid-global-state:
        severity: error
    - prefer-first-last
    - binary-expression-order

  metrics:
    cyclomatic-complexity: 15
    maintainability-index: 70
    number-of-parameters: 4
```
