# Anteater Metrics Examples

Examples demonstrating code quality metrics calculation.

## Running Examples

```bash
# Calculate metrics for examples
anteater metrics -p example/metrics

# With custom thresholds
anteater metrics -p example/metrics --threshold-cc 15 --threshold-mi 60

# Run API example
dart run example/metrics/metrics_api_example.dart
```

## Metrics Overview

| Metric | Description | Default Threshold |
|--------|-------------|-------------------|
| [Cyclomatic Complexity](cyclomatic_complexity_example.dart) | Decision point count | > 20 |
| [Cognitive Complexity](cognitive_complexity_example.dart) | Subjective difficulty | > 15 |
| [Halstead Volume](halstead_metrics_example.dart) | Informational size | - |
| [Maintainability Index](maintainability_index_example.dart) | Composite score (0-100) | < 50 |
| Lines of Code | Function size | > 100 |

## Cyclomatic Complexity

Counts linearly independent paths through code.

| Element | Weight |
|---------|--------|
| Base function | 1 |
| `if`, `for`, `while`, `do-while` | +1 |
| Each `switch case` (not default) | +1 |
| `catch` clause | +1 |
| `?:` ternary | +1 |
| `&&`, `\|\|` | +1 |
| `?.`, `??`, `??=` | +1 |

**NOT counted:** `await`, `try` block, `finally`, `switch` statement itself

## Cognitive Complexity

Measures how difficult code is to understand.

| Element | Weight |
|---------|--------|
| Control flow (if, for, while) at level 0 | +1 |
| Control flow at level 1 | +2 |
| Control flow at level 2 | +3 |
| Logical operators (entire sequence) | +1 |
| Switch statement (entire) | +1 |
| Lambda/closure | +nesting level |

## Maintainability Index

Composite score combining multiple metrics.

```
MI = max(0, (171 - 5.2*ln(V) - 0.23*G - 16.2*ln(LOC)) * 100/171)
```

| Rating | Score | Interpretation |
|--------|-------|----------------|
| Good | >= 80 | Easy to maintain |
| Moderate | 50-79 | Needs attention |
| Poor | < 50 | Difficult to maintain |

## Halstead Metrics

Information-theoretic complexity measures.

| Metric | Formula | Meaning |
|--------|---------|---------|
| Vocabulary (n) | n1 + n2 | Unique tokens |
| Length (N) | N1 + N2 | Total tokens |
| Volume (V) | N * log2(n) | Information content |
| Difficulty (D) | (n1/2) * (N2/n2) | Error-proneness |
| Effort (E) | D * V | Mental effort |

## See Also

- [EXAMPLE.md](../../EXAMPLE.md) - Configuration reference
- [Metrics API Example](metrics_api_example.dart) - Programmatic usage
