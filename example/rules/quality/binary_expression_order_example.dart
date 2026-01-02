// ignore_for_file: unused_local_variable, dead_code, unused_element

/// Example: binary-expression-order
///
/// This file demonstrates the `binary-expression-order` rule.
///
/// ## What It Detects
/// "Yoda conditions" - literal values on the LEFT side of comparisons:
/// - `0 == x` instead of `x == 0`
/// - `null != value` instead of `value != null`
///
/// ## Operators Checked
/// Only comparison operators: `==`, `!=`, `<`, `>`, `<=`, `>=`
///
/// ## What It Does NOT Detect
/// - Identifier constants: `CONSTANT == x` (cannot tell it's a constant)
/// - Variables on both sides: `a == b`
/// - Non-comparison operators: `+`, `-`, `*`, etc.
///
/// ## Why It Matters
/// - Yoda conditions originated in C to prevent `if (x = 0)` typo
/// - Dart doesn't allow assignment in conditions → Yoda unnecessary
/// - `x == 0` reads more naturally as "x equals zero"
///
/// ## Configuration
/// ```yaml
/// anteater:
///   rules:
///     - binary-expression-order
/// ```
///
/// Run with:
/// ```bash
/// anteater analyze -p example/rules/quality/binary_expression_order_example.dart
/// ```
library;

// ============================================================================
// BAD: Yoda conditions (literal on left)
// ============================================================================

/// BAD: Integer literal on left
bool isZero(int value) {
  return 0 == value; // BAD: Yoda condition, should be: value == 0
}

/// BAD: String literal on left
bool isAdmin(String role) {
  return 'admin' == role; // BAD: Should be: role == 'admin'
}

/// BAD: Null literal on left
bool isNull(String? text) {
  return null == text; // BAD: Should be: text == null
}

/// BAD: Boolean literal on left
bool isFalse(bool flag) {
  return false == flag; // BAD: Should be: flag == false (or just !flag)
}

/// BAD: Numeric comparison literals
bool isPositive(int value) {
  return 0 < value; // BAD: Should be: value > 0
}

/// BAD: Less than or equal with literal
bool isInRange(int value) {
  return 0 <= value && 100 >= value; // BAD: Both conditions are Yoda
}

/// BAD: Not equal with literal
bool isNotEmpty(int length) {
  return 0 != length; // BAD: Should be: length != 0
}

/// BAD: Double literal
bool isUnit(double value) {
  return 1.0 == value; // BAD: Should be: value == 1.0
}

/// BAD: Negative literal
bool isNegativeOne(int value) {
  return -1 == value; // BAD: Should be: value == -1
}

// ============================================================================
// GOOD: Natural order (variable on left)
// ============================================================================

/// GOOD: Variable equals literal
bool goodIsZero(int value) {
  return value == 0; // GOOD: Reads naturally
}

/// GOOD: Variable equals string
bool goodIsAdmin(String role) {
  return role == 'admin'; // GOOD: "role equals admin"
}

/// GOOD: Null check - natural order
bool goodIsNull(String? text) {
  return text == null; // GOOD: "text equals null"
}

/// GOOD: Better - use comparison operators
bool betterIsNull(String? text) {
  return text == null; // Or even better in some contexts:
  // return text?.isEmpty ?? true;
}

/// GOOD: Comparison - variable on left
bool goodIsPositive(int value) {
  return value > 0; // GOOD: "value is greater than 0"
}

/// GOOD: Range check - natural order
bool goodIsInRange(int value) {
  return value >= 0 && value <= 100; // GOOD: Natural reading
}

/// GOOD: Not equal - natural order
bool goodIsNotEmpty(int length) {
  return length != 0; // GOOD: "length not equal to 0"
  // Even better: return length > 0;
}

// ============================================================================
// ACCEPTABLE: Both sides are variables or expressions
// ============================================================================

/// ACCEPTABLE: Both sides are variables
bool areEqual(int a, int b) {
  return a == b; // No literal, no Yoda issue
}

/// ACCEPTABLE: Expression on both sides
bool compareExpressions(int x, int y) {
  return x + 1 == y - 1; // Both sides are expressions
}

/// ACCEPTABLE: Method call result
bool checkResult(List<int> list) {
  return list.length == list.toSet().length; // Both are expressions
}

// ============================================================================
// LIMITATION: Identifier constants NOT detected
// ============================================================================

