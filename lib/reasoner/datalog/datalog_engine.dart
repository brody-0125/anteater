import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Datalog engine interface for relational reasoning.
///
/// Integrates with Soufflé via FFI for high-performance
/// points-to analysis, reachability queries, and constraint solving.
abstract class DatalogEngine {
  /// Loads facts into the engine.
  void loadFacts(List<Fact> facts);

  /// Runs the Datalog program to compute derived facts.
  void run();

  /// Queries a relation and returns matching tuples.
  List<List<Object>> query(String relationName);

  /// Clears all facts.
  void clear();
}

/// A Datalog fact (tuple in a relation).
class Fact {
  final String relation;
  final List<Object> values;

  /// Creates a Fact with the given values.
  ///
  /// Note: For immutability guarantees, use [Fact.immutable] which
  /// wraps the values in an unmodifiable list.
  const Fact(this.relation, this.values);

  /// Creates a Fact with an unmodifiable copy of the values list.
  ///
  /// Use this factory when creating facts at runtime to ensure
  /// the fact cannot be mutated after creation.
  factory Fact.immutable(String relation, List<Object> values) =>
      Fact(relation, List.unmodifiable(values));

  @override
  String toString() => '$relation(${values.join(', ')})';
}

/// Native Soufflé engine integration via FFI.
///
/// Requires pre-compiled Soufflé program as shared library.
class SouffleEngine implements DatalogEngine {
  final String libraryPath;
  late final DynamicLibrary _lib;
  bool _initialized = false;

  // Native function signatures
  late final void Function() _init;
  late final void Function() _run;
  late final void Function() _clear;
  // ignore: unused_field - placeholder for future FFI implementation
  late final void Function(Pointer<Utf8>, Pointer<Utf8>) _loadFact;
  // ignore: unused_field - placeholder for future FFI implementation
  late final Pointer<Utf8> Function(Pointer<Utf8>) _queryRelation;

  SouffleEngine(this.libraryPath);

  /// Initializes the Soufflé engine.
  void initialize() {
    if (_initialized) return;

    _lib = DynamicLibrary.open(libraryPath);

    _init = _lib.lookupFunction<Void Function(), void Function()>(
      'souffle_init',
    );
    _run = _lib.lookupFunction<Void Function(), void Function()>(
      'souffle_run',
    );
    _clear = _lib.lookupFunction<Void Function(), void Function()>(
      'souffle_clear',
    );

    _init();
    _initialized = true;
  }

  @override
  void loadFacts(List<Fact> facts) {
    for (final fact in facts) {
      _loadFactNative(fact);
    }
  }

  void _loadFactNative(Fact fact) {
    // TODO: Implement native fact loading
    // Serialize fact to string format and call native function
  }

  @override
  void run() {
    if (!_initialized) {
      throw StateError('Engine not initialized');
    }
    _run();
  }

  @override
  List<List<Object>> query(String relationName) {
    // TODO: Implement native query
    return [];
  }

  @override
  void clear() {
    if (_initialized) {
      _clear();
    }
  }
}

/// In-memory Datalog engine for testing and small programs.
class InMemoryDatalogEngine implements DatalogEngine {
  final Map<String, List<List<Object>>> _facts = {};
  final Map<String, List<List<Object>>> _derived = {};
  final List<DatalogRule> _rules = [];

  /// Maximum iterations before termination (prevents infinite loops).
  final int maxIterations;

  /// Whether the engine reached the maximum iteration limit during run().
  ///
  /// If true, the analysis may be incomplete due to forced termination.
  /// This typically indicates either a bug in the rules or an extremely
  /// large/complex program.
  bool _reachedMaxIterations = false;

  /// Total iterations performed during the last run().
  int _totalIterations = 0;

  /// Creates an in-memory Datalog engine.
  ///
  /// [maxIterations] sets the limit before forced termination.
  /// Default is 100000 which is sufficient for most programs.
  InMemoryDatalogEngine({this.maxIterations = 100000});

  /// Whether the last run() reached the iteration limit.
  bool get reachedMaxIterations => _reachedMaxIterations;

  /// Total iterations performed during the last run().
  int get totalIterations => _totalIterations;

