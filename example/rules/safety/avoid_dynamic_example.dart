// ignore_for_file: unused_local_variable, dead_code, unused_element

/// Example: avoid-dynamic
///
/// This file demonstrates the `avoid-dynamic` rule.
///
/// ## What It Detects
/// Explicit `dynamic` type annotations that bypass Dart's type system.
///
/// ## Why It Matters
/// - `dynamic` disables compile-time type checking
/// - Runtime errors instead of compile-time errors
/// - IDE autocompletion and refactoring become unreliable
///
/// ## Known Limitations
/// - **Cannot detect implicit dynamic** from type inference failures
/// - Getter/setter return types without annotation are not detected
///
/// ## Configuration
/// ```yaml
/// anteater:
///   rules:
///     - avoid-dynamic
/// ```
///
/// Run with:
/// ```bash
/// anteater analyze -p example/rules/safety/avoid_dynamic_example.dart
/// ```
library;

// ============================================================================
// BAD: Patterns that violate the rule
// ============================================================================

/// BAD: Explicit dynamic type annotation
dynamic globalValue;

/// BAD: Dynamic parameter type
void processDynamic(dynamic input) {
  print(input);
}

/// BAD: Dynamic return type
dynamic getValue() {
  return 42;
}

/// BAD: Dynamic in generic type arguments
void processJson(Map<String, dynamic> json) {
  print(json);
}

/// BAD: List of dynamic
void processList(List<dynamic> items) {
  print(items);
}

/// BAD: Cast to dynamic
void castToDynamic(Object value) {
  // ignore: unnecessary_cast
  final d = value as dynamic;
  print(d);
}

/// BAD: Dynamic in function type
typedef DynamicCallback = dynamic Function(dynamic);

// ============================================================================
// GOOD: Correct patterns
// ============================================================================

/// GOOD: Use Object? for unknown types
Object? safeGlobalValue;

/// GOOD: Use Object? parameter
void processObject(Object? input) {
  print(input);
}

/// GOOD: Explicit return type
int getIntValue() {
  return 42;
}

/// GOOD: Use generic types
void processTypedJson<T>(Map<String, T> json) {
  print(json);
}

/// GOOD: Typed list
void processTypedList(List<Object?> items) {
  print(items);
}

/// GOOD: Use generics for flexibility
T getTypedValue<T>(T value) {
  return value;
}

/// GOOD: Sealed class for type-safe unions (Dart 3.0+)
sealed class Result<T> {}

class Success<T> extends Result<T> {
  Success(this.value);
  final T value;
}

class Failure<T> extends Result<T> {
  Failure(this.error);
  final Object error;
}

// ============================================================================
// Edge Cases and Limitations
// ============================================================================

/// LIMITATION: Implicit dynamic is NOT detected
///
/// The following patterns use implicit dynamic but are NOT flagged
/// because the rule only checks explicit type annotations.
void implicitDynamicExamples() {
  // These are NOT detected (implicit dynamic from inference):

  // Map access returns dynamic when value type is dynamic
  final json = <String, dynamic>{'key': 'value'};
  var x = json['key']; // x is inferred as dynamic - NOT DETECTED

  // Lambda parameters may be inferred as dynamic
  final items = [1, 2, 3];
  // In some contexts, 'e' could be dynamic - NOT DETECTED
  items.map((e) => e.toString());
}

/// EDGE CASE: Getter without explicit return type
///
/// This is NOT detected because there's no explicit `dynamic` annotation.
// get implicitDynamic => 42;  // NOT DETECTED

// ============================================================================
// Recommended Analysis Options
// ============================================================================

/// For stricter dynamic detection, enable these in analysis_options.yaml:
///
/// ```yaml
/// analyzer:
///   language:
///     strict-casts: true        # Error on implicit casts from dynamic
///     strict-inference: true    # Error on inference failures
///     strict-raw-types: true    # Error on raw generic types
/// ```

// ============================================================================
// Runnable Demo
// ============================================================================

void main() {
  print('=== avoid-dynamic Demo ===\n');

  // Demonstrate the difference between dynamic and Object?
  print('1. Dynamic vs Object? behavior:\n');

  dynamic dynamicValue = 'hello';
  Object? objectValue = 'hello';

  // dynamic: No compile-time checking (dangerous)
  print('   dynamic allows: dynamicValue.nonExistentMethod()');
  print('   This compiles but fails at runtime!\n');

  // Object?: Type-safe (recommended)
  print('   Object? requires type check before method access');
  if (objectValue is String) {
    print('   After type check: ${objectValue.toUpperCase()}\n');
  }

  // Demonstrate generic alternative
  print('2. Generic type alternative:\n');
  final intResult = getTypedValue<int>(42);
  final stringResult = getTypedValue<String>('hello');
  print('   getTypedValue<int>(42) = $intResult');
  print('   getTypedValue<String>("hello") = $stringResult\n');

  print('Run "anteater analyze -p example/rules/safety" to see violations.');
}
