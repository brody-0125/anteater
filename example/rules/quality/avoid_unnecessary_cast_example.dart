// ignore_for_file: unused_local_variable, dead_code, unused_element
// ignore_for_file: unnecessary_cast, unnecessary_type_check

/// Example: avoid-unnecessary-cast
///
/// This file demonstrates the `avoid-unnecessary-cast` rule.
///
/// ## What It Detects
/// - Cast after type check: `if (x is T) { x as T }` (use type promotion)
/// - Literal casts: `1 as int` (already that type)
/// - Double casts: `(x as T) as T` (redundant)
/// - `is Object` check (always true for non-null)
///
/// ## Why It Matters
/// - Unnecessary casts add noise to code
/// - Type promotion handles many cases automatically
/// - Can hide actual type issues
///
/// ## Known Limitations
/// - Only detects cast in **immediate statement** after `is` check
/// - Cannot detect if types are structurally equivalent
/// - Requires the `is` check to be in the immediate parent `if` statement
///
/// ## Dart 3.0+ Pattern Matching
/// Modern Dart has pattern matching which eliminates many casts:
/// ```dart
/// if (json['value'] case final int x) {
///   print(x * 2);  // x is already int!
/// }
/// ```
///
/// ## Configuration
/// ```yaml
/// anteater:
///   rules:
///     - avoid-unnecessary-cast
/// ```
///
/// Run with:
/// ```bash
/// anteater analyze -p example/rules/quality/avoid_unnecessary_cast_example.dart
/// ```
library;

// ============================================================================
// BAD: Patterns that violate the rule
// ============================================================================

/// BAD: Cast after type check
void castAfterTypeCheck(Object value) {
  if (value is String) {
    // BAD: value is already promoted to String!
    final str = value as String;
    print(str.toUpperCase());
  }
}

/// BAD: Literal cast - already that type
void literalCasts() {
  // ignore: unnecessary_cast
  final a = 1 as int; // BAD: 1 is already int
  // ignore: unnecessary_cast
  final b = 'hello' as String; // BAD: 'hello' is already String
  // ignore: unnecessary_cast
  final c = true as bool; // BAD: true is already bool
  // ignore: unnecessary_cast
  final d = 3.14 as double; // BAD: 3.14 is already double

  print('$a $b $c $d');
}

/// BAD: Double cast
void doubleCast(Object value) {
  // BAD: Redundant double cast to same type
  final result = (value as String) as String;
  print(result);
}

/// BAD: `is Object` check (always true)
void isObjectCheck(int value) {
  // BAD: is Object is always true for non-null values
  if (value is Object) {
    print('This is always true!');
  }
}

/// BAD: Cast immediately after is check in then block
void unnecessaryCastInBlock(Object data) {
  if (data is List<int>) {
    // BAD: data is already List<int> via type promotion
    final list = data as List<int>;
    print('Sum: ${list.reduce((a, b) => a + b)}');
  }
}

// ============================================================================
// GOOD: Correct patterns
// ============================================================================

/// GOOD: Use type promotion directly
void useTypePromotion(Object value) {
  if (value is String) {
    // GOOD: value is automatically promoted to String
    print(value.toUpperCase()); // No cast needed!
  }
}

/// GOOD: No cast needed for literals
void noLiteralCast() {
  final a = 1; // Type inferred as int
  final b = 'hello'; // Type inferred as String
  final c = true; // Type inferred as bool
  final d = 3.14; // Type inferred as double
  print('$a $b $c $d');
}

/// GOOD: Single cast when needed
void singleCast(Object value) {
  // GOOD: Single cast when type is unknown
  final result = value as String;
  print(result);
}

/// GOOD: Use pattern matching (Dart 3.0+)
void usePatternMatching(Object value) {
  // GOOD: Pattern matching extracts and casts in one step
  if (value case final String str) {
    print(str.toUpperCase());
  }
}

/// GOOD: Switch pattern matching (Dart 3.0+)
void switchPatternMatching(Object value) {
  switch (value) {
    case final int n:
      print('Integer: $n');
    case final String s:
      print('String: ${s.toUpperCase()}');
    case final List<int> list:
      print('List sum: ${list.reduce((a, b) => a + b)}');
    default:
      print('Unknown type');
  }
}

/// GOOD: Check for specific type instead of Object
void specificTypeCheck(Object? value) {
  // GOOD: Check for specific types
  if (value is int && value > 0) {
    print('Positive integer: $value');
  }
}

