// ignore_for_file: unused_local_variable, dead_code, unused_element

/// Example: prefer-first-last
///
/// This file demonstrates the `prefer-first-last` rule.
///
/// ## What It Detects
/// - `list[0]` → suggests `.first`
/// - `list[list.length - 1]` → suggests `.last`
///
/// ## Why It Matters
/// - `.first` and `.last` are more readable and expressive
/// - Intent is immediately clear
/// - Standard Dart idiom
///
/// ## CRITICAL LIMITATION: String False Positive
///
/// **This rule produces FALSE POSITIVES for String indexing!**
///
/// ```dart
/// String s = "hello";
/// print(s[0]);  // FLAGGED - but s.first DOES NOT EXIST!
/// ```
///
/// `String` supports `operator[]` but does NOT have `.first` or `.last`.
/// The rule cannot distinguish between `String` and `List` without type info.
///
/// ### Mitigation
/// ```yaml
/// anteater:
///   rules:
///     - prefer-first-last:
///         exclude:
///           - '**/string_utils.dart'
///           - '**/text_*.dart'
/// ```
///
/// ## Configuration
/// ```yaml
/// anteater:
///   rules:
///     - prefer-first-last
/// ```
///
/// Run with:
/// ```bash
/// anteater analyze -p example/rules/quality/prefer_first_last_example.dart
/// ```
library;

// ============================================================================
// BAD: Patterns that violate the rule
// ============================================================================

/// BAD: Using [0] to access first element
void accessFirst(List<String> names) {
  final first = names[0]; // BAD: Use .first instead
  print('First name: $first');
}

/// BAD: Using [length - 1] to access last element
void accessLast(List<int> numbers) {
  final last = numbers[numbers.length - 1]; // BAD: Use .last instead
  print('Last number: $last');
}

/// BAD: In expressions
void processEnds(List<double> values) {
  // BAD: Both patterns in one function
  final sum = values[0] + values[values.length - 1];
  print('Sum of first and last: $sum');
}

/// BAD: With generic list
void genericExample<T>(List<T> items) {
  print('First item: ${items[0]}'); // BAD
  print('Last item: ${items[items.length - 1]}'); // BAD
}

// ============================================================================
// GOOD: Correct patterns
// ============================================================================

/// GOOD: Using .first accessor
void properAccessFirst(List<String> names) {
  final first = names.first; // GOOD: Idiomatic Dart
  print('First name: $first');
}

/// GOOD: Using .last accessor
void properAccessLast(List<int> numbers) {
  final last = numbers.last; // GOOD: Idiomatic Dart
  print('Last number: $last');
}

/// GOOD: Using both .first and .last
void properProcessEnds(List<double> values) {
  final sum = values.first + values.last; // GOOD
  print('Sum of first and last: $sum');
}

/// GOOD: Using firstOrNull/lastOrNull for safety (with extension)
void safeAccess(List<String> items) {
  // GOOD: Safe access that returns null if empty
  final first = items.firstOrNull;
  final last = items.lastOrNull;
  print('First: $first, Last: $last');
}

/// GOOD: Explicit empty check before access
void explicitCheck(List<int> numbers) {
  if (numbers.isNotEmpty) {
    print('First: ${numbers.first}');
    print('Last: ${numbers.last}');
  }
}

// ============================================================================
// CRITICAL: String False Positive
// ============================================================================

/// FALSE POSITIVE: String indexing
///
/// This WILL be flagged, but it's a FALSE POSITIVE!
/// String does NOT have .first or .last properties.
void stringIndexing() {
  const text = 'Hello, World!';

  // FALSE POSITIVE: This will be flagged
  final firstChar = text[0]; // Would suggest text.first - WRONG!

  // FALSE POSITIVE: This will also be flagged
  final lastChar = text[text.length - 1]; // Would suggest text.last - WRONG!

  print('First char: $firstChar, Last char: $lastChar');
}

