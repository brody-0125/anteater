// ignore_for_file: unused_local_variable, dead_code, unused_element

/// Example: Cyclomatic Complexity
///
/// This file demonstrates cyclomatic complexity calculation.
///
/// ## What It Measures
/// The number of linearly independent paths through code.
/// Higher complexity = more test cases needed for full coverage.
///
/// ## Weight Table
///
/// | Element | Weight | Description |
/// |---------|--------|-------------|
/// | Base function | 1 | Minimum 1 path |
/// | `if` | +1 | Branch |
/// | `for` | +1 | Loop branch |
/// | `for-in` | +1 | Loop branch |
/// | `while` | +1 | Loop branch |
/// | `do-while` | +1 | Loop branch |
/// | Each `switch case` | +1 | Per case (not default) |
/// | `catch` clause | +1 | Exception handling path |
/// | `?:` ternary | +1 | Conditional expression |
/// | `&&`, `||` | +1 | Short-circuit evaluation |
/// | `?.` | +1 | Null-aware access |
/// | `??` | +1 | Null-coalescing |
/// | `??=` | +1 | Null-aware assignment |
///
/// ## NOT Counted
/// - `await` (no branching, just suspension)
/// - `try` block itself (only `catch` counts)
/// - `finally` block (always executes)
/// - `switch` statement itself (only cases count)
/// - `else` (already counted by `if`)
/// - `default` case (one path already counted)
///
/// ## Thresholds
/// | CC | Risk Level |
/// |----|------------|
/// | 1-10 | Low - simple, easy to test |
/// | 11-20 | Moderate - some risk |
/// | 21-50 | High - complex, hard to test |
/// | 51+ | Very High - untestable |
///
/// Run with:
/// ```bash
/// anteater metrics -p example/metrics/cyclomatic_complexity_example.dart
/// ```
library;

// ============================================================================
// Low Complexity Examples (CC 1-5)
// ============================================================================

/// CC = 1: No decisions (base case)
int simpleFunction(int x) {
  return x * 2;
}

/// CC = 2: Single if (1 base + 1 if)
int withSingleIf(int x) {
  if (x > 0) {
    return x;
  }
  return 0;
}

/// CC = 3: If with else-if (1 + 1 + 1)
String classify(int x) {
  if (x < 0) {
    return 'negative';
  } else if (x == 0) {
    return 'zero';
  } else {
    return 'positive';
  }
}

/// CC = 3: Single loop with condition (1 + 1 + 1)
int sumPositive(List<int> numbers) {
  var sum = 0;
  for (final n in numbers) {
    // +1 for for-in
    if (n > 0) {
      // +1 for if
      sum += n;
    }
  }
  return sum;
}

// ============================================================================
// Medium Complexity Examples (CC 6-15)
// ============================================================================

/// CC = 6: Multiple conditions with && and ||
/// (1 base + 1 if + 1 && + 1 || + 1 if + 1 &&)
bool validateInput(String? input) {
  if (input == null || input.isEmpty) {
    // if: +1, ||: +1
    return false;
  }

  if (input.length >= 3 && input.length <= 100) {
    // if: +1, &&: +1
    return true;
  }

  return false;
}

/// CC = 7: Loop with multiple conditions
/// (1 + 1 for + 1 if + 1 && + 1 if + 1 || + 1 catch)
int processNumbers(List<int> numbers) {
  var result = 0;
  try {
    for (final n in numbers) {
      // for: +1
      if (n > 0 && n < 100) {
        // if: +1, &&: +1
        result += n;
      }
      if (n == 0 || n == 999) {
        // if: +1, ||: +1
        break;
      }
    }
  } catch (e) {
    // catch: +1
    result = -1;
  }
  return result;
}

/// CC = 8: Switch with multiple cases
/// (1 + 1 + 1 + 1 + 1 + 1 + 1 + 1) - 7 cases + base
String dayName(int day) {
  switch (day) {
    case 1: // +1
      return 'Monday';
    case 2: // +1
      return 'Tuesday';
    case 3: // +1
      return 'Wednesday';
    case 4: // +1
      return 'Thursday';
    case 5: // +1
      return 'Friday';
    case 6: // +1
      return 'Saturday';
    case 7: // +1
      return 'Sunday';
    default: // NOT counted (already one path)
      return 'Unknown';
  }
}

// ============================================================================
// High Complexity Examples (CC 16+)
// ============================================================================

/// CC = 12: Nested conditions and loops
/// This function has high complexity and should be refactored
int complexFunction(List<int> data, int threshold, bool strict) {
  var result = 0;
  var count = 0;

  for (final item in data) {
    // +1
    if (item > 0) {
      // +1
      if (strict && item > threshold) {
        // +1 if, +1 &&
        result += item * 2;
      } else if (item > threshold / 2) {
        // +1
        result += item;
      }
    } else if (item < 0) {
      // +1
      result -= item;
    }

    count++;
    if (count > 100 || result > 10000) {
      // +1 if, +1 ||
      break;
    }
  }

  return strict ? result : result ~/ 2; // +1 ternary
}

