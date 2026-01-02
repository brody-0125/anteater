// ignore_for_file: unused_local_variable, dead_code, unused_element

/// Example: Halstead Metrics
///
/// This file demonstrates Halstead complexity metrics calculation.
///
/// ## What It Measures
/// Information-theoretic metrics treating code as a sequence of tokens.
/// Developed by Maurice Halstead in 1977.
///
/// ## Token Classification
///
/// ### Operators (things that DO something)
/// - Binary: `+`, `-`, `*`, `/`, `%`, `~/`, `==`, `!=`, `<`, `>`, etc.
/// - Unary: `!`, `-` (prefix), `++`, `--`
/// - Assignment: `=`, `+=`, `-=`, `*=`, etc.
/// - Logical: `&&`, `||`, `??`
/// - Control keywords: `if`, `for`, `while`, `return`, `await`
///
/// ### Operands (things being operated ON)
/// - Identifiers: variable names, function names
/// - Literals: `42`, `'hello'`, `true`, `3.14`, `null`
/// - Type names (when used as values)
///
/// ## Basic Metrics
///
/// | Symbol | Name | Description |
/// |--------|------|-------------|
/// | n₁ | Unique operators | Distinct operators used |
/// | n₂ | Unique operands | Distinct operands used |
/// | N₁ | Total operators | Total operator occurrences |
/// | N₂ | Total operands | Total operand occurrences |
///
/// ## Derived Metrics
///
/// | Metric | Formula | Meaning |
/// |--------|---------|---------|
/// | Vocabulary (n) | n₁ + n₂ | Unique token count |
/// | Length (N) | N₁ + N₂ | Total token count |
/// | Volume (V) | N × log₂(n) | Information content (bits) |
/// | Difficulty (D) | (n₁/2) × (N₂/n₂) | Error-proneness |
/// | Effort (E) | D × V | Mental effort required |
/// | Time (T) | E / 18 | Estimated programming time (seconds) |
/// | Bugs (B) | V / 3000 | Estimated bugs |
///
/// Run with:
/// ```bash
/// anteater metrics -p example/metrics/halstead_metrics_example.dart
/// ```
library;

import 'dart:math' as math;

// ============================================================================
// Simple Examples: Low Volume
// ============================================================================

/// Operators: return, *
/// Operands: x, 2
///
/// n₁ = 2 (*, return)
/// n₂ = 2 (x, 2)
/// N₁ = 2
/// N₂ = 2
///
/// n = 4, N = 4
/// V = 4 × log₂(4) = 4 × 2 = 8 bits
int double_(int x) {
  return x * 2;
}

/// More operators and operands
///
/// Operators: if, return, >, - (4 unique)
/// Operands: a, b, 0 (3 unique)
///
/// Higher vocabulary = higher volume
int maxAbs(int a, int b) {
  if (a > 0) {
    return a;
  }
  if (b > 0) {
    return b;
  }
  return -a > -b ? -a : -b;
}

// ============================================================================
// Medium Complexity
// ============================================================================

/// Calculating factorial
///
/// Operators: if, return, <=, *, -, for, = (7 unique)
/// Operands: n, 0, 1, result, i (5 unique)
///
/// Volume ≈ 60-80 bits
int factorial(int n) {
  if (n <= 0) return 1;

  var result = 1;
  for (var i = 1; i <= n; i++) {
    result *= i;
  }
  return result;
}

/// Fibonacci with more operands
///
/// More repeated operands = higher N₂
/// But more unique operands = higher n₂
/// Difficulty = (n₁/2) × (N₂/n₂)
int fibonacci(int n) {
  if (n <= 1) return n;

  var a = 0;
  var b = 1;

  for (var i = 2; i <= n; i++) {
    final temp = a + b;
    a = b;
    b = temp;
  }

  return b;
}

// ============================================================================
// High Volume Example
// ============================================================================

