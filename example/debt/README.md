# Anteater Technical Debt Examples

Examples demonstrating technical debt detection and cost calculation.

## Running Examples

```bash
# Analyze debt in examples
anteater debt -p example/debt

# Output as JSON
anteater debt -p example/debt -f json

# Generate markdown report
anteater debt -p example/debt -f markdown

# CI gate with threshold
anteater debt -p example/debt --threshold 100 --fail-on-threshold

# Run API example
dart run example/debt/debt_api_example.dart
```

## Debt Types

### Comment-Based Debt

| Type | Default Cost | Severity | Pattern |
|------|-------------|----------|---------|
| TODO | 4 hours | Medium | `// TODO:` or `// TODO ` |
| FIXME | 8 hours | High | `// FIXME:` or `// FIXME ` |
| ignore | 8 hours | High | `// ignore: rule_name` |
| ignore_for_file | 16 hours | Critical | `// ignore_for_file: rule_name` |

**Not detected:** Block comments (`/* TODO */`), doc comments (`/// TODO`), no space/colon (`//TODO`)

### Code-Based Debt

| Type | Default Cost | Severity | Pattern |
|------|-------------|----------|---------|
| as dynamic | 16 hours | High | `x as dynamic` casts |
| deprecated | 2 hours | Medium | `@deprecated` or `@Deprecated()` |

### Metrics-Based Debt

| Type | Threshold | Default Cost | Severity |
|------|-----------|-------------|----------|
| Low Maintainability | MI < 50 | 8 hours | High |
| High Complexity | CC > 20 | 4 hours | Medium |
| High Cognitive | > 15 | 4 hours | Medium |
| Long Method | LOC > 100 | 4 hours | Medium |

## Cost Calculation

```
Total Cost = Base Cost x Severity Multiplier
```

| Severity | Multiplier |
|----------|------------|
| Critical | 4.0x |
| High | 2.0x |
| Medium | 1.0x |
| Low | 0.5x |

## Configuration

```yaml
anteater:
  debt:
    # Cost unit (hours, days, story_points)
    unit: hours

    # Alert threshold
    threshold: 40.0

    # Per-type costs
    costs:
      todo: 4.0
      fixme: 8.0
      ignore: 8.0
      ignore_for_file: 16.0
      as_dynamic: 16.0
      deprecated: 2.0

    # Metrics thresholds
    metrics:
      maintainability_index: 50
      cyclomatic_complexity: 20
      cognitive_complexity: 15
      lines_of_code: 100
```

## Examples

| File | Description |
|------|-------------|
| [comment_debt_example.dart](comment_debt_example.dart) | TODO, FIXME, ignore patterns |
| [code_debt_example.dart](code_debt_example.dart) | as dynamic, @deprecated |
| [metrics_debt_example.dart](metrics_debt_example.dart) | Low MI, high complexity |
| [debt_api_example.dart](debt_api_example.dart) | Full API demonstration |

## See Also

- [EXAMPLE.md](../../EXAMPLE.md) - Full configuration reference
- [Debt API Example](debt_api_example.dart) - Programmatic usage
