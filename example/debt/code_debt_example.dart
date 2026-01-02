// ignore_for_file: unused_local_variable, dead_code, unused_element

/// Example: Code-Based Technical Debt
///
/// This file demonstrates code patterns detected as technical debt.
///
/// ## Detected Patterns
///
/// | Pattern | Severity | Base Cost |
/// |---------|----------|-----------|
/// | `as dynamic` | High | 16 hours |
/// | `@deprecated` | Medium | 2 hours |
/// | `@Deprecated('message')` | Medium | 2 hours |
///
/// ## Detection Mechanism
///
/// **`as dynamic` casts**:
/// - Detected via `AsExpression` visitor
/// - Checks if target type is `dynamic`
/// - Records enclosing function/method context
///
/// **`@deprecated` annotations**:
/// - Detected via `Annotation` visitor
/// - Matches both `@deprecated` and `@Deprecated(...)`
/// - Records annotated declaration name
///
/// Run with:
/// ```bash
/// anteater debt -p example/debt/code_debt_example.dart
/// ```
library;

// ============================================================================
// `as dynamic` Casts (Severity: High)
// ============================================================================

/// `as dynamic` casts bypass type safety.
/// Cost: 16 hours base × 2.0 (high) = 32 hours
class AsDynamicExamples {
  /// Detected: Explicit cast to dynamic
  void explicitCast() {
    Object value = 'hello';
    var result = value as dynamic; // DETECTED
    print(result.length); // No type checking
  }

  /// Detected: Cast in expression
  void processValue(Object obj) {
    final result = (obj as dynamic).someMethod(); // DETECTED
    print(result);
  }

  /// Detected: Cast in function call
  void callWithDynamic(Object data) {
    processData(data as dynamic); // DETECTED
  }

  /// Detected: Multiple casts in one function
  void multipleCasts(Object a, Object b) {
    final x = a as dynamic; // DETECTED (1)
    final y = b as dynamic; // DETECTED (2)
    print('$x $y');
  }
}

void processData(dynamic data) => print(data);

// ============================================================================
// Why `as dynamic` is Debt
// ============================================================================

/// ## Problems with `as dynamic`
///
/// 1. **No compile-time type checking**
///    - Errors only discovered at runtime
///    - IDE autocomplete doesn't work
///
/// 2. **Maintenance burden**
///    - Unclear what methods/properties are expected
///    - Refactoring becomes risky
///
/// 3. **Testing difficulty**
///    - Cannot rely on type system for correctness
///    - Need more runtime tests
///
/// ## Better Alternatives

class BetterAlternatives {
  /// GOOD: Use specific type
  void withSpecificType(Object obj) {
    if (obj is String) {
      print(obj.length); // Type promoted
    }
  }

  /// GOOD: Use pattern matching (Dart 3.0+)
  String processWithPattern(Object obj) {
    return switch (obj) {
      String s => 'String: ${s.length}',
      int i => 'Int: $i',
      _ => 'Unknown',
    };
  }

  /// GOOD: Use generic type
  T process<T>(T value) {
    return value;
  }
}

// ============================================================================
// @deprecated Annotations (Severity: Medium)
// ============================================================================

/// @deprecated marks APIs that should no longer be used.
/// Cost: 2 hours base × 1.0 (medium) = 2 hours

/// Detected: Simple @deprecated annotation
@deprecated
void oldFunction() {
  // This function is deprecated
}

/// Detected: @Deprecated with message
@Deprecated('Use newFunction() instead. Will be removed in v2.0.')
void oldFunctionWithMessage() {
  // This function has a deprecation message
}

/// Detected: Deprecated class
@deprecated
class OldClass {
  void method() {}
}

/// Detected: Deprecated class with message
@Deprecated('Migrate to NewService by Q2 2024')
class LegacyService {
  void doSomething() {}
}

/// Detected: Deprecated method
class ServiceWithDeprecation {
  @deprecated
  void oldMethod() {}

  @Deprecated('Use processV2 instead')
  void process() {}

  void processV2() {
    // New implementation
  }
}

/// Detected: Deprecated field
class ModelWithDeprecation {
  @deprecated
  final String oldField;

  @Deprecated('Use newName instead')
  final String legacyName;

