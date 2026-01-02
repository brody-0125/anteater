// ignore_for_file: unused_local_variable, dead_code, unused_element

/// Example: Maintainability Index
///
/// This file demonstrates the Maintainability Index (MI) calculation.
///
/// ## What It Measures
/// A composite score (0-100) indicating how easy code is to maintain.
/// Combines multiple metrics into a single value.
///
/// ## Formula
///
/// ```
/// MI_orig = 171 - 5.2×ln(V) - 0.23×G - 16.2×ln(LOC)
/// MI = max(0, MI_orig × 100 / 171)
/// ```
///
/// Where:
/// - V = Halstead Volume (information content)
/// - G = Cyclomatic Complexity (decision points)
/// - LOC = Lines of Code
///
/// ## Rating Scale
///
/// | Score | Rating | Color | Interpretation |
/// |-------|--------|-------|----------------|
/// | 80-100 | Good | 🟢 | Easy to maintain |
/// | 50-79 | Moderate | 🟡 | Needs attention |
/// | 0-49 | Poor | 🔴 | Difficult, refactor |
///
/// ## Component Weights
///
/// From the formula coefficients:
/// - **Volume (5.2)**: Higher volume → lower MI
/// - **Complexity (0.23)**: Higher CC → lower MI (smaller impact)
/// - **LOC (16.2)**: More lines → lower MI (major impact)
///
/// This means:
/// - Long functions hurt MI more than complex short ones
/// - Volume matters more than raw complexity
///
/// Run with:
/// ```bash
/// anteater metrics -p example/metrics/maintainability_index_example.dart
/// ```
library;

import 'dart:math' as math;

// ============================================================================
// High Maintainability (MI >= 80) - 🟢 Good
// ============================================================================

/// MI ≈ 85-95: Very simple, easy to maintain
/// - Low LOC
/// - Low Volume
/// - Low Complexity
int add(int a, int b) => a + b;

/// MI ≈ 80-85: Simple utility function
bool isPositive(int n) => n > 0;

/// MI ≈ 75-85: Single responsibility, clear logic
int findMax(List<int> numbers) {
  if (numbers.isEmpty) return 0;

  var max = numbers.first;
  for (final n in numbers) {
    if (n > max) max = n;
  }
  return max;
}

/// MI ≈ 75-80: Well-structured with early returns
String classify(int score) {
  if (score < 0) return 'Invalid';
  if (score < 60) return 'Fail';
  if (score < 70) return 'D';
  if (score < 80) return 'C';
  if (score < 90) return 'B';
  return 'A';
}

// ============================================================================
// Moderate Maintainability (MI 50-79) - 🟡 Needs Attention
// ============================================================================

/// MI ≈ 60-70: More logic, but still manageable
/// Consider if it can be simplified
List<int> filterAndSort(List<int> items, int min, int max, bool ascending) {
  final filtered = <int>[];

  for (final item in items) {
    if (item >= min && item <= max) {
      filtered.add(item);
    }
  }

  if (ascending) {
    filtered.sort();
  } else {
    filtered.sort((a, b) => b.compareTo(a));
  }

  return filtered;
}

/// MI ≈ 55-65: Moderate complexity and length
/// Would benefit from extracting helper methods
Map<String, int> analyzeText(String text) {
  final result = <String, int>{};

  if (text.isEmpty) return result;

  var wordCount = 0;
  var charCount = 0;
  var lineCount = 1;
  var sentenceCount = 0;

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    charCount++;

    if (char == '\n') {
      lineCount++;
    }

    if (char == '.' || char == '!' || char == '?') {
      sentenceCount++;
    }

    if (char == ' ' || char == '\n') {
      if (i > 0 && text[i - 1] != ' ' && text[i - 1] != '\n') {
        wordCount++;
      }
    }
  }

  if (text.isNotEmpty && text[text.length - 1] != ' ') {
    wordCount++;
  }

  result['words'] = wordCount;
  result['characters'] = charCount;
  result['lines'] = lineCount;
  result['sentences'] = sentenceCount;

  return result;
}

// ============================================================================
// Poor Maintainability (MI < 50) - 🔴 Needs Refactoring
// ============================================================================

/// MI ≈ 35-45: Too long, too complex
/// This function SHOULD be refactored
Map<String, dynamic> processUserData(
  Map<String, dynamic> data,
  bool validateAge,
  bool validateEmail,
  bool validatePhone,
  bool strictMode,
) {
  final errors = <String>[];
  final warnings = <String>[];
  var isValid = true;

  // Name validation
  if (!data.containsKey('name')) {
    errors.add('Name is required');
    isValid = false;
  } else {
    final name = data['name'];
    if (name is! String) {
      errors.add('Name must be a string');
      isValid = false;
    } else {
      if (name.isEmpty) {
        errors.add('Name cannot be empty');
        isValid = false;
      } else if (name.length < 2) {
        if (strictMode) {
          errors.add('Name too short');
          isValid = false;
        } else {
          warnings.add('Name is very short');
        }
      } else if (name.length > 100) {
        errors.add('Name too long');
        isValid = false;
      }
    }
  }

  // Age validation
  if (validateAge) {
    if (!data.containsKey('age')) {
      if (strictMode) {
        errors.add('Age is required in strict mode');
        isValid = false;
      } else {
        warnings.add('Age not provided');
      }
    } else {
      final age = data['age'];
      if (age is! int) {
        errors.add('Age must be an integer');
        isValid = false;
      } else {
        if (age < 0) {
          errors.add('Age cannot be negative');
          isValid = false;
        } else if (age < 13) {
          if (strictMode) {
            errors.add('User must be 13 or older');
            isValid = false;
          } else {
            warnings.add('User is under 13');
          }
        } else if (age > 150) {
          errors.add('Age seems invalid');
          isValid = false;
        }
      }
    }
  }

  // Email validation
  if (validateEmail) {
    if (!data.containsKey('email')) {
      errors.add('Email is required');
      isValid = false;
    } else {
      final email = data['email'];
      if (email is! String) {
        errors.add('Email must be a string');
        isValid = false;
      } else {
        if (!email.contains('@')) {
          errors.add('Invalid email format');
          isValid = false;
        } else if (!email.contains('.')) {
          errors.add('Invalid email domain');
          isValid = false;
        }
      }
    }
  }

  // Phone validation
  if (validatePhone && data.containsKey('phone')) {
    final phone = data['phone'];
    if (phone is String) {
      if (phone.length < 10 || phone.length > 15) {
        warnings.add('Phone number length unusual');
      }
    }
  }

  return {
    'isValid': isValid,
    'errors': errors,
    'warnings': warnings,
    'data': isValid ? data : null,
  };
}