// ============================================================================
// NECESSARY Casts (Not Flagged)
// ============================================================================

/// NECESSARY: Cast after storing in variable (promotion lost)
void castAfterAssignment(Object value) {
  if (value is String) {
    Object temp = value; // Promotion lost when stored as Object
    // Cast is necessary here
    final str = temp as String;
    print(str.toUpperCase());
  }
}

/// NECESSARY: Field access (fields don't promote)
class Container {
  Object? value;

  void process() {
    if (value is String) {
      // NECESSARY: Fields cannot be promoted (could change)
      final str = value as String;
      print(str.toUpperCase());
    }
  }
}

/// NECESSARY: Downcast from supertype
void downcast(num value) {
  // NECESSARY: Downcasting from num to int
  final intValue = value as int;
  print(intValue.toRadixString(16));
}

/// NECESSARY: Generic type cast
void genericCast<T>(Object value) {
  // NECESSARY: Casting to generic type
  final typed = value as T;
  print('Value: $typed');
}

/// NECESSARY: Dynamic to specific type
void dynamicCast(dynamic value) {
  // NECESSARY: dynamic doesn't promote
  final str = value as String;
  print(str.toUpperCase());
}

// ============================================================================
// Edge Cases and Limitations
// ============================================================================

/// LIMITATION: Not detected if cast is in a different statement
void castInDifferentStatement(Object value) {
  if (value is String) {
    // Some other code here
    print('Doing something else');
    // NOT DETECTED: Cast is not immediately after is check
    final str = value as String;
    print(str);
  }
}

/// LIMITATION: Not detected in nested blocks
void castInNestedBlock(Object value) {
  if (value is String) {
    if (value.isNotEmpty) {
      // NOT DETECTED: Not immediately in the is-check block
      final str = value as String;
      print(str);
    }
  }
}

/// EDGE CASE: Cast to different type (necessary)
void castToDifferentType(Object value) {
  if (value is num) {
    // NECESSARY: Casting to subtype of checked type
    final intValue = value as int;
    print(intValue.isEven);
  }
}

/// EDGE CASE: Null safety casts
void nullSafetyCasts(String? nullable) {
  // NECESSARY: Cast to non-nullable
  if (nullable != null) {
    // Actually not needed - type is promoted
    // But if stored in Object? first:
    Object? temp = nullable;
    if (temp != null) {
      final str = temp as String; // Necessary
      print(str.toUpperCase());
    }
  }
}

// ============================================================================
// Modern Dart 3.0+ Patterns
// ============================================================================

/// Modern: if-case pattern
void ifCasePattern(Object value) {
  // Dart 3.0+ pattern matching
  if (value case final String s when s.isNotEmpty) {
    print('Non-empty string: ${s.toUpperCase()}');
  }
}

/// Modern: Map entry extraction
void mapPatternMatching(Map<String, Object> json) {
  // Dart 3.0+ pattern matching for JSON
  if (json case {'name': final String name, 'age': final int age}) {
    print('$name is $age years old');
  }
}

/// Modern: List pattern
void listPatternMatching(Object value) {
  if (value case [final int first, final int second, ...final rest]) {
    print('First: $first, Second: $second, Rest: $rest');
  }
}

// ============================================================================
// Runnable Demo
// ============================================================================

void main() {
  print('=== avoid-unnecessary-cast Demo ===\n');

  print('1. BAD: Cast after type check\n');
  print('''
  if (value is String) {
    final str = value as String;  // Unnecessary!
    print(str.toUpperCase());
  }
''');

  print('2. GOOD: Use type promotion\n');
  print('''
  if (value is String) {
    print(value.toUpperCase());  // Just use value directly!
  }
''');

  print('3. Demo: Type promotion in action\n');
  final Object mixedValue = 'Hello, World!';
  useTypePromotion(mixedValue);

  print('\n4. Modern: Pattern matching (Dart 3.0+)\n');
  print('''
  if (value case final String s) {
    print(s.toUpperCase());
  }
''');
  usePatternMatching(mixedValue);

  print('\n5. Switch patterns:\n');
  switchPatternMatching(42);
  switchPatternMatching('test');
  switchPatternMatching([1, 2, 3]);

  print('\nRun "anteater analyze -p example/rules/quality" to see violations.');
}