  /// Adds a rule to the engine.
  void addRule(DatalogRule rule) {
    _rules.add(rule);
  }

  @override
  void loadFacts(List<Fact> facts) {
    for (final fact in facts) {
      _facts.putIfAbsent(fact.relation, () => []).add(fact.values);
    }
  }

  @override
  void run() {
    _reachedMaxIterations = false;
    _totalIterations = 0;

    // Group rules by stratum for stratified evaluation
    final strata = <int, List<DatalogRule>>{};
    for (final rule in _rules) {
      strata.putIfAbsent(rule.stratum, () => []).add(rule);
    }

    // Evaluate each stratum to fixpoint before moving to next
    final sortedStrata = strata.keys.toList()..sort();
    for (final stratumId in sortedStrata) {
      if (_reachedMaxIterations) break;
      _runStratum(strata[stratumId]!);
    }
  }

  /// Runs rules in a single stratum to fixpoint.
  void _runStratum(List<DatalogRule> rules) {
    var changed = true;
    while (changed && _totalIterations < maxIterations) {
      changed = false;
      _totalIterations++;

      for (final rule in rules) {
        final newFacts = rule.evaluate(_facts, _derived);
        for (final fact in newFacts) {
          final existing = _derived[fact.relation] ?? [];
          if (!_containsTuple(existing, fact.values)) {
            _derived.putIfAbsent(fact.relation, () => []).add(fact.values);
            changed = true;
          }
        }
      }
    }

    if (_totalIterations >= maxIterations) {
      _reachedMaxIterations = true;
    }
  }

  bool _containsTuple(List<List<Object>> tuples, List<Object> tuple) {
    for (final t in tuples) {
      if (_tuplesEqual(t, tuple)) return true;
    }
    return false;
  }

  bool _tuplesEqual(List<Object> a, List<Object> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  List<List<Object>> query(String relationName) {
    return [...?_facts[relationName], ...?_derived[relationName]];
  }

  @override
  void clear() {
    _facts.clear();
    _derived.clear();
  }
}

/// A Datalog rule with stratification support.
///
/// Rules with negation must be placed in a higher stratum than
/// the predicates they negate. For example, if rule R uses `!P`,
/// then R must be in a stratum > stratum of rules producing P.
abstract class DatalogRule {
  final String headRelation;

  /// Stratum for stratified evaluation.
  ///
  /// Rules in stratum N are evaluated to fixpoint before rules in stratum N+1.
  /// Rules with negation should have higher stratum than their negated dependencies.
  final int stratum;

  DatalogRule(this.headRelation, {this.stratum = 0});

  /// Evaluates the rule and returns derived facts.
  List<Fact> evaluate(
    Map<String, List<List<Object>>> facts,
    Map<String, List<List<Object>>> derived,
  );

  /// Returns a lazy iterable combining facts and derived tuples for a relation.
  ///
  /// This avoids allocating a new list on every rule evaluation by yielding
  /// elements from both sources without copying. O(1) allocation instead of O(n).
  @pragma('vm:prefer-inline')
  Iterable<List<Object>> getCombined(
    String relation,
    Map<String, List<List<Object>>> facts,
    Map<String, List<List<Object>>> derived,
  ) sync* {
    final f = facts[relation];
    if (f != null) yield* f;
    final d = derived[relation];
    if (d != null) yield* d;
  }
}

// ============================================================
// Pre-defined rules for points-to analysis
// ============================================================

/// VarPointsTo(var, heap) :- Assign(var, alloc), Alloc(alloc, heap).
class AllocRule extends DatalogRule {
  AllocRule() : super('VarPointsTo');

  @override
  List<Fact> evaluate(
    Map<String, List<List<Object>>> facts,
    Map<String, List<List<Object>>> derived,
  ) {
    final result = <Fact>[];
    final assigns = facts['Assign'] ?? [];
    final allocs = facts['Alloc'] ?? [];

    for (final assign in assigns) {
      final varId = assign[0];
      final exprId = assign[1];

      for (final alloc in allocs) {
        if (alloc[0] == exprId) {
          result.add(Fact('VarPointsTo', [varId, alloc[1]]));
        }
      }
    }

    return result;
  }
}

/// VarPointsTo(var1, heap) :- Assign(var1, var2), VarPointsTo(var2, heap).
class CopyRule extends DatalogRule {
  CopyRule() : super('VarPointsTo');

