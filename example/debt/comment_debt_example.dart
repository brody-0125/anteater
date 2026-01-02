// ignore_for_file: unused_local_variable, dead_code, unused_element

/// Example: Comment-Based Technical Debt
///
/// This file demonstrates comment patterns detected as technical debt.
///
/// ## Detected Patterns
///
/// | Pattern | Severity | Description |
/// |---------|----------|-------------|
/// | `// TODO:` or `// TODO ` | Medium | Planned work |
/// | `// FIXME:` or `// FIXME ` | High | Known issue |
/// | `// ignore: rule_name` | High | Suppressed warning |
/// | `// ignore_for_file: rule_name` | Critical | File-level suppression |
///
/// ## NOT Detected (Limitations)
///
/// | Pattern | Reason |
/// |---------|--------|
/// | `/* TODO */` | Block comments not scanned |
/// | `/// TODO` | Doc comments not scanned |
/// | `//TODO` | No space or colon after keyword |
/// | `// todo:` | Case-sensitive (lowercase) |
///
/// ## Regex Patterns Used
///
/// ```regex
/// TODO: //\s*TODO[:\s](.*)$
/// FIXME: //\s*FIXME[:\s](.*)$
/// ignore: //\s*ignore:\s*([a-z_,\s]+)
/// ignore_for_file: //\s*ignore_for_file:\s*([a-z_,\s]+)
/// ```
///
/// Run with:
/// ```bash
/// anteater debt -p example/debt/comment_debt_example.dart
/// ```
library;

// ============================================================================
// TODO Comments (Severity: Medium)
// ============================================================================

/// TODO comments mark planned work.
/// Cost: 4 hours base × 1.0 (medium) = 4 hours
class TodoExamples {
  // TODO: Implement caching for better performance
  void fetchData() {
    // Direct database call without caching
  }

  // TODO Add input validation
  void processInput(String input) {
    // No validation yet
  }

  void calculate() {
    // TODO: Optimize this algorithm for large datasets
    // This is O(n^2), should be O(n log n)
  }
}

// ============================================================================
// FIXME Comments (Severity: High)
// ============================================================================

/// FIXME comments mark known issues requiring fixes.
/// Cost: 8 hours base × 2.0 (high) = 16 hours
class FixmeExamples {
  // FIXME: Memory leak when called repeatedly
  void loadResource() {
    // Resource not properly disposed
  }

  // FIXME Race condition in concurrent access
  var sharedState = 0;

  void updateState() {
    // FIXME: This is not thread-safe
    sharedState++;
  }
}

// ============================================================================
// Ignore Comments (Severity: High)
// ============================================================================

/// Single-line ignore comments suppress specific warnings.
/// Cost: 8 hours base × 2.0 (high) = 16 hours
class IgnoreExamples {
  void example1() {
    // ignore: avoid_print
    print('Debug output');
  }

  void example2() {
    // ignore: unused_local_variable
    var temp = 42;
  }

  void example3() {
    // ignore: avoid_dynamic, unnecessary_cast
    dynamic value = getData() as dynamic;
  }
}

dynamic getData() => 'data';

// ============================================================================
// Ignore For File Comments (Severity: Critical)
// ============================================================================

/// File-level suppressions are the highest severity debt.
/// Cost: 16 hours base × 4.0 (critical) = 64 hours
///
/// File-level ignore is at the top of this file:
/// `// ignore_for_file: unused_local_variable, dead_code, unused_element`
///
/// This affects the entire file and should be reviewed.

// ============================================================================
// NOT Detected - Block Comments
// ============================================================================

/// Block comments are NOT scanned for debt patterns.
/// The following will NOT be detected:

/* TODO: This won't be detected */
/* FIXME: Neither will this */

class BlockCommentExamples {
  /*
   * TODO: Multi-line block comment
   * This is completely ignored by the detector.
   */
  void method1() {}

  /* FIXME: Single-line block comment - not detected */
  void method2() {}
}

// ============================================================================
// NOT Detected - Doc Comments
// ============================================================================

/// Doc comments are NOT scanned for debt patterns.
/// The following will NOT be detected:

