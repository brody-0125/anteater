// ignore_for_file: unused_local_variable, dead_code, unused_element
// ignore_for_file: discarded_futures, unawaited_futures

/// Example: prefer-async-await
///
/// This file demonstrates the `prefer-async-await` rule.
///
/// ## What It Detects
/// - Chained `.then().then()` calls
/// - Nested `.then()` calls inside callbacks
///
/// ## What It Does NOT Flag
/// - Single `.then()` call (might be intentional fire-and-forget)
/// - `.then()` on Stream (different semantics)
///
/// ## Why It Matters
/// - async/await is more readable than callback chains
/// - Error handling is clearer with try/catch
/// - Easier to debug and step through
/// - No callback nesting (pyramid of doom)
///
/// ## Configuration
/// ```yaml
/// anteater:
///   rules:
///     - prefer-async-await
/// ```
///
/// Run with:
/// ```bash
/// anteater analyze -p example/rules/quality/prefer_async_await_example.dart
/// ```
library;

import 'dart:async';

// ============================================================================
// BAD: Patterns that violate the rule
// ============================================================================

/// BAD: Chained .then() calls
Future<void> chainedThen() {
  return fetchUser()
      .then((user) => fetchOrders(user.id)) // First .then()
      .then((orders) => processOrders(orders)); // BAD: Chained .then()
}

/// BAD: Longer chain with catchError
Future<void> longChain() {
  return fetchUser()
      .then((user) => fetchOrders(user.id)) // BAD: Chain starts
      .then((orders) => calculateTotal(orders))
      .then((total) => applyDiscount(total))
      .catchError((Object e) => handleError(e));
}

/// BAD: Nested .then() inside callback
Future<void> nestedThen() {
  return fetchUser().then((user) {
    // BAD: Nested .then() inside callback
    return fetchOrders(user.id).then((orders) {
      return processOrders(orders);
    });
  });
}

/// BAD: Deep nesting (pyramid of doom)
Future<void> pyramidOfDoom() {
  return fetchUser().then((user) {
    return fetchOrders(user.id).then((orders) {
      return fetchPayments(user.id).then((payments) {
        return reconcile(orders, payments);
      });
    });
  });
}

/// BAD: Mixed chain and catchError
Future<void> mixedChain() {
  return fetchUser()
      .then((user) => fetchOrders(user.id))
      .then((orders) => processOrders(orders))
      .catchError((Object e) => handleError(e))
      .whenComplete(() => cleanup());
}

// ============================================================================
// GOOD: Correct patterns using async/await
// ============================================================================

/// GOOD: Simple async/await
Future<void> simpleAsyncAwait() async {
  final user = await fetchUser();
  final orders = await fetchOrders(user.id);
  await processOrders(orders);
}

/// GOOD: With error handling
Future<void> asyncWithErrorHandling() async {
  try {
    final user = await fetchUser();
    final orders = await fetchOrders(user.id);
    final total = await calculateTotal(orders);
    await applyDiscount(total);
  } catch (e) {
    await handleError(e);
  }
}

/// GOOD: With finally cleanup
Future<void> asyncWithFinally() async {
  try {
    final user = await fetchUser();
    final orders = await fetchOrders(user.id);
    await processOrders(orders);
  } catch (e) {
    await handleError(e);
  } finally {
    await cleanup();
  }
}

/// GOOD: Parallel operations with Future.wait
Future<void> parallelOperations() async {
  final user = await fetchUser();

  // Parallel fetching
  final results = await Future.wait([
    fetchOrders(user.id),
    fetchPayments(user.id),
  ]);

  final orders = results[0] as List<Order>;
  final payments = results[1] as List<Payment>;
  await reconcile(orders, payments);
}

/// GOOD: Sequential with early return
Future<String?> asyncWithEarlyReturn() async {
  final user = await fetchUser();
  if (user.isGuest) {
    return null; // Early return
  }

  final orders = await fetchOrders(user.id);
  if (orders.isEmpty) {
    return 'No orders';
  }

  return 'Found ${orders.length} orders';
}

// ============================================================================
// ACCEPTABLE: Single .then() (not flagged)
// ============================================================================

/// ACCEPTABLE: Single .then() for fire-and-forget
void fireAndForget() {
  // Single .then() might be intentional
  fetchUser().then((user) => logUserAccess(user));
  // Not waiting for result - continues immediately
  print('Continuing without waiting...');
}

/// ACCEPTABLE: Single .then() for simple transformation
Future<String> simpleTransform() {
  // Single .then() for simple mapping
  return fetchUser().then((user) => user.name);
}

/// ACCEPTABLE: When you need the Future immediately
Future<void> returningFuture() {
  // Sometimes you want to return the Future without awaiting
  return fetchUser().then((user) => logUserAccess(user));
}

// ============================================================================
// Edge Cases
// ============================================================================

