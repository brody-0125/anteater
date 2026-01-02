// ignore_for_file: unused_local_variable, dead_code, unused_element
// ignore_for_file: require_trailing_commas

/// Example: prefer-trailing-comma
///
/// This file demonstrates the `prefer-trailing-comma` rule.
///
/// ## What It Detects
/// Missing trailing commas in multiline constructs:
/// - Argument lists (function calls)
/// - Parameter lists (function definitions)
/// - List literals
/// - Set/Map literals
///
/// ## What It Does NOT Check
/// - Single-line constructs (no trailing comma needed)
/// - Record literals (not implemented)
/// - Enum declarations (not implemented)
///
/// ## Why It Matters
/// - Better git diffs (adding item doesn't modify previous line)
/// - Easier to add/remove items
/// - Consistent formatting with `dart format`
/// - Prevents merge conflicts
///
/// ## Configuration
/// ```yaml
/// anteater:
///   rules:
///     - prefer-trailing-comma
///     # Or with custom severity:
///     - prefer-trailing-comma:
///         severity: warning
/// ```
///
/// Run with:
/// ```bash
/// anteater analyze -p example/rules/quality/prefer_trailing_comma_example.dart
/// ```
library;

// ============================================================================
// BAD: Missing trailing comma in multiline constructs
// ============================================================================

/// BAD: Multiline function call without trailing comma
void callWithoutTrailingComma() {
  someFunction(
    'first argument',
    'second argument',
    'third argument' // BAD: Missing trailing comma
  );
}

/// BAD: Multiline list literal without trailing comma
final badList = [
  'item1',
  'item2',
  'item3' // BAD: Missing trailing comma
];

/// BAD: Multiline map literal without trailing comma
final badMap = {
  'key1': 'value1',
  'key2': 'value2',
  'key3': 'value3' // BAD: Missing trailing comma
};

/// BAD: Multiline set literal without trailing comma
final badSet = {
  'a',
  'b',
  'c' // BAD: Missing trailing comma
};

/// BAD: Multiline parameter list without trailing comma
void badFunctionDefinition(
  String param1,
  String param2,
  String param3 // BAD: Missing trailing comma
) {
  print('$param1 $param2 $param3');
}

/// BAD: Named parameters without trailing comma
void badNamedParams({
  required String name,
  required int age,
  required bool active // BAD: Missing trailing comma
}) {
  print('$name $age $active');
}

/// BAD: Constructor call without trailing comma
class Person {
  final String name;
  final int age;

  const Person({
    required this.name,
    required this.age // BAD: Missing trailing comma in constructor call
  });
}

final badPerson = Person(
  name: 'John',
  age: 30 // BAD: Missing trailing comma
);

// ============================================================================
// GOOD: With trailing commas
// ============================================================================

/// GOOD: Multiline function call with trailing comma
void callWithTrailingComma() {
  someFunction(
    'first argument',
    'second argument',
    'third argument', // GOOD: Trailing comma present
  );
}

/// GOOD: Multiline list literal with trailing comma
final goodList = [
  'item1',
  'item2',
  'item3', // GOOD: Trailing comma present
];

/// GOOD: Multiline map literal with trailing comma
final goodMap = {
  'key1': 'value1',
  'key2': 'value2',
  'key3': 'value3', // GOOD: Trailing comma present
};

/// GOOD: Multiline set literal with trailing comma
final goodSet = {
  'a',
  'b',
  'c', // GOOD: Trailing comma present
};

/// GOOD: Multiline parameter list with trailing comma
void goodFunctionDefinition(
  String param1,
  String param2,
  String param3, // GOOD: Trailing comma present
) {
  print('$param1 $param2 $param3');
}

/// GOOD: Named parameters with trailing comma
void goodNamedParams({
  required String name,
  required int age,
  required bool active, // GOOD: Trailing comma present
}) {
  print('$name $age $active');
}

/// GOOD: Constructor with trailing comma
class GoodPerson {
  final String name;
  final int age;

  const GoodPerson({
    required this.name,
    required this.age, // GOOD: Trailing comma present
  });
}

final goodPerson = GoodPerson(
  name: 'Jane',
  age: 25, // GOOD: Trailing comma present
);

// ============================================================================
// ACCEPTABLE: Single-line constructs (no trailing comma needed)
// ============================================================================

/// ACCEPTABLE: Single-line function call
void singleLineCall() {
  someFunction('arg1', 'arg2', 'arg3'); // No trailing comma needed
}