  @override
  List<Fact> evaluate(
    Map<String, List<List<Object>>> facts,
    Map<String, List<List<Object>>> derived,
  ) {
    final result = <Fact>[];
    final assigns = facts['Assign'] ?? [];
    final pointsTo = getCombined('VarPointsTo', facts, derived);

    for (final assign in assigns) {
      final var1 = assign[0];
      final var2 = assign[1];

      for (final pt in pointsTo) {
        if (pt[0] == var2) {
          result.add(Fact('VarPointsTo', [var1, pt[1]]));
        }
      }
    }

    return result;
  }
}

/// HeapPointsTo(baseHeap, field, targetHeap) :-
///   StoreField(base, field, source),
///   VarPointsTo(base, baseHeap),
///   VarPointsTo(source, targetHeap).
class StoreFieldRule extends DatalogRule {
  StoreFieldRule() : super('HeapPointsTo');

  @override
  List<Fact> evaluate(
    Map<String, List<List<Object>>> facts,
    Map<String, List<List<Object>>> derived,
  ) {
    final result = <Fact>[];
    final stores = facts['StoreField'] ?? [];
    final pointsTo = getCombined('VarPointsTo', facts, derived);

    for (final store in stores) {
      final baseVar = store[0];
      final field = store[1];
      final sourceVar = store[2];

      // Find what base points to
      for (final basePt in pointsTo) {
        if (basePt[0] == baseVar) {
          final baseHeap = basePt[1];

          // Find what source points to
          for (final sourcePt in pointsTo) {
            if (sourcePt[0] == sourceVar) {
              final targetHeap = sourcePt[1];
              result.add(Fact('HeapPointsTo', [baseHeap, field, targetHeap]));
            }
          }
        }
      }
    }

    return result;
  }
}

/// VarPointsTo(target, targetHeap) :-
///   LoadField(base, field, target),
///   VarPointsTo(base, baseHeap),
///   HeapPointsTo(baseHeap, field, targetHeap).
class LoadFieldRule extends DatalogRule {
  LoadFieldRule() : super('VarPointsTo');

  @override
  List<Fact> evaluate(
    Map<String, List<List<Object>>> facts,
    Map<String, List<List<Object>>> derived,
  ) {
    final result = <Fact>[];
    final loads = facts['LoadField'] ?? [];
    final pointsTo = getCombined('VarPointsTo', facts, derived);
    final heapPointsTo = getCombined('HeapPointsTo', facts, derived);

    for (final load in loads) {
      final baseVar = load[0];
      final field = load[1];
      final targetVar = load[2];

      // Find what base points to
      for (final basePt in pointsTo) {
        if (basePt[0] == baseVar) {
          final baseHeap = basePt[1];

          // Find what the heap field points to
          for (final heapPt in heapPointsTo) {
            if (heapPt[0] == baseHeap && heapPt[1] == field) {
              final targetHeap = heapPt[2];
              result.add(Fact('VarPointsTo', [targetVar, targetHeap]));
            }
          }
        }
      }
    }

    return result;
  }
}

/// Reachable(to) :- Reachable(from), Flow(from, to).
class ReachabilityRule extends DatalogRule {
  ReachabilityRule() : super('Reachable');

  @override
  List<Fact> evaluate(
    Map<String, List<List<Object>>> facts,
    Map<String, List<List<Object>>> derived,
  ) {
    final result = <Fact>[];
    final flows = facts['Flow'] ?? [];
    final reachable = getCombined('Reachable', facts, derived);

    for (final flow in flows) {
      final from = flow[0];
      final to = flow[1];

      for (final r in reachable) {
        if (r[0] == from) {
          result.add(Fact('Reachable', [to]));
        }
      }
    }

    return result;
  }
}

/// Mutable(heap) :- StoreField(base, _, _), VarPointsTo(base, heap).
class MutabilityRule extends DatalogRule {
  MutabilityRule() : super('Mutable');