/// TODO: This is in a doc comment - not detected
/// FIXME: This is also in a doc comment - not detected
class DocCommentExamples {
  /// TODO: Implement this method properly
  /// This doc comment TODO is not detected.
  void method1() {}

  /// FIXME: Known issue with edge cases
  /// This doc comment FIXME is not detected.
  void method2() {}
}

// ============================================================================
// NOT Detected - Missing Space/Colon
// ============================================================================

/// Patterns without space or colon after keyword are NOT detected.
/// The regex requires `TODO:` or `TODO ` (with space).

class NoSpaceExamples {
  //TODO: No space before TODO - NOT DETECTED (but colon present, depends on leading space)
  void method1() {}

  //FIXME This might not be detected correctly
  void method2() {}
}

// ============================================================================
// NOT Detected - Lowercase
// ============================================================================

/// The patterns are case-sensitive.
/// Lowercase variants are NOT detected.

class LowercaseExamples {
  // todo: lowercase - NOT DETECTED
  void method1() {}

  // fixme: lowercase - NOT DETECTED
  void method2() {}

  // Todo: Mixed case - NOT DETECTED
  void method3() {}
}

// ============================================================================
// Multiple Rules in Single Ignore
// ============================================================================

/// Multiple rules can be suppressed in a single comment.
/// Each rule adds to the technical debt.

class MultipleRulesExample {
  void method() {
    // ignore: avoid_print, unnecessary_cast, unused_local_variable
    print('Multiple suppressions in one comment');
  }
}

// ============================================================================
// Valid Patterns for Reference
// ============================================================================

/// Valid patterns that WILL be detected:

class ValidPatternExamples {
  // TODO: Standard format with colon
  void pattern1() {}

  // TODO Standard format with space (no colon)
  void pattern2() {}

  // FIXME: Standard format with colon
  void pattern3() {}

  // FIXME Standard format with space
  void pattern4() {}

  //  TODO: Extra leading space is OK
  void pattern5() {}

  // TODO:No space after colon is OK
  void pattern6() {}
}

// ============================================================================
// Cost Calculation Reference
// ============================================================================

/// ## Default Cost Configuration
///
/// | Type | Base Cost | Default Severity | Multiplier | Total |
/// |------|-----------|------------------|------------|-------|
/// | TODO | 4 hours | Medium | 1.0x | 4 hours |
/// | FIXME | 8 hours | High | 2.0x | 16 hours |
/// | ignore | 8 hours | High | 2.0x | 16 hours |
/// | ignore_for_file | 16 hours | Critical | 4.0x | 64 hours |
///
/// ## Why High Costs?
///
/// - **TODO**: Represents planned work not yet done
/// - **FIXME**: Indicates known bugs or issues
/// - **ignore**: Bypasses safety checks for specific lines
/// - **ignore_for_file**: Bypasses safety checks for entire file

// ============================================================================
// Runnable Demo
// ============================================================================

void main() {
  print('=== Comment-Based Debt Demo ===\n');

  print('1. Detected Patterns:\n');
  print('   // TODO: description      → Medium severity');
  print('   // FIXME: description     → High severity');
  print('   // ignore: rule_name      → High severity');
  print('   // ignore_for_file: rule  → Critical severity');

  print('\n2. NOT Detected:\n');
  print('   /* TODO */               → Block comments ignored');
  print('   /// TODO                 → Doc comments ignored');
  print('   //TODO (no space)        → Missing delimiter');
  print('   // todo: (lowercase)     → Case sensitive');

  print('\n3. Cost Examples:\n');
  print('   1 TODO comment:          4 hours');
  print('   1 FIXME comment:         16 hours (8 × 2.0)');
  print('   1 ignore comment:        16 hours (8 × 2.0)');
  print('   1 ignore_for_file:       64 hours (16 × 4.0)');

  print('\n4. Best Practices:\n');
  print('   - Address TODOs before merging to main');
  print('   - FIXME should have linked issue tracker item');
  print('   - Avoid ignore comments; fix the underlying issue');
  print('   - Never use ignore_for_file in production code');

  print('\nRun "anteater debt -p example/debt" for full analysis.');
}