/// ACCEPTABLE: Single-line list
final singleLineList = ['a', 'b', 'c']; // No trailing comma needed

/// ACCEPTABLE: Single-line map
final singleLineMap = {'key': 'value'}; // No trailing comma needed

/// ACCEPTABLE: Single-line parameters
void singleLineParams(String a, int b, bool c) {
  print('$a $b $c');
}

/// ACCEPTABLE: Short constructor call
final shortPerson = Person(name: 'X', age: 1);

// ============================================================================
// Why Trailing Commas Matter: Git Diff Example
// ============================================================================

/// Without trailing comma - adding an item:
///
/// ```diff
/// final items = [
///   'item1',
/// -   'item2'
/// +   'item2',
/// +   'item3'
/// ];
/// ```
///
/// With trailing comma - adding an item:
///
/// ```diff
/// final items = [
///   'item1',
///   'item2',
/// +   'item3',
/// ];
/// ```
///
/// The second diff is cleaner - only shows the actual change!

// ============================================================================
// Edge Cases and Limitations
// ============================================================================

/// EDGE CASE: Empty collections (not flagged)
final emptyList = <String>[]; // No elements, no comma needed
final emptyMap = <String, int>{}; // No elements, no comma needed

/// EDGE CASE: Single element multiline (still flagged)
final singleElementList = [
  'only one element' // BAD: Still should have trailing comma
];

/// LIMITATION: Record literals (NOT CHECKED)
///
/// Records are not currently checked by this rule
final record = (
  name: 'John',
  age: 30 // NOT FLAGGED (records not implemented)
);

/// LIMITATION: Enum declarations (NOT CHECKED)
///
/// Enum values are not currently checked
enum Status {
  pending,
  active,
  completed // NOT FLAGGED (enums not implemented)
}

/// EDGE CASE: Nested structures
final nestedStructure = {
  'users': [
    {
      'name': 'John',
      'age': 30 // BAD: Inner map needs trailing comma
    } // BAD: Inner list needs trailing comma
  ] // BAD: Outer map needs trailing comma
};

/// GOOD: Properly nested with trailing commas
final properNestedStructure = {
  'users': [
    {
      'name': 'John',
      'age': 30,
    },
  ],
};

// ============================================================================
// Interaction with dart format
// ============================================================================

/// `dart format` uses trailing commas as a hint for line breaking.
///
/// Without trailing comma:
/// ```dart
/// someFunction(param1, param2, param3);  // Stays single line
/// ```
///
/// With trailing comma:
/// ```dart
/// someFunction(
///   param1,
///   param2,
///   param3,
/// );  // Formatted as multiline
/// ```
///
/// Adding a trailing comma tells `dart format` you WANT multiline formatting.

// ============================================================================
// Common Patterns
// ============================================================================

/// Pattern: Widget constructor (Flutter)
///
/// ```dart
/// Container(
///   width: 100,
///   height: 100,
///   color: Colors.blue,
///   child: Text('Hello'),  // <-- Trailing comma!
/// )
/// ```

/// Pattern: Test assertions
///
/// ```dart
/// expect(
///   result,
///   containsAll([
///     'item1',
///     'item2',
///   ]),  // <-- Trailing comma!
/// );
/// ```

/// Pattern: JSON-like structures
///
/// ```dart
/// final config = {
///   'apiUrl': 'https://api.example.com',
///   'timeout': 30,
///   'retries': 3,
/// };  // <-- Trailing comma!
/// ```

// ============================================================================
// Runnable Demo
// ============================================================================

void main() {
  print('=== prefer-trailing-comma Demo ===\n');

  print('1. Git diff comparison:\n');

  print('   Without trailing comma (messy diff):');
  print("   - 'item2'");
  print("   + 'item2',");
  print("   + 'item3'");

  print('\n   With trailing comma (clean diff):');
  print("   + 'item3',");

  print('\n2. Examples of proper trailing commas:\n');

  print('   List: $goodList');
  print('   Map: $goodMap');
  print('   Set: $goodSet');

  print('\n3. dart format behavior:\n');
  print('   Adding trailing comma → Forces multiline formatting');
  print('   Removing trailing comma → Allows single-line if fits');

  print('\n4. Nested structures benefit most:\n');
  print('   $properNestedStructure');

  print('\nRun "anteater analyze -p example/rules/quality" to see violations.');
}

// Helper function
void someFunction(String a, String b, String c) {
  print('Called with: $a, $b, $c');
}
