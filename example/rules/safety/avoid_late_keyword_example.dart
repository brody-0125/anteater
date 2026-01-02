// ignore_for_file: unused_local_variable, unused_element, unused_field

/// Example: avoid-late-keyword
///
/// This file demonstrates the `avoid-late-keyword` rule.
///
/// ## What It Detects
/// - Variables declared with the `late` keyword without initializers
/// - `late` variables that could throw `LateInitializationError`
///
/// ## What It Allows
/// - `late final x = expression;` (lazy initialization pattern)
/// - This is a valid performance optimization
///
/// ## Why It Matters
/// - `late` defers null checking to runtime
/// - Accessing before initialization throws `LateInitializationError`
/// - Makes code harder to reason about
/// - Cannot check if a late variable is initialized
///
/// ## Severity
/// This rule has `info` severity by default (not warning).
///
/// ## Configuration
/// ```yaml
/// anteater:
///   rules:
///     - avoid-late-keyword
///     # Or with custom severity:
///     - avoid-late-keyword:
///         severity: warning
/// ```
///
/// Run with:
/// ```bash
/// anteater analyze -p example/rules/safety/avoid_late_keyword_example.dart
/// ```
library;

// ============================================================================
// BAD: Patterns that violate the rule
// ============================================================================

/// BAD: late without initializer
class UserProfile {
  /// BAD: late field - could throw LateInitializationError
  late String username;

  /// BAD: late non-final field
  late int age;

  /// BAD: late nullable type (defeats the purpose)
  late String? optionalField;

  void loadFromJson(Map<String, dynamic> json) {
    username = json['username'] as String;
    age = json['age'] as int;
  }
}

/// BAD: late in function scope
void processData() {
  late String result; // BAD: could be accessed before assignment

  // Imagine complex logic here where result might not be assigned
  // on all code paths
  result = 'processed';
  print(result);
}

/// BAD: late for dependency injection
class BadService {
  /// BAD: late injection - no compile-time guarantee
  late ApiClient client;

  void initialize(ApiClient c) {
    client = c;
  }

  void fetch() {
    // If initialize() wasn't called, this throws LateInitializationError
    client.get('/data');
  }
}

/// BAD: late final without initializer
class ConfigLoader {
  /// BAD: late final without initializer
  late final String configPath;

  /// BAD: late final without initializer
  late final Map<String, dynamic> settings;

  void load(String path) {
    configPath = path;
    settings = {'loaded': true};
  }
}

// ============================================================================
// GOOD: Allowed patterns
// ============================================================================

/// GOOD: late final WITH initializer (lazy initialization)
///
/// This pattern is ALLOWED because:
/// - The value is guaranteed to be computed on first access
/// - No risk of LateInitializationError
/// - Useful for expensive computations that may not be needed
class LazyComputation {
  /// GOOD: Lazy initialization pattern
  late final String expensiveValue = _computeExpensively();

  /// GOOD: Another lazy initialization
  late final List<int> processedData = _processData();

  String _computeExpensively() {
    print('Computing expensive value...');
    return 'computed';
  }

  List<int> _processData() {
    return [1, 2, 3].map((x) => x * 2).toList();
  }
}

// ============================================================================
// GOOD: Alternatives to late keyword
// ============================================================================

/// Alternative 1: Nullable type with null check
class SafeUserProfile {
  /// GOOD: Nullable instead of late
  String? username;
  int? age;

  bool get isLoaded => username != null && age != null;

  void loadFromJson(Map<String, dynamic> json) {
    username = json['username'] as String?;
    age = json['age'] as int?;
  }

  void displayProfile() {
    final name = username;
    final userAge = age;
    if (name != null && userAge != null) {
      print('User: $name, Age: $userAge');
    } else {
      print('Profile not loaded');
    }
  }
}

/// Alternative 2: Required constructor parameters
class SafeService {
  /// GOOD: Required via constructor - compile-time guarantee
  SafeService(this.client);

  final ApiClient client;

  void fetch() {
    client.get('/data'); // Always safe - client is guaranteed
  }
}