/// Binary search has many operators and operands
///
/// High Volume indicators:
/// - Many unique operators (while, if, <, >, ==, ~/, +, -, return)
/// - Many operands (list, target, low, high, mid, length)
/// - Repeated use of operands (N₂ >> n₂)
///
/// High Difficulty = more error-prone
int binarySearch(List<int> list, int target) {
  var low = 0;
  var high = list.length - 1;

  while (low <= high) {
    final mid = low + (high - low) ~/ 2;
    final value = list[mid];

    if (value == target) {
      return mid;
    } else if (value < target) {
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }

  return -1;
}

// ============================================================================
// Understanding Difficulty
// ============================================================================

/// Low Difficulty: Few unique operators, balanced operand usage
///
/// D = (n₁/2) × (N₂/n₂)
/// If n₂ is high (many unique operands), D is lower
/// If N₂ is high but n₂ is low (repetition), D is higher
int lowDifficulty(int a, int b, int c, int d) {
  // Many unique operands, few operators, little repetition
  return a + b + c + d;
}

/// High Difficulty: Few operands used repeatedly
///
/// Same operand 'x' used many times = high N₂/n₂ ratio
int highDifficulty(int x) {
  // 'x' is used 6 times, but n₂ includes x, 2, 3, 4 = 4
  // High repetition of x increases difficulty
  return x + x * 2 + x * 3 + x * 4 + x + x;
}

// ============================================================================
// Effort and Time Estimation
// ============================================================================

/// The Effort metric estimates mental effort
/// Time = Effort / 18 (in seconds)
///
/// A function with:
/// - E = 1000 would take ~55 seconds to understand
/// - E = 10000 would take ~9 minutes
///
/// These are rough estimates, actual time varies by:
/// - Developer experience
/// - Code familiarity
/// - Documentation quality
int effortExample(List<int> data, int threshold, bool ascending) {
  if (data.isEmpty) return 0;

  var result = 0;
  var count = 0;

  for (final value in data) {
    if (ascending) {
      if (value > threshold) {
        result += value;
        count++;
      }
    } else {
      if (value < threshold) {
        result += value;
        count++;
      }
    }
  }

  return count > 0 ? result ~/ count : 0;
}

// ============================================================================
// Bug Estimation
// ============================================================================

/// B = V / 3000
/// Estimated number of bugs based on information content
///
/// A function with V = 300 is estimated to have ~0.1 bugs
/// A function with V = 3000 is estimated to have ~1 bug
///
/// This is a probabilistic model - actual bugs depend on:
/// - Testing quality
/// - Developer experience
/// - Code review
/// - Language safety features

/// Low Volume = Low Bug Risk
int lowBugRisk(int x) => x * 2; // V ≈ 8, B ≈ 0.003

/// Higher Volume = Higher Bug Risk
int higherBugRisk(int x, int y, int z, bool flag) {
  // More operations = more places for bugs
  if (flag) {
    return (x + y) * z - (x - y);
  } else {
    return (x - y) * z + (x + y);
  }
}

// ============================================================================
// Practical Applications
// ============================================================================

/// Halstead metrics help identify:
///
/// 1. **Code complexity** - High V suggests complex logic
/// 2. **Maintenance effort** - High E suggests more effort to modify
/// 3. **Bug-prone code** - High D suggests error-prone sections
/// 4. **Refactoring candidates** - Outliers in D or V

/// Example: Identify refactoring candidate
///
/// If a function has:
/// - V > 1000 (high information content)
/// - D > 30 (high difficulty)
/// - E > 10000 (high effort)
///
/// Consider:
/// - Extracting helper functions
/// - Simplifying logic
/// - Adding intermediate variables

// ============================================================================
// Comparison with Other Metrics
// ============================================================================

/// Halstead vs Cyclomatic vs Cognitive
///
/// | Metric | Focus | Best for |
/// |--------|-------|----------|
/// | Halstead | Token-based | Size/info content |
/// | Cyclomatic | Decision points | Test coverage |
/// | Cognitive | Understanding | Readability |
///
/// Use together for comprehensive analysis:
/// - High Cyclomatic + Low Halstead = Many simple conditions
/// - Low Cyclomatic + High Halstead = Long sequential code
/// - High Cognitive + High Halstead = Complex and lengthy

// ============================================================================
// Runnable Demo
// ============================================================================

void main() {
  print('=== Halstead Metrics Demo ===\n');

  print('1. Simple function (double_):\n');
  print('   Operators: *, return (n₁ = 2)');
  print('   Operands: x, 2 (n₂ = 2)');
  print('   Volume ≈ 8 bits');

  print('\n2. Vocabulary and Length:\n');
  print('   n = n₁ + n₂ (unique tokens)');
  print('   N = N₁ + N₂ (total tokens)');

  print('\n3. Volume formula:\n');
  print('   V = N × log₂(n)');
  print('   Higher vocabulary or length = higher volume');

  print('\n4. Difficulty formula:\n');
  print('   D = (n₁/2) × (N₂/n₂)');
  print('   High operand repetition = high difficulty');

  print('\n5. Effort formula:\n');
  print('   E = D × V');
  print('   Time (seconds) = E / 18');

  print('\n6. Bug estimation:\n');
  print('   B = V / 3000');
  print('   V = 300 → ~0.1 bugs');
  print('   V = 3000 → ~1 bug');

  print('\n7. Demo calculations:\n');

  // Simulate Halstead calculation for factorial
  const n1 = 7; // if, return, <=, *, -, for, =
  const n2 = 5; // n, 0, 1, result, i
  const n1Total = 10; // Count all operator occurrences
  const n2Total = 15; // Count all operand occurrences

  final n = n1 + n2;
  final programN = n1Total + n2Total;
  final volume = programN * (math.log(n) / math.log(2));
  final difficulty = (n1 / 2) * (n2Total / n2);
  final effort = difficulty * volume;
  final time = effort / 18;
  final bugs = volume / 3000;

  print('   factorial function:');
  print('   n₁ = $n1, n₂ = $n2');
  print('   N₁ = $n1Total, N₂ = $n2Total');
  print('   Vocabulary (n) = $n');
  print('   Length (N) = $programN');
  print('   Volume (V) = ${volume.toStringAsFixed(2)} bits');
  print('   Difficulty (D) = ${difficulty.toStringAsFixed(2)}');
  print('   Effort (E) = ${effort.toStringAsFixed(2)}');
  print('   Time (T) = ${time.toStringAsFixed(2)} seconds');
  print('   Bugs (B) = ${bugs.toStringAsFixed(4)}');

  print('\nRun "anteater metrics -p example/metrics" for full analysis.');
}
