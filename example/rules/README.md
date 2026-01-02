# Anteater Rules Examples

Examples demonstrating all 10 lint rules provided by Anteater.

## Running Examples

```bash
# Analyze all rules examples
anteater analyze -p example/rules

# Analyze safety rules only
anteater analyze -p example/rules/safety

# Analyze quality rules only
anteater analyze -p example/rules/quality

# Output as JSON
anteater analyze -p example/rules -f json
```

## Safety Rules

Rules focused on type safety and error prevention.

| Rule | Severity | Description |
|------|----------|-------------|
| [`avoid-dynamic`](safety/avoid_dynamic_example.dart) | warning | Prevents explicit `dynamic` type annotations |
| [`avoid-global-state`](safety/avoid_global_state_example.dart) | warning | Detects mutable top-level and static variables |
| [`avoid-late-keyword`](safety/avoid_late_keyword_example.dart) | info | Discourages `late` without initializers |
| [`no-empty-block`](safety/no_empty_block_example.dart) | warning/info | Identifies empty blocks needing implementation |
| [`no-equal-then-else`](safety/no_equal_then_else_example.dart) | warning | Finds redundant if/else with identical branches |

## Quality Rules

Rules focused on code quality and readability.

| Rule | Severity | Description |
|------|----------|-------------|
| [`prefer-first-last`](quality/prefer_first_last_example.dart) | info | Suggests `.first`/`.last` accessors |
| [`prefer-async-await`](quality/prefer_async_await_example.dart) | info | Suggests async/await over `.then()` chains |
| [`avoid-unnecessary-cast`](quality/avoid_unnecessary_cast_example.dart) | info | Detects redundant type casts |
| [`prefer-trailing-comma`](quality/prefer_trailing_comma_example.dart) | info | Enforces trailing commas in multiline |
| [`binary-expression-order`](quality/binary_expression_order_example.dart) | info | Detects Yoda conditions |

## Configuration

```yaml
anteater:
  rules:
    # Enable with default severity
    - avoid-dynamic
    - avoid-global-state

    # Override severity
    - prefer-trailing-comma:
        severity: warning

    # Exclude specific files
    - avoid-late-keyword:
        exclude:
          - '**/generated/**'
```

## Known Limitations

1. **avoid-dynamic**: Cannot detect implicit dynamic from type inference
2. **prefer-first-last**: May flag String indexing (String has no `.first`/`.last`)
3. **avoid-unnecessary-cast**: Only detects casts in immediate statements after `is` check

See individual example files for detailed limitations.