/// Alternative 3: Factory pattern
class SafeConfigLoader {
  /// GOOD: Private constructor with required params
  SafeConfigLoader._(this.configPath, this.settings);

  final String configPath;
  final Map<String, dynamic> settings;

  /// Factory that ensures all fields are set
  static Future<SafeConfigLoader> load(String path) async {
    final settings = await _loadSettings(path);
    return SafeConfigLoader._(path, settings);
  }

  static Future<Map<String, dynamic>> _loadSettings(String path) async {
    // Simulate loading
    return {'loaded': true};
  }
}

/// Alternative 4: Builder pattern
class UserBuilder {
  String? _name;
  int? _age;

  UserBuilder setName(String name) {
    _name = name;
    return this;
  }

  UserBuilder setAge(int age) {
    _age = age;
    return this;
  }

  User build() {
    final name = _name;
    final age = _age;
    if (name == null || age == null) {
      throw StateError('Name and age must be set');
    }
    return User(name, age);
  }
}

class User {
  User(this.name, this.age);
  final String name;
  final int age;
}

// ============================================================================
// Flutter-Specific Cases
// ============================================================================

/// In Flutter, late is sometimes used for controllers initialized in initState.
///
/// BAD (but common):
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   late TextEditingController controller;
///
///   @override
///   void initState() {
///     super.initState();
///     controller = TextEditingController();
///   }
/// }
/// ```
///
/// GOOD alternatives:
/// ```dart
/// // Option 1: Initialize directly
/// class _MyWidgetState extends State<MyWidget> {
///   final controller = TextEditingController();
/// }
///
/// // Option 2: Nullable with dispose check
/// class _MyWidgetState extends State<MyWidget> {
///   TextEditingController? _controller;
///   TextEditingController get controller => _controller!;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = TextEditingController();
///   }
/// }
/// ```

// ============================================================================
// Edge Cases
// ============================================================================

/// EDGE CASE: late with complex dependency
///
/// Sometimes late seems necessary for circular dependencies
class NodeA {
  late NodeB partner; // How to avoid?

  // Solution: Use nullable or redesign the relationship
  // NodeB? partner;
}

class NodeB {
  late NodeA partner;
}

/// EDGE CASE: late for test mocking
///
/// In tests, you might see:
/// ```dart
/// late MockService mockService;
///
/// setUp(() {
///   mockService = MockService();
/// });
/// ```
///
/// This is acceptable in TEST code, but avoid in production code.

// ============================================================================
// Runnable Demo
// ============================================================================

void main() {
  print('=== avoid-late-keyword Demo ===\n');

  // Demonstrate the problem with late
  print('1. Problem: LateInitializationError\n');

  final profile = UserProfile();
  // Uncommenting this would throw:
  // print(profile.username); // LateInitializationError!

  profile.loadFromJson({'username': 'john', 'age': 30});
  print('   After loading: ${profile.username}, ${profile.age}');

  print('\n2. ALLOWED: Lazy initialization pattern\n');

  final lazy = LazyComputation();
  print('   LazyComputation created (nothing computed yet)');
  print('   Accessing expensiveValue...');
  print('   Value: ${lazy.expensiveValue}');
  print('   Accessing again (cached): ${lazy.expensiveValue}');

  print('\n3. Alternative: Nullable with null check\n');

  final safeProfile = SafeUserProfile();
  print('   isLoaded: ${safeProfile.isLoaded}');
  safeProfile.loadFromJson({'username': 'jane', 'age': 25});
  print('   After load - isLoaded: ${safeProfile.isLoaded}');
  safeProfile.displayProfile();

  print('\n4. Alternative: Required constructor parameters\n');

  final client = ApiClient();
  final service = SafeService(client);
  // service.client is ALWAYS available - no risk of late error
  print('   SafeService created with guaranteed client');

  print('\nRun "anteater analyze -p example/rules/safety" to see violations.');
}

/// Helper class for examples
class ApiClient {
  void get(String path) => print('   GET $path');
}