/// CC = 18: Very complex validation
/// This function SHOULD be refactored into smaller pieces
bool validateUserData(Map<String, dynamic> data) {
  // Validate name
  if (!data.containsKey('name')) return false; // +1
  final name = data['name'];
  if (name is! String) return false; // +1
  if (name.isEmpty || name.length > 100) return false; // +1 if, +1 ||

  // Validate age
  if (!data.containsKey('age')) return false; // +1
  final age = data['age'];
  if (age is! int) return false; // +1
  if (age < 0 || age > 150) return false; // +1 if, +1 ||

  // Validate email
  if (!data.containsKey('email')) return false; // +1
  final email = data['email'];
  if (email is! String) return false; // +1
  if (!email.contains('@') || !email.contains('.')) return false; // +1 if, +1 ||

  // Validate phone (optional)
  if (data.containsKey('phone')) {
    // +1
    final phone = data['phone'];
    if (phone is String && phone.isNotEmpty) {
      // +1 if, +1 &&
      if (phone.length < 10 || phone.length > 15) return false; // +1 if, +1 ||
    }
  }

  return true;
}

// ============================================================================
// Null-Aware Operators (Dart Specific)
// ============================================================================

/// CC = 5: Null-aware operators add complexity
/// (1 base + 1 ?. + 1 ?? + 1 ?. + 1 ??=)
String processNullable(User? user) {
  // Each null-aware operator is a hidden branch
  final name = user?.name ?? 'Anonymous'; // +1 ?., +1 ??
  final email = user?.email; // +1 ?.

  String? result;
  result ??= 'Default'; // +1 ??=

  return '$name: $email ($result)';
}

/// CC = 4: Null-aware method chaining
String formatName(Person? person) {
  return person?.name?.toUpperCase() ?? 'UNKNOWN';
  // +1 for person?., +1 for name?., +1 for ??
}

// ============================================================================
// Control Flow Comparisons
// ============================================================================

/// Comparing await (not counted) vs branching (counted)

/// CC = 1: Await does NOT add complexity
Future<String> fetchData() async {
  final response = await fetchFromServer(); // await: NOT counted
  final processed = await processData(response); // await: NOT counted
  return processed;
}

/// CC = 4: But handling async results adds complexity
Future<String> fetchDataWithHandling() async {
  final response = await fetchFromServer();

  if (response.isEmpty) {
    // +1
    return 'Empty';
  }

  try {
    final processed = await processData(response);
    if (processed.contains('error')) {
      // +1
      return 'Error in processing';
    }
    return processed;
  } catch (e) {
    // +1
    return 'Exception: $e';
  }
}

// ============================================================================
// How to Reduce Complexity
// ============================================================================

/// Strategy 1: Extract methods
/// Before: One function with CC = 18 (validateUserData above)
/// After: Multiple small functions, each with CC < 5

bool validateName(String? name) {
  if (name == null || name.isEmpty) return false;
  if (name.length > 100) return false;
  return true;
}

bool validateAge(int? age) {
  if (age == null) return false;
  if (age < 0 || age > 150) return false;
  return true;
}

bool validateEmail(String? email) {
  if (email == null || email.isEmpty) return false;
  if (!email.contains('@')) return false;
  return true;
}

/// Strategy 2: Use guard clauses (early returns)
/// This keeps nesting low and each check simple

int processValueWithGuards(int? value, bool isRequired) {
  if (value == null && isRequired) return -1;
  if (value == null) return 0;
  if (value < 0) return 0;
  if (value > 1000) return 1000;
  return value;
}

/// Strategy 3: Replace conditionals with polymorphism
/// Instead of switch, use subclasses or pattern matching

abstract class Shape {
  double area();
}

class Circle extends Shape {
  Circle(this.radius);
  final double radius;

  @override
  double area() => 3.14159 * radius * radius;
}

class Rectangle extends Shape {
  Rectangle(this.width, this.height);
  final double width;
  final double height;

  @override
  double area() => width * height;
}

// ============================================================================
// Runnable Demo
// ============================================================================

void main() {
  print('=== Cyclomatic Complexity Demo ===\n');

  print('1. Simple function (CC = 1):\n');
  print('   simpleFunction(5) = ${simpleFunction(5)}');

  print('\n2. With single if (CC = 2):\n');
  print('   withSingleIf(5) = ${withSingleIf(5)}');
  print('   withSingleIf(-5) = ${withSingleIf(-5)}');

  print('\n3. Classify (CC = 3):\n');
  print('   classify(-1) = ${classify(-1)}');
  print('   classify(0) = ${classify(0)}');
  print('   classify(1) = ${classify(1)}');

  print('\n4. Switch statement (CC = 8):\n');
  for (var i = 1; i <= 7; i++) {
    print('   dayName($i) = ${dayName(i)}');
  }

  print('\n5. Null-aware operators add hidden complexity:\n');
  print('   x?.y ?? z  has CC = 3 (base + ?. + ??)');

  print('\n6. Thresholds:\n');
  print('   1-10:  Low risk');
  print('   11-20: Moderate risk');
  print('   21-50: High risk');
  print('   51+:   Very high risk');

  print('\nRun "anteater metrics -p example/metrics" for full analysis.');
}

// Helper types
class User {
  final String name;
  final String? email;
  User(this.name, this.email);
}

class Person {
  final String? name;
  Person(this.name);
}

Future<String> fetchFromServer() async => 'data';
Future<String> processData(String data) async => 'processed: $data';
