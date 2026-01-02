// ignore_for_file: unused_local_variable, unused_element, dead_code
// ignore_for_file: empty_catches, empty_statements

/// Example: no-empty-block
///
/// This file demonstrates the `no-empty-block` rule.
///
/// ## What It Detects
/// - Empty function/method bodies
/// - Empty catch blocks
/// - Empty if/else/while/for blocks
/// - Empty switch statements
///
/// ## Severity by Context
/// | Context | Severity |
/// |---------|----------|
/// | Empty catch block | warning |
/// | Empty function body | info |
/// | Other empty blocks | warning |
///
/// ## Known Behavior
/// - Comments inside blocks PREVENT flagging
/// - Both line comments (`//`) and block comments (`/* */`) work
///
/// ## Configuration
/// ```yaml
/// anteater:
///   rules:
///     - no-empty-block
/// ```
///
/// Run with:
/// ```bash
/// anteater analyze -p example/rules/safety/no_empty_block_example.dart
/// ```
library;

// ============================================================================
// BAD: Patterns that violate the rule
// ============================================================================

/// BAD: Empty function body
void doNothing() {}

/// BAD: Empty method body
class EmptyMethods {
  void process() {}

  void handleEvent() {}

  int calculate() {
    return 0;
  } // This is fine - has a statement
}

/// BAD: Empty catch block - silently swallows errors
void riskyOperation() {
  try {
    throw Exception('Something went wrong');
  } catch (e) {} // BAD: Swallows exception silently
}

/// BAD: Empty if block
void checkCondition(bool condition) {
  if (condition) {} // BAD: Empty if block
}

/// BAD: Empty else block
void checkWithElse(bool condition) {
  if (condition) {
    print('true');
  } else {} // BAD: Empty else block
}

/// BAD: Empty while loop
void emptyLoop() {
  var i = 0;
  while (i < 10) {} // BAD: Also an infinite loop!
}

/// BAD: Empty for loop body
void emptyForLoop() {
  for (var i = 0; i < 10; i++) {} // BAD: Empty loop body
}

/// BAD: Empty switch statement
void emptySwitch(int value) {
  switch (value) {} // BAD: No case clauses
}

/// BAD: Empty callback
void setupCallbacks() {
  final items = [1, 2, 3];
  items.forEach((item) {}); // BAD: No-op callback
}

// ============================================================================
// GOOD: Correct patterns
// ============================================================================

/// GOOD: Comment explains why empty (line comment)
void intentionallyEmpty() {
  // No-op: This callback is required by the API but we don't need to do anything
}

/// GOOD: Comment explains why empty (block comment)
void anotherIntentionallyEmpty() {
  /* Intentionally empty - handled elsewhere */
}

/// GOOD: Throw UnimplementedError for abstract-like behavior
void toBeImplemented() {
  throw UnimplementedError('Subclass must override this method');
}

/// GOOD: Proper catch with logging
void properErrorHandling() {
  try {
    throw Exception('Error');
  } catch (e) {
    print('Error occurred: $e'); // Actual handling
  }
}

/// GOOD: Catch with comment explaining why empty
void acceptableEmptyCatch() {
  try {
    throw Exception('Expected error');
  } catch (e) {
    // Expected during normal operation - safe to ignore
  }
}

/// GOOD: Rethrow after logging
void catchAndRethrow() {
  try {
    throw Exception('Error');
  } catch (e) {
    print('Logging error: $e');
    rethrow;
  }
}

/// GOOD: If with actual content
void properCondition(bool condition) {
  if (condition) {
    print('Condition is true');
  }
}

/// GOOD: Actual loop body
void properLoop() {
  for (var i = 0; i < 10; i++) {
    print('Iteration $i');
  }
}

/// GOOD: Switch with cases
void properSwitch(int value) {
  switch (value) {
    case 0:
      print('Zero');
    case 1:
      print('One');
    default:
      print('Other');
  }
}

/// GOOD: Meaningful callback
void properCallback() {
  final items = [1, 2, 3];
  items.forEach((item) {
    print('Processing $item');
  });
}

// ============================================================================
// Edge Cases and Limitations
// ============================================================================

/// EDGE CASE: Constructor body
///
/// Empty constructor bodies are generally acceptable
class Point {
  Point(this.x, this.y); // No body needed - using initializing formals

  final int x;
  final int y;
}

/// EDGE CASE: Getter/setter bodies
class PropertyExample {
  int _value = 0;

  /// Empty getter bodies not typically flagged (expression body)
  int get value => _value;

  /// Setter with actual body
  set value(int newValue) {
    _value = newValue;
  }
}

/// EDGE CASE: Lambda expressions
void lambdaExamples() {
  // Empty lambda
  final noOp = () {}; // This IS flagged

  // Lambda with comment
  final intentionalNoOp = () {
    // Required callback, no action needed
  }; // This is NOT flagged (has comment)
}

/// EDGE CASE: Abstract method equivalent
abstract class Animal {
  /// In abstract class, no body is expected
  void makeSound();
}

/// EDGE CASE: Override with no-op
class SilentAnimal extends Animal {
  @override
  void makeSound() {
    // Silent animals don't make sounds
  }
}

/// EDGE CASE: Finally blocks
void finallyExample() {
  try {
    print('Trying...');
  } catch (e) {
    print('Caught: $e');
  } finally {} // BAD: Empty finally block
}

/// GOOD: Finally with cleanup
void properFinally() {
  try {
    print('Trying...');
  } catch (e) {
    print('Caught: $e');
  } finally {
    print('Cleanup');
  }
}

// ============================================================================
// Common Patterns
// ============================================================================

/// Pattern: Placeholder for future implementation
void futureFeature() {
  // TODO: Implement user authentication
  throw UnimplementedError('Coming in v2.0');
}

/// Pattern: Conditional no-op
void maybeDoSomething(bool shouldAct) {
  if (shouldAct) {
    performAction();
  }
  // else: intentionally no action needed
}

void performAction() => print('Action performed');

/// Pattern: Event handler that may not need all events
class EventHandler {
  void onStart() {
    print('Started');
  }

  void onProgress(int percent) {
    // Only care about start and complete
  }

  void onComplete() {
    print('Completed');
  }
}

// ============================================================================
// Runnable Demo
// ============================================================================

void main() {
  print('=== no-empty-block Demo ===\n');

  print('1. Empty catch block hides errors:\n');
  riskyOperation();
  print('   (Exception was silently swallowed!)');

  print('\n2. Proper error handling:\n');
  properErrorHandling();

  print('\n3. Empty callback vs meaningful callback:\n');
  print('   Empty callback (no output):');
  [1, 2, 3].forEach((item) {});
  print('   Meaningful callback:');
  [1, 2, 3].forEach((item) => print('   Processing $item'));

  print('\n4. Comment prevents flagging:\n');
  intentionallyEmpty();
  print('   intentionallyEmpty() called (has explanatory comment)');

  print('\n5. Using UnimplementedError:\n');
  try {
    toBeImplemented();
  } catch (e) {
    print('   Caught: $e');
  }

  print('\nRun "anteater analyze -p example/rules/safety" to see violations.');
}
