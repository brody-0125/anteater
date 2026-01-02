// ignore_for_file: unused_local_variable, dead_code, unused_element

/// Example: Cognitive Complexity
///
/// This file demonstrates cognitive complexity calculation.
///
/// ## What It Measures
/// How difficult code is for a human to understand.
/// Based on SonarQube's cognitive complexity model.
///
/// ## Key Difference from Cyclomatic Complexity
///
/// | Aspect | Cyclomatic | Cognitive |
/// |--------|------------|-----------|
/// | Focus | Test paths | Human understanding |
/// | Nesting | Not penalized | Heavily penalized |
/// | Switch | +1 per case | +1 total |
/// | Logical ops | +1 each | +1 per sequence |
///
/// ## Nesting Penalty
///
/// Control structures at deeper nesting levels add more complexity:
///
/// | Nesting Level | Penalty |
/// |---------------|---------|
/// | Level 0 | +1 (base) |
/// | Level 1 | +2 (1 + 1 nesting) |
/// | Level 2 | +3 (1 + 2 nesting) |
/// | Level 3 | +4 (1 + 3 nesting) |
///
/// ## Elements That Add Complexity
///
/// **With Nesting Penalty:**
/// - `if`, `else if`, `else`
/// - `for`, `for-in`, `while`, `do-while`
/// - `switch` (entire statement, not per case)
/// - `catch` clause
/// - Lambda/closure (increases nesting for inner code)
///
/// **Without Nesting Penalty:**
/// - `&&`, `||` (only first in a chain counts)
///
/// ## Thresholds
/// | Cognitive | Interpretation |
/// |-----------|----------------|
/// | 0-7 | Low - easy to understand |
/// | 8-15 | Moderate - manageable |
/// | 16-24 | High - difficult |
/// | 25+ | Very High - needs refactoring |
///
/// Run with:
/// ```bash
/// anteater metrics -p example/metrics/cognitive_complexity_example.dart
/// ```
library;

// ============================================================================
// Nesting Penalty Demonstration
// ============================================================================

/// Cognitive = 1: Single if at level 0
/// (1 for if, 0 nesting penalty)
int flatIf(int x) {
  if (x > 0) {
    return x;
  }
  return 0;
}

/// Cognitive = 4: Nested if
/// if at level 0: +1
/// if at level 1: +1 base + 1 nesting = +2
/// Total: 1 + 2 + 1(else) = 4
int nestedIf(int x, int y) {
  if (x > 0) {
    // +1 (level 0)
    if (y > 0) {
      // +2 (level 1: 1 base + 1 nesting)
      return x + y;
    }
  } else {
    // +1 (else)
    return 0;
  }
  return x;
}

/// Cognitive = 9: Deeply nested structure
/// Level 0 if: +1
/// Level 1 for: +2 (1 + 1 nesting)
/// Level 2 if: +3 (1 + 2 nesting)
/// Level 2 else: +3 (1 + 2 nesting)
int deeplyNested(List<int> items, int threshold) {
  var result = 0;
  if (items.isNotEmpty) {
    // +1 (level 0)
    for (final item in items) {
      // +2 (level 1)
      if (item > threshold) {
        // +3 (level 2)
        result += item;
      } else {
        // +3 (level 2)
        result -= item;
      }
    }
  }
  return result;
}

// ============================================================================
// Switch Statement Comparison
// ============================================================================

/// Cyclomatic = 8 (1 base + 7 cases)
/// Cognitive = 1 (switch counts as 1 total, regardless of cases)
String dayNameCyclomatic(int day) {
  switch (day) {
    case 1:
      return 'Monday';
    case 2:
      return 'Tuesday';
    case 3:
      return 'Wednesday';
    case 4:
      return 'Thursday';
    case 5:
      return 'Friday';
    case 6:
      return 'Saturday';
    case 7:
      return 'Sunday';
    default:
      return 'Unknown';
  }
}

/// Cognitive = 8 (if chains count each condition)
/// This is why switch is preferred for multiple values!
String dayNameIfChain(int day) {
  if (day == 1) {
    // +1
    return 'Monday';
  } else if (day == 2) {
    // +1 (else-if doesn't add nesting)
    return 'Tuesday';
  } else if (day == 3) {
    // +1
    return 'Wednesday';
  } else if (day == 4) {
    // +1
    return 'Thursday';
  } else if (day == 5) {
    // +1
    return 'Friday';
  } else if (day == 6) {
    // +1
    return 'Saturday';
  } else if (day == 7) {
    // +1
    return 'Sunday';
  } else {
    // +1
    return 'Unknown';
  }
}

// ============================================================================
// Logical Operator Sequences
// ============================================================================

/// Cognitive = 2: Two separate logical sequences
/// First sequence: a && b && c → +1 (one sequence)
/// Second sequence: x || y → +1 (separate sequence)
bool logicalSequences(bool a, bool b, bool c, bool x, bool y) {
  final firstCondition = a && b && c; // +1 for entire sequence
  final secondCondition = x || y; // +1 for separate sequence
  return firstCondition || secondCondition; // +1 for combining
}

/// Cyclomatic = 5 (1 + 4 operators)
/// Cognitive = 1 (entire expression is one logical unit)
bool longAndChain(bool a, bool b, bool c, bool d) {
  return a && b && c && d; // Only +1 in cognitive
}

/// Cognitive = 2: Mixed operators break the sequence
bool mixedOperators(bool a, bool b, bool c, bool d) {
  return a && b || c && d; // +1 for first part, +1 for second
}

