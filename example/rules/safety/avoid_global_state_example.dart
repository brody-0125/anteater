// ignore_for_file: unused_local_variable, unused_element, unused_field

/// Example: avoid-global-state
///
/// This file demonstrates the `avoid-global-state` rule.
///
/// ## What It Detects
/// - Mutable top-level variables (non-final, non-const)
/// - Mutable static fields in classes
///
/// ## Why It Matters
/// - Global mutable state is difficult to test
/// - Makes reasoning about program behavior harder
/// - Can cause subtle concurrency bugs in async code
/// - Violates dependency injection principles
///
/// ## Known Limitations
/// - **Does NOT detect mutable contents of final collections**
///   - `final List<int> items = []` is NOT flagged
///   - The reference is immutable, but contents can change
/// - Singleton patterns with `static final _instance` are NOT flagged
///
/// ## Configuration
/// ```yaml
/// anteater:
///   rules:
///     - avoid-global-state
/// ```
///
/// Run with:
/// ```bash
/// anteater analyze -p example/rules/safety/avoid_global_state_example.dart
/// ```
library;

// ============================================================================
// BAD: Patterns that violate the rule
// ============================================================================

/// BAD: Mutable top-level variable
var globalCounter = 0;

/// BAD: Mutable top-level string
String globalMessage = 'Hello';

/// BAD: Top-level list (var, not final)
var globalItems = <String>[];

/// BAD: Class with mutable static field
class AppState {
  /// BAD: Mutable static field
  static int instanceCount = 0;

  /// BAD: Mutable static configuration
  static String currentTheme = 'light';

  /// BAD: Mutable static cache
  static Map<String, dynamic> cache = {};
}

/// BAD: Another example of mutable static state
class Logger {
  /// BAD: Mutable log level
  static int logLevel = 1;

  /// BAD: Mutable enabled flag
  static bool isEnabled = true;
}

// ============================================================================
// GOOD: Correct patterns
// ============================================================================

/// GOOD: Immutable top-level constant
const String appVersion = '1.0.0';

/// GOOD: Final top-level variable (reference cannot change)
final DateTime startTime = DateTime.now();

/// GOOD: Private final (acceptable for singletons)
final _defaultConfig = {'timeout': 30};

/// GOOD: Class with immutable static fields
class SafeAppConfig {
  /// GOOD: Static constant
  static const int maxRetries = 3;

  /// GOOD: Static final
  static final Uri baseUrl = Uri.parse('https://api.example.com');

  /// GOOD: Private static final for singleton pattern
  static final SafeAppConfig _instance = SafeAppConfig._();
  factory SafeAppConfig() => _instance;
  SafeAppConfig._();
}

/// GOOD: Dependency injection pattern
class UserService {
  UserService(this._repository);

  final UserRepository _repository;

  Future<User?> getUser(int id) => _repository.findById(id);
}

abstract class UserRepository {
  Future<User?> findById(int id);
}

class User {
  User(this.id, this.name);
  final int id;
  final String name;
}

/// GOOD: Instance fields instead of static
class Counter {
  int value = 0; // Instance field is fine

  void increment() => value++;
  void reset() => value = 0;
}

/// GOOD: State management with encapsulation
class ConfigManager {
  ConfigManager._();
  static final ConfigManager instance = ConfigManager._();

  // Private mutable state with controlled access
  String _theme = 'light';

  String get theme => _theme;
  void setTheme(String newTheme) {
    _theme = newTheme;
    // Can add validation, logging, notifications here
  }
}

// ============================================================================
// Edge Cases and Limitations
// ============================================================================

/// LIMITATION: Final collections with mutable contents
///
/// These are NOT detected because the reference is final.
/// However, the contents CAN still be modified!
final List<int> finalButMutableList = [];
final Map<String, String> finalButMutableMap = {};
final Set<int> finalButMutableSet = {};

/// LIMITATION: Singleton pattern with final static
///
/// This is NOT flagged (and arguably shouldn't be)
class Singleton {
  Singleton._();
  static final Singleton _instance = Singleton._();
  static Singleton get instance => _instance;

  // Instance state is fine
  int counter = 0;
}

/// EDGE CASE: Late final static
///
/// This IS flagged because it's late (not truly final until initialized)
class LazyInitExample {
  // static late final String computed; // Would be flagged
  // To avoid: use a getter or initialize immediately
  static final String computed = _computeExpensiveValue();

  static String _computeExpensiveValue() => 'computed';
}

// ============================================================================
// Alternative Patterns
// ============================================================================

/// Alternative 1: Provider/Riverpod pattern (Flutter)
///
/// Instead of:
/// ```dart
/// static User? currentUser;
/// ```
///
/// Use a provider:
/// ```dart
/// final currentUserProvider = StateProvider<User?>((ref) => null);
/// ```

/// Alternative 2: Scoped instance via constructor
class ApiClient {
  ApiClient({required this.baseUrl, this.timeout = const Duration(seconds: 30)});

  final Uri baseUrl;
  final Duration timeout;

  // Now each test can create its own instance with different config
}

/// Alternative 3: InheritedWidget / Context (Flutter)
///
/// Instead of global theme:
/// ```dart
/// static String theme = 'light';
/// ```
///
/// Access via context:
/// ```dart
/// final theme = Theme.of(context);
/// ```

// ============================================================================
// Runnable Demo
// ============================================================================

void main() {
  print('=== avoid-global-state Demo ===\n');

  // Demonstrate the problem with global state
  print('1. Problem: Global state is hard to test\n');

  // Imagine testing code that uses globalCounter
  globalCounter = 0;
  incrementGlobal();
  incrementGlobal();
  print('   globalCounter after 2 increments: $globalCounter');

  // Another test might have modified it already!
  // This makes tests order-dependent and flaky

  print('\n2. Solution: Dependency injection\n');

  final counter = Counter();
  counter.increment();
  counter.increment();
  print('   counter.value after 2 increments: ${counter.value}');
  // Each test can create its own Counter instance

  print('\n3. Demonstrating final mutable collection limitation:\n');

  finalButMutableList.add(1);
  finalButMutableList.add(2);
  print('   finalButMutableList: $finalButMutableList');
  print('   (This is NOT detected by the rule!)');

  print('\n4. Safe singleton pattern:\n');

  Singleton.instance.counter++;
  print('   Singleton.instance.counter: ${Singleton.instance.counter}');
  print('   (Singleton pattern with final static is acceptable)');

  print('\nRun "anteater analyze -p example/rules/safety" to see violations.');
}

void incrementGlobal() {
  globalCounter++;
}