/// LIMITATION: Constant identifier on left - NOT DETECTED
///
/// The rule cannot distinguish identifiers that are constants
/// because it doesn't have type information.
const int maxValue = 100;
const String adminRole = 'admin';

bool checkMaxValue(int value) {
  // NOT DETECTED: maxValue looks like a variable to the rule
  return maxValue == value; // This is technically Yoda, but not flagged
}

bool checkAdminRole(String role) {
  // NOT DETECTED: adminRole looks like a variable
  return adminRole == role;
}

/// Recommendation: Still prefer variable on left for consistency
bool recommendedMaxCheck(int value) {
  return value == maxValue; // GOOD: Consistent style
}

// ============================================================================
// Why Yoda Conditions Exist (Historical Context)
// ============================================================================

/// In C, this is a common bug:
///
/// ```c
/// if (x = 0) {  // BUG: Assignment, not comparison!
///   // This never executes because x is now 0 (falsy)
/// }
/// ```
///
/// Yoda condition prevents this:
///
/// ```c
/// if (0 = x) {  // COMPILE ERROR: Cannot assign to literal
///   // This bug is caught at compile time
/// }
/// ```
///
/// In Dart, assignment in conditions is NOT ALLOWED:
///
/// ```dart
/// if (x = 0) {  // COMPILE ERROR in Dart!
///   // Dart already prevents this bug
/// }
/// ```
///
/// Therefore, Yoda conditions provide no safety benefit in Dart,
/// they only reduce readability.

// ============================================================================
// Edge Cases
// ============================================================================

/// EDGE CASE: Null-aware operators
void nullAwareOperators(String? text) {
  // These are not Yoda conditions (not comparison operators)
  final length = text?.length ?? 0;
  final value = text ?? 'default';
  print('$length $value');
}

/// EDGE CASE: Ternary operator (not checked)
String ternaryExample(int value) {
  // This rule doesn't check ternary conditions
  return 0 == value ? 'zero' : 'non-zero'; // NOT flagged by this rule
  // (might be flagged by no-equal-then-else if branches were same)
}

/// EDGE CASE: Chained comparisons
bool chainedComparison(int value) {
  // Each comparison is checked separately
  return 0 < value && value < 100; // First part is Yoda
}

/// EDGE CASE: Negated comparisons
bool negatedComparison(int value) {
  return !(0 == value); // BAD: Yoda inside negation
  // Better: return value != 0;
}

// ============================================================================
// Best Practices
// ============================================================================

/// Best practice 1: Use idiomatic null checks
void nullCheckBestPractice(String? text) {
  // Good
  if (text != null) {
    print(text);
  }

  // Even better in many cases
  if (text case final String t) {
    print(t);
  }
}

/// Best practice 2: Use meaningful comparisons
void meaningfulComparisons(int count, List<String> items) {
  // Good: Reads naturally
  if (count > 0) {
    print('Has items');
  }

  // Even better: Use semantic methods
  if (items.isNotEmpty) {
    print('Has items');
  }
}

/// Best practice 3: Extract complex conditions
bool isValidAge(int age) {
  // Instead of: if (age >= 0 && age <= 120)
  // Use a descriptive function
  return age >= 0 && age <= 120;
}

void processUser(int age) {
  if (isValidAge(age)) {
    print('Valid age: $age');
  }
}

// ============================================================================
// Runnable Demo
// ============================================================================

void main() {
  print('=== binary-expression-order Demo ===\n');

  print('1. Yoda condition (BAD):\n');
  print("   0 == value  reads as 'zero equals value'");
  print('   Result: ${isZero(0)}');

  print('\n2. Natural order (GOOD):\n');
  print("   value == 0  reads as 'value equals zero'");
  print('   Result: ${goodIsZero(0)}');

  print('\n3. Why Yoda exists (C language):\n');
  print('   In C: if (x = 0) is a bug (assignment)');
  print('   Yoda: if (0 = x) catches the bug');
  print('   In Dart: if (x = 0) is already a compile error!');

  print('\n4. Limitation - constant identifiers:\n');
  print('   maxValue == value is NOT detected');
  print('   (Rule cannot tell maxValue is a constant)');

  print('\n5. Comparison operators checked:\n');
  print('   ==, !=, <, >, <=, >=');
  print('   +, -, *, / are NOT checked');

  print('\nRun "anteater analyze -p example/rules/quality" to see violations.');
}