/// EDGE CASE: .then() on non-Future types
///
/// Some libraries have .then() methods on non-Future types (e.g., Result types)
/// These might be falsely flagged if chained.

/// EDGE CASE: Stream operations
///
/// This rule does NOT apply to Stream operations
void streamExample() {
  final controller = StreamController<int>();

  // This is fine - different semantics
  controller.stream.listen((event) {
    print('Event: $event');
  });

  controller.close();
}

/// EDGE CASE: Intentional callback style for library compatibility
///
/// Some APIs require callback-based patterns
void callbackApiCompatibility(Future<User> userFuture, void Function(User) callback) {
  // Sometimes callback style is required by an API
  userFuture.then(callback);
}

// ============================================================================
// Why async/await is Better
// ============================================================================

/// Comparison: Same logic in both styles

// 1. Error handling clarity
Future<void> errorHandlingCallback() {
  return fetchUser()
      .then((user) => fetchOrders(user.id))
      .then((orders) => processOrders(orders))
      .catchError((Object e) {
        // Which operation failed? Hard to tell
        return handleError(e);
      });
}

Future<void> errorHandlingAsync() async {
  try {
    final user = await fetchUser();
    try {
      final orders = await fetchOrders(user.id);
      await processOrders(orders);
    } catch (e) {
      // Clearly: fetchOrders or processOrders failed
      print('Order processing failed: $e');
    }
  } catch (e) {
    // Clearly: fetchUser failed
    print('User fetch failed: $e');
  }
}

// 2. Conditional logic
Future<void> conditionalCallback() {
  return fetchUser().then((user) {
    if (user.isPremium) {
      return fetchPremiumOrders(user.id).then((orders) => processPremium(orders));
    } else {
      return fetchOrders(user.id).then((orders) => processOrders(orders));
    }
  });
}

Future<void> conditionalAsync() async {
  final user = await fetchUser();

  if (user.isPremium) {
    final orders = await fetchPremiumOrders(user.id);
    await processPremium(orders);
  } else {
    final orders = await fetchOrders(user.id);
    await processOrders(orders);
  }
}

// 3. Loop with async operations
Future<void> loopCallback(List<int> ids) {
  // Very difficult with callbacks!
  var chain = Future.value();
  for (final id in ids) {
    chain = chain.then((_) => processId(id));
  }
  return chain;
}

Future<void> loopAsync(List<int> ids) async {
  for (final id in ids) {
    await processId(id);
  }
}

// ============================================================================
// Runnable Demo
// ============================================================================

Future<void> main() async {
  print('=== prefer-async-await Demo ===\n');

  print('1. Callback style (harder to read):\n');
  print('''
  fetchUser()
    .then((user) => fetchOrders(user.id))
    .then((orders) => processOrders(orders))
    .catchError((e) => handleError(e));
''');

  print('2. async/await style (cleaner):\n');
  print('''
  try {
    final user = await fetchUser();
    final orders = await fetchOrders(user.id);
    await processOrders(orders);
  } catch (e) {
    await handleError(e);
  }
''');

  print('3. Running async version...\n');
  await simpleAsyncAwait();
  print('\n   Completed successfully!');

  print('\nRun "anteater analyze -p example/rules/quality" to see violations.');
}

// Helper types and functions
class User {
  final int id;
  final String name;
  final bool isPremium;
  final bool isGuest;

  User({
    required this.id,
    required this.name,
    this.isPremium = false,
    this.isGuest = false,
  });
}

class Order {
  final int id;
  Order(this.id);
}

class Payment {
  final int id;
  Payment(this.id);
}

Future<User> fetchUser() async {
  print('   Fetching user...');
  await Future<void>.delayed(const Duration(milliseconds: 100));
  return User(id: 1, name: 'John');
}

Future<List<Order>> fetchOrders(int userId) async {
  print('   Fetching orders for user $userId...');
  await Future<void>.delayed(const Duration(milliseconds: 100));
  return [Order(1), Order(2)];
}

Future<List<Order>> fetchPremiumOrders(int userId) async {
  return fetchOrders(userId);
}

Future<List<Payment>> fetchPayments(int userId) async {
  return [Payment(1)];
}

Future<void> processOrders(List<Order> orders) async {
  print('   Processing ${orders.length} orders...');
}

Future<void> processPremium(List<Order> orders) async {
  print('   Processing premium orders...');
}

Future<double> calculateTotal(List<Order> orders) async {
  return orders.length * 10.0;
}

Future<void> applyDiscount(double total) async {
  print('   Applying discount to $total');
}

Future<void> reconcile(List<Order> orders, List<Payment> payments) async {
  print('   Reconciling orders and payments');
}

Future<void> handleError(Object e) async {
  print('   Error: $e');
}

Future<void> cleanup() async {
  print('   Cleaning up...');
}

void logUserAccess(User user) {
  print('   User ${user.name} accessed');
}

Future<void> processId(int id) async {
  print('   Processing ID: $id');
}
