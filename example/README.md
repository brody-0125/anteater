# Anteater Examples

Comprehensive examples for Anteater static analysis features.

## Quick Start

```bash
# Run main example
dart run example/example.dart

# Analyze rules examples
anteater analyze -p example/rules

# Calculate metrics
anteater metrics -p example/metrics

# Check technical debt
anteater debt -p example/debt
```

## Directory Structure

| Directory | Description |
|-----------|-------------|
| [`rules/`](rules/) | Lint rule examples (10 rules) |
| [`metrics/`](metrics/) | Code metrics examples |
| [`debt/`](debt/) | Technical debt examples |

## Rules Coverage

### Safety Rules

| Rule | Description | Example |
|------|-------------|---------|
| `avoid-dynamic` | Prevents explicit `dynamic` type usage | [View](rules/safety/avoid_dynamic_example.dart) |
| `avoid-global-state` | Detects mutable top-level/static variables | [View](rules/safety/avoid_global_state_example.dart) |
| `avoid-late-keyword` | Discourages `late` keyword usage | [View](rules/safety/avoid_late_keyword_example.dart) |
| `no-empty-block` | Identifies empty blocks | [View](rules/safety/no_empty_block_example.dart) |
| `no-equal-then-else` | Finds identical if/else branches | [View](rules/safety/no_equal_then_else_example.dart) |

### Quality Rules

| Rule | Description | Example |
|------|-------------|---------|
| `prefer-first-last` | Suggests `.first`/`.last` over `[0]`/`[length-1]` | [View](rules/quality/prefer_first_last_example.dart) |
| `prefer-async-await` | Suggests async/await over `.then()` chains | [View](rules/quality/prefer_async_await_example.dart) |
| `avoid-unnecessary-cast` | Detects redundant type casts | [View](rules/quality/avoid_unnecessary_cast_example.dart) |
| `prefer-trailing-comma` | Enforces trailing commas | [View](rules/quality/prefer_trailing_comma_example.dart) |
| `binary-expression-order` | Detects Yoda conditions | [View](rules/quality/binary_expression_order_example.dart) |

## Metrics Coverage

| Metric | Description | Example |
|--------|-------------|---------|
| Cyclomatic Complexity | Decision point count | [View](metrics/cyclomatic_complexity_example.dart) |
| Cognitive Complexity | Subjective difficulty measure | [View](metrics/cognitive_complexity_example.dart) |
| Halstead Metrics | Informational complexity | [View](metrics/halstead_metrics_example.dart) |
| Maintainability Index | Composite quality score (0-100) | [View](metrics/maintainability_index_example.dart) |
| API Usage | Full API demonstration | [View](metrics/metrics_api_example.dart) |

## Technical Debt Coverage

| Type | Description | Example |
|------|-------------|---------|
| Comment Debt | TODO, FIXME, ignore directives | [View](debt/comment_debt_example.dart) |
| Code Debt | `as dynamic`, `@deprecated` | [View](debt/code_debt_example.dart) |
| Metrics Debt | Low MI, high complexity | [View](debt/metrics_debt_example.dart) |
| API Usage | Full API demonstration | [View](debt/debt_api_example.dart) |

## See Also

- [EXAMPLE.md](../EXAMPLE.md) - Full configuration reference
- [README.md](../README.md) - Project documentation