  @override
  List<Fact> evaluate(
    Map<String, List<List<Object>>> facts,
    Map<String, List<List<Object>>> derived,
  ) {
    final result = <Fact>[];
    final stores = facts['StoreField'] ?? [];
    final pointsTo = getCombined('VarPointsTo', facts, derived);

    for (final store in stores) {
      final baseVar = store[0];

      for (final pt in pointsTo) {
        if (pt[0] == baseVar) {
          result.add(Fact('Mutable', [pt[1]]));
        }
      }
    }

    return result;
  }
}

/// Mutable(heap) :- HeapPointsTo(heap, _, targetHeap), Mutable(targetHeap).
/// (Transitive mutability)
class TransitiveMutabilityRule extends DatalogRule {
  TransitiveMutabilityRule() : super('Mutable');

  @override
  List<Fact> evaluate(
    Map<String, List<List<Object>>> facts,
    Map<String, List<List<Object>>> derived,
  ) {
    final result = <Fact>[];
    final heapPointsTo = getCombined('HeapPointsTo', facts, derived);
    final mutable = getCombined('Mutable', facts, derived);

    for (final hpt in heapPointsTo) {
      final heap = hpt[0];
      final targetHeap = hpt[2];

      for (final m in mutable) {
        if (m[0] == targetHeap) {
          result.add(Fact('Mutable', [heap]));
        }
      }
    }

    return result;
  }
}

/// DeepImmutable(heap) :- Alloc(_, heap), !Mutable(heap).
///
/// This rule uses negation (!Mutable) and must be in stratum 1
/// to ensure Mutable facts are complete before evaluation.
class ImmutabilityRule extends DatalogRule {
  ImmutabilityRule() : super('DeepImmutable', stratum: 1);

  @override
  List<Fact> evaluate(
    Map<String, List<List<Object>>> facts,
    Map<String, List<List<Object>>> derived,
  ) {
    // This is a stratified rule - only evaluate after Mutable is complete
    final result = <Fact>[];
    final allocs = facts['Alloc'] ?? [];
    final mutable = {...?facts['Mutable'], ...?derived['Mutable']};

    // Convert mutable to set for efficient lookup
    final mutableHeaps = <Object>{};
    for (final m in mutable) {
      mutableHeaps.add(m[0]);
    }

    for (final alloc in allocs) {
      final heap = alloc[1];
      if (!mutableHeaps.contains(heap)) {
        result.add(Fact('DeepImmutable', [heap]));
      }
    }

    return result;
  }
}

/// CallGraph(site, method) :- Call(site, receiver, method, _), VarPointsTo(receiver, _).
class CallGraphRule extends DatalogRule {
  CallGraphRule() : super('CallGraph');

  @override
  List<Fact> evaluate(
    Map<String, List<List<Object>>> facts,
    Map<String, List<List<Object>>> derived,
  ) {
    final result = <Fact>[];
    final calls = facts['Call'] ?? [];
    final pointsTo = getCombined('VarPointsTo', facts, derived);

    for (final call in calls) {
      final site = call[0];
      final receiver = call[1];
      final method = call[2];

      // Static calls (receiver == -1) always resolve
      if (receiver == -1) {
        result.add(Fact('CallGraph', [site, method]));
        continue;
      }

      // Instance calls only resolve if receiver points to something
      for (final pt in pointsTo) {
        if (pt[0] == receiver) {
          result.add(Fact('CallGraph', [site, method]));
          break; // One edge per call site
        }
      }
    }

    return result;
  }
}

// ============================================================
// Taint tracking rules for security analysis
// ============================================================

/// TaintedVar(var, source, label) :- TaintSource(var, label).
///
/// Initializes taint from annotated source locations.
/// TaintSource facts are provided as input (EDB) marking where
/// untrusted data enters the program.
class TaintSourceRule extends DatalogRule {
  TaintSourceRule() : super('TaintedVar');