  final String newName;

  ModelWithDeprecation({
    this.oldField = '',
    this.legacyName = '',
    this.newName = '',
  });
}

/// Detected: Deprecated getter/setter
class PropertyDeprecation {
  String _value = '';

  @deprecated
  String get oldValue => _value;

  @deprecated
  set oldValue(String v) => _value = v;

  String get value => _value;
  set value(String v) => _value = v;
}

// ============================================================================
// Why @deprecated is Debt
// ============================================================================

/// ## Problems with Deprecated Code
///
/// 1. **Maintenance burden**
///    - Must maintain two implementations (old + new)
///    - Increases codebase size
///
/// 2. **Migration pressure**
///    - Clients need to migrate
///    - Removal deadline creates work
///
/// 3. **Documentation overhead**
///    - Need to document migration path
///    - Keep deprecation messages updated
///
/// ## Best Practices

class DeprecationBestPractices {
  /// GOOD: Include migration guidance
  @Deprecated('Use fetchDataV2(). Migration: Replace fetch() calls with fetchDataV2().')
  Future<void> fetch() async {}

  Future<void> fetchDataV2() async {}

  /// GOOD: Set removal timeline
  @Deprecated('Will be removed in v3.0. Use newApi() instead.')
  void legacyApi() {}

  void newApi() {}
}

// ============================================================================
// NOT Detected Patterns
// ============================================================================

/// These patterns are NOT detected as code debt:

class NotDetectedExamples {
  /// Cast to Object (not dynamic) - NOT DETECTED
  void castToObject(String s) {
    var obj = s as Object;
  }

  /// Cast to specific type - NOT DETECTED
  void castToSpecific(Object obj) {
    var str = obj as String;
  }

  /// Dynamic parameter (without cast) - NOT DETECTED
  /// (This would be detected by avoid-dynamic rule, not debt detector)
  void acceptsDynamic(dynamic value) {
    print(value);
  }

  /// Dynamic return type - NOT DETECTED by debt detector
  dynamic returnsDynamic() => 42;
}

// ============================================================================
// Context Tracking
// ============================================================================

/// The detector tracks the enclosing context for better reporting.

class ContextExample {
  void methodWithCast() {
    var x = getData() as dynamic;
    // Reported as: ContextExample.methodWithCast
  }
}

void topLevelFunctionWithCast() {
  var x = getData() as dynamic;
  // Reported as: topLevelFunctionWithCast
}

Object getData() => 'data';

// ============================================================================
// Cost Calculation Reference
// ============================================================================

/// ## Default Cost Configuration
///
/// | Type | Base Cost | Default Severity | Multiplier | Total |
/// |------|-----------|------------------|------------|-------|
/// | as dynamic | 16 hours | High | 2.0x | 32 hours |
/// | @deprecated | 2 hours | Medium | 1.0x | 2 hours |
///
/// ## Rationale
///
/// - **`as dynamic`**: High cost because it completely bypasses type safety
/// - **`@deprecated`**: Lower cost because it's a planned transition

// ============================================================================
// Runnable Demo
// ============================================================================

void main() {
  print('=== Code-Based Debt Demo ===\n');

  print('1. Detected Patterns:\n');
  print('   obj as dynamic          → High severity (32 hours)');
  print('   @deprecated             → Medium severity (2 hours)');
  print('   @Deprecated("message")  → Medium severity (2 hours)');

  print('\n2. NOT Detected:\n');
  print('   obj as String           → Specific type cast OK');
  print('   dynamic param           → Use avoid-dynamic rule');
  print('   dynamic return          → Use avoid-dynamic rule');

  print('\n3. as dynamic Problems:\n');
  print('   - No compile-time checking');
  print('   - No IDE autocomplete');
  print('   - Runtime errors only');

  print('\n4. Better Alternatives:\n');
  print('   - Type checks: if (obj is String)');
  print('   - Pattern matching: switch (obj) { String s => ... }');
  print('   - Generics: T process<T>(T value)');

  print('\n5. @deprecated Best Practices:\n');
  print('   - Include migration guidance');
  print('   - Set removal timeline');
  print('   - Document replacement API');

  print('\nRun "anteater debt -p example/debt" for full analysis.');
}
