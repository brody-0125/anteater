// ignore_for_file: unused_local_variable, dead_code, unused_element

/// Example: no-equal-then-else
///
/// This file demonstrates the `no-equal-then-else` rule.
///
/// ## What It Detects
/// - If/else statements where both branches have identical code
/// - Ternary expressions where both branches are identical
///
/// ## Why It Matters
/// - The condition becomes meaningless (dead code smell)
/// - Often indicates copy-paste errors
/// - Makes code harder to understand
/// - May hide logic bugs
///
/// ## Detection Method
/// - Source code is normalized (whitespace removed) before comparison
/// - Both branches must be textually identical after normalization
///
/// ## Known Limitations
/// - **Different variable names are NOT detected** even if semantically equivalent
/// - Only compares source text, not semantic meaning
///
/// ## Configuration
/// ```yaml
/// anteater:
///   rules:
///     - no-equal-then-else
/// ```
///
/// Run with:
/// ```bash
/// anteater analyze -p example/rules/safety/no_equal_then_else_example.dart
/// ```
library;

// ============================================================================
// BAD: Patterns that violate the rule
// ============================================================================

/// BAD: Identical if/else branches
int processValue(bool condition, int value) {
  if (condition) {
    return value * 2;
  } else {
    return value * 2; // BAD: Same as then branch
  }
}

/// BAD: Identical branches with multiple statements
void handleEvent(bool isAdmin) {
  if (isAdmin) {
    print('Processing...');
    logAction('event');
    notifyUser();
  } else {
    print('Processing...');
    logAction('event');
    notifyUser(); // BAD: Entire block is identical
  }
}

/// BAD: Identical ternary expression branches
String getMessage(bool isError) {
  return isError
      ? 'An error occurred'
      : 'An error occurred'; // BAD: Both branches identical
}

/// BAD: Identical nested if branches
void nestedExample(bool a, bool b) {
  if (a) {
    if (b) {
      print('result');
    } else {
      print('result'); // BAD: Inner if/else identical
    }
  }
}

/// BAD: Whitespace doesn't matter (normalized before comparison)
void whitespaceNormalized(bool flag) {
  if (flag) {
    print('hello');
  } else {
    print('hello'); // BAD: Still identical after normalization
  }
}

/// BAD: Identical assignment
void assignmentExample(bool condition) {
  int result;
  if (condition) {
    result = 42;
  } else {
    result = 42; // BAD: Same assignment
  }
  print(result);
}

// ============================================================================
// GOOD: Correct patterns
// ============================================================================

/// GOOD: Different branches
int properProcess(bool condition, int value) {
  if (condition) {
    return value * 2;
  } else {
    return value * 3; // Different logic
  }
}

/// GOOD: Only if, no else (no comparison needed)
void conditionalAction(bool shouldAct) {
  if (shouldAct) {
    performAction();
  }
}

/// GOOD: Different ternary branches
String properMessage(bool isError) {
  return isError ? 'An error occurred' : 'Operation successful';
}

/// GOOD: Meaningful condition with different outcomes
void handleUserType(bool isPremium, int discount) {
  if (isPremium) {
    applyDiscount(discount * 2);
    sendPremiumNotification();
  } else {
    applyDiscount(discount);
    sendStandardNotification();
  }
}

/// GOOD: Early return pattern
int processWithGuard(bool isValid, int value) {
  if (!isValid) {
    return -1; // Early return
  }
  return value * 2;
}

// ============================================================================
// Edge Cases and Limitations
// ============================================================================

/// LIMITATION: Different variable names - NOT detected
///
/// These are semantically equivalent but use different variable names.
/// The rule CANNOT detect this because it only compares source text.
void differentVariableNames(bool condition) {
  final valueA = 10;
  final valueB = 10;

  if (condition) {
    print(valueA); // Uses valueA
  } else {
    print(valueB); // Uses valueB - NOT DETECTED as identical
  }
}

/// LIMITATION: Semantically equivalent expressions - NOT detected
void semanticallyEquivalent(bool condition) {
  if (condition) {
    print(1 + 1); // 2
  } else {
    print(2); // Also 2 - NOT DETECTED
  }
}

/// LIMITATION: Equivalent method calls - NOT detected
void equivalentCalls(bool condition, List<int> list) {
  if (condition) {
    print(list.length);
  } else {
    print(list.toList().length); // Same result, different code - NOT DETECTED
  }
}