  @override
  List<Fact> evaluate(
    Map<String, List<List<Object>>> facts,
    Map<String, List<List<Object>>> derived,
  ) {
    final result = <Fact>[];
    final sources = facts['TaintSource'] ?? [];

    for (final source in sources) {
      final varId = source[0];
      final label = source[1];
      // TaintedVar(var, source, label) - var is tainted, source is origin, label is category
      result.add(Fact('TaintedVar', [varId, varId, label]));
    }

    return result;
  }
}

/// TaintedVar(target, source, label) :-
///   Assign(target, from), TaintedVar(from, source, label).
///
/// Propagates taint through variable assignments.
/// If a tainted variable is assigned to another variable,
/// the target becomes tainted with the same source and label.
class TaintPropagationRule extends DatalogRule {
  TaintPropagationRule() : super('TaintedVar');

  @override
  List<Fact> evaluate(
    Map<String, List<List<Object>>> facts,
    Map<String, List<List<Object>>> derived,
  ) {
    final result = <Fact>[];
    final assigns = facts['Assign'] ?? [];
    final tainted = getCombined('TaintedVar', facts, derived);

    for (final assign in assigns) {
      final target = assign[0];
      final from = assign[1];

      for (final t in tainted) {
        if (t[0] == from) {
          // Propagate taint: target inherits source and label from 'from'
          result.add(Fact('TaintedVar', [target, t[1], t[2]]));
        }
      }
    }

    return result;
  }
}

/// TaintViolation(sink, source, taintLabel, sinkLabel) :-
///   TaintSink(sink, sinkLabel), TaintedVar(sink, source, taintLabel).
///
/// Detects when tainted data reaches a security-sensitive sink.
/// Reports the sink location, the original taint source, and both labels.
class TaintViolationRule extends DatalogRule {
  TaintViolationRule() : super('TaintViolation');

  @override
  List<Fact> evaluate(
    Map<String, List<List<Object>>> facts,
    Map<String, List<List<Object>>> derived,
  ) {
    final result = <Fact>[];
    final sinks = facts['TaintSink'] ?? [];
    final tainted = getCombined('TaintedVar', facts, derived);

    for (final sink in sinks) {
      final sinkVar = sink[0];
      final sinkLabel = sink[1];

      for (final t in tainted) {
        if (t[0] == sinkVar) {
          // Violation: tainted data reached sink
          result.add(Fact('TaintViolation', [sinkVar, t[1], t[2], sinkLabel]));
        }
      }
    }

    return result;
  }
}

/// TaintedVar(target, source, label) :-
///   LoadField(base, field, target),
///   VarPointsTo(base, baseHeap),
///   TaintedHeap(baseHeap, field, source, label).
///
/// Propagates taint through field loads (requires points-to analysis).
class TaintLoadFieldRule extends DatalogRule {
  TaintLoadFieldRule() : super('TaintedVar');

  @override
  List<Fact> evaluate(
    Map<String, List<List<Object>>> facts,
    Map<String, List<List<Object>>> derived,
  ) {
    final result = <Fact>[];
    final loads = facts['LoadField'] ?? [];
    final pointsTo = getCombined('VarPointsTo', facts, derived);
    final taintedHeap = getCombined('TaintedHeap', facts, derived);

    for (final load in loads) {
      final baseVar = load[0];
      final field = load[1];
      final targetVar = load[2];

      for (final basePt in pointsTo) {
        if (basePt[0] == baseVar) {
          final baseHeap = basePt[1];

          for (final th in taintedHeap) {
            if (th[0] == baseHeap && th[1] == field) {
              result.add(Fact('TaintedVar', [targetVar, th[2], th[3]]));
            }
          }
        }
      }
    }

    return result;
  }
}

/// TaintedHeap(baseHeap, field, source, label) :-
///   StoreField(base, field, sourceVar),
///   VarPointsTo(base, baseHeap),
///   TaintedVar(sourceVar, source, label).
///
/// Propagates taint through field stores to heap locations.
class TaintStoreFieldRule extends DatalogRule {
  TaintStoreFieldRule() : super('TaintedHeap');