// ============================================================================
// Refactored Version (High MI)
// ============================================================================

/// Refactored: Each validation is its own function
/// MI ≈ 80+ for each small function

class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ValidationResult(this.isValid, this.errors, this.warnings);

  factory ValidationResult.valid() => ValidationResult(true, [], []);
  factory ValidationResult.error(String msg) => ValidationResult(false, [msg], []);
  factory ValidationResult.warning(String msg) => ValidationResult(true, [], [msg]);

  ValidationResult merge(ValidationResult other) {
    return ValidationResult(
      isValid && other.isValid,
      [...errors, ...other.errors],
      [...warnings, ...other.warnings],
    );
  }
}

ValidationResult validateName(String? name, bool strictMode) {
  if (name == null || name.isEmpty) {
    return ValidationResult.error('Name is required');
  }
  if (name.length < 2) {
    return strictMode
        ? ValidationResult.error('Name too short')
        : ValidationResult.warning('Name is very short');
  }
  if (name.length > 100) {
    return ValidationResult.error('Name too long');
  }
  return ValidationResult.valid();
}

ValidationResult validateAge(int? age, bool strictMode) {
  if (age == null) {
    return strictMode
        ? ValidationResult.error('Age required in strict mode')
        : ValidationResult.warning('Age not provided');
  }
  if (age < 0) return ValidationResult.error('Age cannot be negative');
  if (age < 13) {
    return strictMode
        ? ValidationResult.error('Must be 13+')
        : ValidationResult.warning('User is under 13');
  }
  if (age > 150) return ValidationResult.error('Age seems invalid');
  return ValidationResult.valid();
}

ValidationResult validateEmail(String? email) {
  if (email == null || email.isEmpty) {
    return ValidationResult.error('Email is required');
  }
  if (!email.contains('@') || !email.contains('.')) {
    return ValidationResult.error('Invalid email format');
  }
  return ValidationResult.valid();
}

// ============================================================================
// Understanding the Formula Components
// ============================================================================

/// LOC Impact Demonstration
///
/// Same logic, different LOC → different MI

// Short version (low LOC, high MI)
int sumShort(List<int> n) => n.fold(0, (a, b) => a + b);

// Verbose version (high LOC, lower MI)
int sumVerbose(List<int> numbers) {
  // Initialize the sum variable
  var sum = 0;

  // Iterate through each number
  for (final number in numbers) {
    // Add the number to the sum
    sum = sum + number;
  }

  // Return the final sum
  return sum;
}

// Both do the same thing, but sumShort has higher MI!

// ============================================================================
// Runnable Demo
// ============================================================================

void main() {
  print('=== Maintainability Index Demo ===\n');

  print('1. Formula:\n');
  print('   MI = max(0, (171 - 5.2×ln(V) - 0.23×G - 16.2×ln(LOC)) × 100/171)\n');

  print('2. Rating Scale:\n');
  print('   🟢 80-100: Good (easy to maintain)');
  print('   🟡 50-79:  Moderate (needs attention)');
  print('   🔴 0-49:   Poor (refactor needed)\n');

  print('3. Component Impact:\n');
  print('   - LOC has highest impact (coefficient 16.2)');
  print('   - Volume has moderate impact (coefficient 5.2)');
  print('   - Complexity has lowest impact (coefficient 0.23)\n');

  print('4. Example Calculation:\n');

  // Example values
  const volume = 150.0;
  const complexity = 8;
  const loc = 20;

  final miOrig = 171 - 5.2 * math.log(volume) - 0.23 * complexity - 16.2 * math.log(loc);
  final mi = math.max(0, miOrig * 100 / 171);

  print('   V = $volume, G = $complexity, LOC = $loc');
  print('   MI_orig = 171 - 5.2×ln($volume) - 0.23×$complexity - 16.2×ln($loc)');
  print('   MI_orig = ${miOrig.toStringAsFixed(2)}');
  print('   MI = ${mi.toStringAsFixed(2)} 🟢\n');

  print('5. LOC Impact Demo:\n');
  print('   Same logic, different style:');
  print('   - sumShort: ~5 LOC → Higher MI');
  print('   - sumVerbose: ~15 LOC → Lower MI\n');

  print('6. Refactoring Benefits:\n');
  print('   processUserData (one function): MI ≈ 35-45 🔴');
  print('   After splitting into validateName, validateAge, validateEmail:');
  print('   Each function: MI ≈ 75-85 🟢\n');

  print('7. Key Insight:\n');
  print('   Short, focused functions have higher MI.');
  print('   Long functions hurt MI more than complex short ones.');

  print('\nRun "anteater metrics -p example/metrics" for full analysis.');
}