/// EDGE CASE: Comments don't affect comparison
void commentsIgnored(bool condition) {
  if (condition) {
    // Comment in then branch
    print('result');
  } else {
    // Different comment in else branch
    print('result'); // BAD: Still detected (comments normalized out)
  }
}

/// EDGE CASE: else-if chains
void elseIfChain(int value) {
  if (value == 1) {
    print('one');
  } else if (value == 2) {
    print('two');
  } else {
    print('other');
  }
  // Each branch is different - this is fine
}

/// EDGE CASE: Identical else-if branches
void identicalElseIf(int value) {
  if (value == 1) {
    print('special');
  } else if (value == 2) {
    print('special'); // This specific pair would be compared
  } else {
    print('other');
  }
}

// ============================================================================
// Why This Happens
// ============================================================================

/// Common cause 1: Copy-paste error
///
/// Developer copies the if block to create else block but forgets to modify
void copyPasteError(bool isPremium, int price) {
  // Intended: premium users get 20% off, others get 10%
  if (isPremium) {
    final discount = price * 0.2;
    print('Discount: $discount');
  } else {
    final discount = price * 0.2; // Oops, should be 0.1!
    print('Discount: $discount');
  }
}

/// Common cause 2: Incomplete refactoring
///
/// The condition was meaningful before, but after refactoring both paths
/// ended up the same
void incompleteRefactoring(bool legacyMode) {
  // After migrating legacy users, this condition became meaningless
  if (legacyMode) {
    useNewSystem();
  } else {
    useNewSystem();
  }
}

/// Common cause 3: Defensive coding gone wrong
///
/// Developer adds else "just in case" but doesn't actually handle it differently
void defensiveCodingGoneWrong(String? status) {
  if (status != null) {
    processStatus('active');
  } else {
    processStatus('active'); // "Just in case" - but same logic!
  }
}

// ============================================================================
// How to Fix
// ============================================================================

/// Fix 1: Remove the condition entirely
void fixByRemovingCondition() {
  // Instead of:
  // if (condition) { doSomething(); } else { doSomething(); }

  // Just do:
  doSomething();
}

/// Fix 2: Make branches actually different
void fixByDifferentiating(bool isAdmin, String resource) {
  // Instead of identical branches, implement actual differences:
  if (isAdmin) {
    logAccess(resource, 'admin');
    grantFullAccess(resource);
  } else {
    logAccess(resource, 'user');
    grantLimitedAccess(resource);
  }
}

/// Fix 3: Use the condition value
void fixByUsingCondition(bool condition) {
  // Instead of ignoring the condition:
  if (condition) {
    performAction(); // Only act when condition is true
  }
}

// ============================================================================
// Runnable Demo
// ============================================================================

void main() {
  print('=== no-equal-then-else Demo ===\n');

  print('1. Identical if/else branches (will be flagged):\n');
  final result1 = processValue(true, 10);
  final result2 = processValue(false, 10);
  print('   processValue(true, 10) = $result1');
  print('   processValue(false, 10) = $result2');
  print('   (Both return same value - condition is meaningless!)');

  print('\n2. Different branches (correct):\n');
  final result3 = properProcess(true, 10);
  final result4 = properProcess(false, 10);
  print('   properProcess(true, 10) = $result3');
  print('   properProcess(false, 10) = $result4');
  print('   (Different results - condition is meaningful)');

  print('\n3. Limitation - different variable names NOT detected:\n');
  print('   differentVariableNames uses valueA vs valueB');
  print('   but both hold 10, so output is identical');
  differentVariableNames(true);
  differentVariableNames(false);

  print('\n4. Common cause - copy-paste error:\n');
  print('   Premium and non-premium get same discount (bug!)');
  copyPasteError(true, 100);
  copyPasteError(false, 100);

  print('\nRun "anteater analyze -p example/rules/safety" to see violations.');
}

// Helper functions
void logAction(String action) => print('   Logged: $action');
void notifyUser() => print('   User notified');
void performAction() => print('   Action performed');
void applyDiscount(num amount) => print('   Discount: $amount');
void sendPremiumNotification() => print('   Premium notification sent');
void sendStandardNotification() => print('   Standard notification sent');
void useNewSystem() => print('   Using new system');
void processStatus(String status) => print('   Status: $status');
void doSomething() => print('   Doing something');
void logAccess(String resource, String type) =>
    print('   Log: $type accessed $resource');
void grantFullAccess(String resource) => print('   Full access to $resource');
void grantLimitedAccess(String resource) =>
    print('   Limited access to $resource');