/// Correct approach for String first/last character
void correctStringAccess() {
  const text = 'Hello, World!';

  // Correct: Use codeUnitAt or substring
  final firstChar = text[0]; // This is fine for String!
  final lastChar = text[text.length - 1]; // This is fine for String!

  // Or use characters package for grapheme clusters:
  // final firstGrapheme = text.characters.first;
  // final lastGrapheme = text.characters.last;

  print('First: $firstChar, Last: $lastChar');
}

// ============================================================================
// Edge Cases and Limitations
// ============================================================================

/// EDGE CASE: Different variables for length
///
/// NOT DETECTED because the rule checks if the same expression
/// is used for both the target and .length
void differentVariables(List<int> a, List<int> b) {
  // NOT DETECTED: a's element at b's length - 1
  final value = a[b.length - 1];
  print(value);
}

/// EDGE CASE: Computed length expression
///
/// NOT DETECTED because the pattern check is strict
void computedLength(List<int> items, int offset) {
  // NOT DETECTED: Complex expression
  final value = items[items.length - 1 - offset];
  print(value);
}

/// EDGE CASE: Property access chain
void propertyChain(Container container) {
  // DETECTED: This should work
  final first = container.items[0];
  final last = container.items[container.items.length - 1];
  print('First: $first, Last: $last');
}

/// EDGE CASE: Method call result
void methodResult() {
  // DETECTED: Method returning List
  final first = getItems()[0];
  print('First: $first');

  // NOT DETECTED for .last because getItems() is called twice
  // (different expressions)
  // final last = getItems()[getItems().length - 1];
}

/// EDGE CASE: Custom indexable types
///
/// FALSE POSITIVE for custom types without .first/.last
class Matrix {
  final List<List<int>> _data;
  Matrix(this._data);

  List<int> operator [](int row) => _data[row];
  int get length => _data.length;
}

void matrixAccess(Matrix matrix) {
  // FALSE POSITIVE: Matrix doesn't have .first
  final firstRow = matrix[0]; // Would suggest matrix.first - WRONG!
  print('First row: $firstRow');
}

// ============================================================================
// When [0] and [length-1] ARE Appropriate
// ============================================================================

/// APPROPRIATE: When you need to modify the element
void modifyFirst(List<int> numbers) {
  numbers[0] = 999; // Cannot use .first for assignment
  numbers[numbers.length - 1] = 888; // Cannot use .last for assignment
}

/// APPROPRIATE: When working with fixed-size known structures
void knownStructure(List<int> coordinate3D) {
  // For a known [x, y, z] structure
  final x = coordinate3D[0];
  final y = coordinate3D[1];
  final z = coordinate3D[2];
  // Here [0] might be clearer than .first
  print('Position: ($x, $y, $z)');
}

// ============================================================================
// Runnable Demo
// ============================================================================

void main() {
  print('=== prefer-first-last Demo ===\n');

  final numbers = [1, 2, 3, 4, 5];

  print('1. BAD: Using [0] and [length - 1]\n');
  print('   numbers[0] = ${numbers[0]}');
  print('   numbers[numbers.length - 1] = ${numbers[numbers.length - 1]}');

  print('\n2. GOOD: Using .first and .last\n');
  print('   numbers.first = ${numbers.first}');
  print('   numbers.last = ${numbers.last}');

  print('\n3. CRITICAL: String false positive\n');
  const text = 'Hello';
  print('   text[0] = "${text[0]}" (flagged but correct for String!)');
  print('   text.first would NOT work - String has no .first property');

  print('\n4. Safe access with empty check:\n');
  final empty = <int>[];
  print('   empty list: $empty');
  print('   empty.firstOrNull = ${empty.firstOrNull}');
  // print('   empty.first would throw StateError!');

  print('\nRun "anteater analyze -p example/rules/quality" to see violations.');
}

// Helper classes and functions
class Container {
  List<int> items = [1, 2, 3];
}

List<int> getItems() => [1, 2, 3];