// ============================================================================
// Lambda/Closure Nesting
// ============================================================================

/// Cognitive = 4: Lambda increases nesting level
/// for: +1 (level 0)
/// lambda creates level 1
/// if inside lambda: +2 (level 1)
/// else: +1
int processWithLambda(List<int> items) {
  var sum = 0;
  items.forEach((item) {
    // Lambda increases nesting
    if (item > 0) {
      // +2 (inside lambda = level 1)
      sum += item;
    } else {
      // +1
      sum -= item;
    }
  });
  return sum;
}

/// Cognitive = 3: for-in is simpler than forEach with lambda
/// for: +1 (level 0)
/// if: +2 (level 1)
int processWithForIn(List<int> items) {
  var sum = 0;
  for (final item in items) {
    // +1 (level 0)
    if (item > 0) {
      // +2 (level 1, inside for loop)
      sum += item;
    }
  }
  return sum;
}

// ============================================================================
// Refactoring to Reduce Cognitive Complexity
// ============================================================================

/// Before: Cognitive = 15+
/// This function is hard to understand due to deep nesting
int complexBeforeRefactoring(List<Map<String, dynamic>> data, int minAge) {
  var total = 0;
  for (final entry in data) {
    // +1
    if (entry.containsKey('age')) {
      // +2
      final age = entry['age'];
      if (age is int) {
        // +3
        if (age >= minAge) {
          // +4
          if (entry.containsKey('score')) {
            // +5
            final score = entry['score'];
            if (score is int) {
              // +6 = 21 total!
              total += score;
            }
          }
        }
      }
    }
  }
  return total;
}

/// After: Cognitive = 6
/// Use guard clauses and extract helper methods
int complexAfterRefactoring(List<Map<String, dynamic>> data, int minAge) {
  var total = 0;
  for (final entry in data) {
    // +1
    final score = extractScore(entry, minAge);
    if (score != null) {
      // +2
      total += score;
    }
  }
  return total;
}

/// Helper: Cognitive = 4
int? extractScore(Map<String, dynamic> entry, int minAge) {
  final age = entry['age'];
  if (age is! int || age < minAge) return null; // +1, +1 for ||

  final score = entry['score'];
  if (score is! int) return null; // +1

  return score;
}

// ============================================================================
// Comparison: Same Logic, Different Complexity
// ============================================================================

/// High Cognitive Complexity: Nested approach
/// Cognitive = 10+
String categorizeNested(int value, bool strict) {
  if (value >= 0) {
    // +1
    if (value < 10) {
      // +2
      if (strict) {
        // +3
        return 'low-strict';
      } else {
        // +1
        return 'low';
      }
    } else if (value < 100) {
      // +1
      if (strict) {
        // +3
        return 'medium-strict';
      } else {
        // +1
        return 'medium';
      }
    } else {
      // +1
      return 'high';
    }
  } else {
    // +1
    return 'negative';
  }
}

/// Low Cognitive Complexity: Flat approach with early returns
/// Cognitive = 5
String categorizeFlat(int value, bool strict) {
  if (value < 0) return 'negative'; // +1

  if (value < 10) {
    // +1
    return strict ? 'low-strict' : 'low';
  }

  if (value < 100) {
    // +1
    return strict ? 'medium-strict' : 'medium';
  }

  return 'high';
}

// ============================================================================
// else-if Chains (Special Case)
// ============================================================================

/// else-if does NOT increase nesting level
/// Each else-if adds +1, not increasing penalty
/// Cognitive = 4 (1 + 1 + 1 + 1)
String elseIfChain(int x) {
  if (x < 0) {
    // +1
    return 'negative';
  } else if (x == 0) {
    // +1 (no nesting increase!)
    return 'zero';
  } else if (x < 100) {
    // +1
    return 'small';
  } else {
    // +1
    return 'large';
  }
}

// ============================================================================
// Runnable Demo
// ============================================================================

void main() {
  print('=== Cognitive Complexity Demo ===\n');

  print('1. Nesting penalty demonstration:\n');
  print('   flatIf: Cognitive = 1 (if at level 0)');
  print('   nestedIf: Cognitive = 4 (if at level 1 adds +2)');

  print('\n2. Switch vs if-chain:\n');
  print('   switch with 7 cases: Cognitive = 1');
  print('   if-else chain with 7 conditions: Cognitive = 8');
  print('   (Switch is preferred for multiple values!)');

  print('\n3. Logical operators:\n');
  print('   a && b && c && d: Cognitive = 1 (one sequence)');
  print('   a && b || c && d: Cognitive = 2 (mixed = broken sequence)');

  print('\n4. Lambda vs for-in:\n');
  print('   forEach with lambda: adds nesting penalty');
  print('   for-in: simpler, no lambda nesting');

  print('\n5. Refactoring example:\n');
  print('   Before: 6 levels of nesting = Cognitive 21+');
  print('   After:  2 levels + helper = Cognitive 6');

  print('\n6. Guard clauses reduce complexity:\n');
  print('   categorizeNested: Cognitive = 10+');
  print('   categorizeFlat:   Cognitive = 5');

  print('\n7. Thresholds:\n');
  print('   0-7:   Easy to understand');
  print('   8-15:  Moderate complexity');
  print('   16-24: Difficult to understand');
  print('   25+:   Needs refactoring');

  print('\nRun "anteater metrics -p example/metrics" for full analysis.');
}