  @override
  List<Fact> evaluate(
    Map<String, List<List<Object>>> facts,
    Map<String, List<List<Object>>> derived,
  ) {
    final result = <Fact>[];
    final stores = facts['StoreField'] ?? [];
    final pointsTo = getCombined('VarPointsTo', facts, derived);
    final tainted = getCombined('TaintedVar', facts, derived);

    for (final store in stores) {
      final baseVar = store[0];
      final field = store[1];
      final sourceVar = store[2];

      for (final basePt in pointsTo) {
        if (basePt[0] == baseVar) {
          final baseHeap = basePt[1];

          for (final t in tainted) {
            if (t[0] == sourceVar) {
              result.add(Fact('TaintedHeap', [baseHeap, field, t[1], t[2]]));
            }
          }
        }
      }
    }

    return result;
  }
}

/// Factory to create a fully configured points-to analysis engine.
class PointsToEngineFactory {
  /// Creates an InMemory engine with all standard rules.
  static InMemoryDatalogEngine create() {
    final engine = InMemoryDatalogEngine();

    // Add all rules in evaluation order (stratum 0)
    engine.addRule(AllocRule());
    engine.addRule(CopyRule());
    engine.addRule(StoreFieldRule());
    engine.addRule(LoadFieldRule());
    engine.addRule(ReachabilityRule());
    engine.addRule(MutabilityRule());
    engine.addRule(TransitiveMutabilityRule());
    engine.addRule(CallGraphRule());

    return engine;
  }

  /// Creates an engine with immutability analysis.
  ///
  /// ImmutabilityRule is in stratum 1 and will be evaluated after
  /// all stratum 0 rules reach fixpoint, ensuring Mutable facts are complete.
  static InMemoryDatalogEngine createWithImmutability() {
    final engine = create();
    // ImmutabilityRule is in stratum 1 - evaluated after stratum 0 fixpoint
    engine.addRule(ImmutabilityRule());
    return engine;
  }
}

/// Factory to create a taint tracking analysis engine.
///
/// ## Input Facts (EDB)
///
/// - `TaintSource(varId, label)`: Marks a variable as a taint source.
///   Label is a category like "user_input", "network", "file", etc.
///
/// - `TaintSink(varId, label)`: Marks a variable as a security-sensitive sink.
///   Label is a category like "sql_query", "html_output", "exec", etc.
///
/// - `Assign(target, source)`: Variable assignment.
///
/// - `Alloc(exprId, heapId)`: Heap allocation (for field-sensitive tracking).
///
/// - `StoreField(base, field, source)`: Field store.
///
/// - `LoadField(base, field, target)`: Field load.
///
/// ## Output Facts (IDB)
///
/// - `TaintedVar(varId, sourceId, label)`: Variable is tainted.
///
/// - `TaintedHeap(heapId, field, sourceId, label)`: Heap field is tainted.
///
/// - `TaintViolation(sinkId, sourceId, taintLabel, sinkLabel)`:
///   Tainted data reached a sink (security vulnerability).
class TaintEngineFactory {
  /// Creates an engine for basic taint tracking (no heap sensitivity).
  ///
  /// Use this for simple intra-procedural taint analysis.
  static InMemoryDatalogEngine create() {
    final engine = InMemoryDatalogEngine();

    // Taint initialization and propagation
    engine.addRule(TaintSourceRule());
    engine.addRule(TaintPropagationRule());
    engine.addRule(TaintViolationRule());

    return engine;
  }

  /// Creates an engine with full points-to-based taint tracking.
  ///
  /// Includes heap-sensitive taint propagation through field accesses.
  /// Requires points-to facts (VarPointsTo) for field tracking.
  static InMemoryDatalogEngine createWithPointsTo() {
    final engine = InMemoryDatalogEngine();

    // Points-to analysis (stratum 0)
    engine.addRule(AllocRule());
    engine.addRule(CopyRule());
    engine.addRule(StoreFieldRule());
    engine.addRule(LoadFieldRule());

    // Taint tracking (stratum 0, runs in parallel with points-to)
    engine.addRule(TaintSourceRule());
    engine.addRule(TaintPropagationRule());
    engine.addRule(TaintStoreFieldRule());
    engine.addRule(TaintLoadFieldRule());
    engine.addRule(TaintViolationRule());

    return engine;
  }
}
