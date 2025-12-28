import '../../frontend/ir_generator.dart';
import '../../ir/cfg/control_flow_graph.dart';
import 'datalog_engine.dart';
import 'fact_extractor.dart';

/// High-level API for points-to analysis results.
///
/// Provides convenient methods to query analysis results
/// after running the Datalog engine.
class PointsToAnalysis {
  final InMemoryDatalogEngine _engine;
  final FactExtractor _extractor;

  /// Maps variable IDs back to names for debugging.
  final Map<int, String> _varNames = {};

  PointsToAnalysis._(this._engine, this._extractor);

  /// Creates and runs points-to analysis on a function IR.
  static PointsToAnalysis analyzeFunction(FunctionIr ir) {
    final extractor = FactExtractor();
    final facts = extractor.extractFromFunction(ir);

    final engine = PointsToEngineFactory.createWithImmutability();
    engine.loadFacts(facts);
    engine.run();

    final analysis = PointsToAnalysis._(engine, extractor);
    analysis._buildVarNameMap(extractor);
    return analysis;
  }

  /// Creates and runs points-to analysis on a file IR.
  static PointsToAnalysis analyzeFile(FileIr ir) {
    final extractor = FactExtractor();
    final facts = extractor.extractFromFile(ir);

    final engine = PointsToEngineFactory.createWithImmutability();
    engine.loadFacts(facts);
    engine.run();

    final analysis = PointsToAnalysis._(engine, extractor);
    analysis._buildVarNameMap(extractor);
    return analysis;
  }

  /// Creates and runs analysis on a CFG directly.
  static PointsToAnalysis analyzeCfg(ControlFlowGraph cfg) {
    final extractor = FactExtractor();
    final facts = extractor.extractFromCfg(cfg);

    final engine = PointsToEngineFactory.createWithImmutability();
    engine.loadFacts(facts);
    engine.run();

    final analysis = PointsToAnalysis._(engine, extractor);
    analysis._buildVarNameMap(extractor);
    return analysis;
  }

  void _buildVarNameMap(FactExtractor extractor) {
    // Invert the var ID map for debugging
    extractor.varIds.forEach((name, id) {
      _varNames[id] = name;
    });
  }

  // ============================================================
  // Points-To Queries
  // ============================================================

  /// Gets all heap objects that a variable may point to.
  Set<String> getPointsTo(int varId) {
    final results = _engine.query('VarPointsTo');
    return results
        .where((tuple) => tuple[0] == varId)
        .map((tuple) => tuple[1] as String)
        .toSet();
  }

  /// Gets all heap objects that a variable (by name) may point to.
  Set<String> getPointsToByName(String varName) {
    final varId = _extractor.varIds[varName];
    if (varId == null) return {};
    return getPointsTo(varId);
  }

  /// Gets all variables that may point to a specific heap object.
  Set<int> getPointedBy(String heapId) {
    final results = _engine.query('VarPointsTo');
    return results
        .where((tuple) => tuple[1] == heapId)
        .map((tuple) => tuple[0] as int)
        .toSet();
  }

  /// Gets all VarPointsTo relationships.
  Map<int, Set<String>> getAllPointsTo() {
    final results = _engine.query('VarPointsTo');
    final map = <int, Set<String>>{};

    for (final tuple in results) {
      final varId = tuple[0] as int;
      final heapId = tuple[1] as String;
      map.putIfAbsent(varId, () => {}).add(heapId);
    }

    return map;
  }

  // ============================================================
  // Heap Points-To Queries
  // ============================================================

  /// Gets what a heap object's field points to.
  Set<String> getFieldPointsTo(String heapId, String fieldName) {
    final results = _engine.query('HeapPointsTo');
    return results
        .where((tuple) => tuple[0] == heapId && tuple[1] == fieldName)
        .map((tuple) => tuple[2] as String)
        .toSet();
  }

  /// Gets all fields of a heap object and what they point to.
  Map<String, Set<String>> getAllFieldsPointsTo(String heapId) {
    final results = _engine.query('HeapPointsTo');
    final map = <String, Set<String>>{};

    for (final tuple in results) {
      if (tuple[0] == heapId) {
        final field = tuple[1] as String;
        final target = tuple[2] as String;
        map.putIfAbsent(field, () => {}).add(target);
      }
    }

    return map;
  }

  // ============================================================
  // Reachability Queries
  // ============================================================

  /// Gets all reachable blocks.
  Set<int> getReachableBlocks() {
    final results = _engine.query('Reachable');
    return results.map((tuple) => tuple[0] as int).toSet();
  }

  /// Checks if a specific block is reachable.
  bool isBlockReachable(int blockId) {
    return getReachableBlocks().contains(blockId);
  }

  // ============================================================
  // Mutability Queries
  // ============================================================

  /// Gets all mutable heap objects.
  Set<String> getMutableObjects() {
    final results = _engine.query('Mutable');
    return results.map((tuple) => tuple[0] as String).toSet();
  }

  /// Gets all deeply immutable heap objects.
  Set<String> getDeepImmutableObjects() {
    final results = _engine.query('DeepImmutable');
    return results.map((tuple) => tuple[0] as String).toSet();
  }

  /// Checks if a heap object is mutable.
  bool isMutable(String heapId) {
    return getMutableObjects().contains(heapId);
  }

  /// Checks if a heap object is deeply immutable.
  bool isDeepImmutable(String heapId) {
    return getDeepImmutableObjects().contains(heapId);
  }

  // ============================================================
  // Call Graph Queries
  // ============================================================

  /// Gets the call graph as a map from call sites to methods.
  Map<int, Set<String>> getCallGraph() {
    final results = _engine.query('CallGraph');
    final map = <int, Set<String>>{};

    for (final tuple in results) {
      final site = tuple[0] as int;
      final method = tuple[1] as String;
      map.putIfAbsent(site, () => {}).add(method);
    }

    return map;
  }

  /// Gets methods called at a specific call site.
  Set<String> getCalledMethods(int callSite) {
    return getCallGraph()[callSite] ?? {};
  }

  // ============================================================
  // Debugging & Reporting
  // ============================================================

  /// Gets a human-readable summary of the analysis.
  String getSummary() {
    final buffer = StringBuffer();

    buffer.writeln('=== Points-To Analysis Summary ===');
    buffer.writeln();

    // Variable points-to
    buffer.writeln('Variable Points-To:');
    final pointsTo = getAllPointsTo();
    for (final entry in pointsTo.entries) {
      final varName = _varNames[entry.key] ?? 'var${entry.key}';
      buffer.writeln('  $varName -> ${entry.value.join(', ')}');
    }
    buffer.writeln();

    // Reachable blocks
    buffer.writeln('Reachable Blocks: ${getReachableBlocks().toList()..sort()}');
    buffer.writeln();

    // Mutability
    buffer.writeln('Mutable Objects: ${getMutableObjects()}');
    buffer.writeln('Immutable Objects: ${getDeepImmutableObjects()}');
    buffer.writeln();

    // Call graph
    buffer.writeln('Call Graph:');
    final callGraph = getCallGraph();
    for (final entry in callGraph.entries) {
      buffer.writeln('  site ${entry.key} -> ${entry.value.join(', ')}');
    }

    return buffer.toString();
  }

  /// Dumps all facts for debugging.
  void dumpFacts() {
    print('=== Input Facts ===');
    for (final relation in ['Assign', 'Alloc', 'Flow', 'LoadField', 'StoreField', 'Call']) {
      final facts = _engine.query(relation);
      if (facts.isNotEmpty) {
        print('$relation:');
        for (final fact in facts) {
          print('  $fact');
        }
      }
    }

    print('\n=== Derived Facts ===');
    for (final relation in [
      'VarPointsTo',
      'HeapPointsTo',
      'Reachable',
      'Mutable',
      'DeepImmutable',
      'CallGraph'
    ]) {
      final facts = _engine.query(relation);
      if (facts.isNotEmpty) {
        print('$relation:');
        for (final fact in facts) {
          print('  $fact');
        }
      }
    }
  }
}

/// Extension to add analysis capability to FileIr.
extension PointsToAnalysisExtension on FileIr {
  /// Runs points-to analysis on this file.
  PointsToAnalysis runPointsToAnalysis() {
    return PointsToAnalysis.analyzeFile(this);
  }
}

/// Extension to add analysis capability to FunctionIr.
extension FunctionPointsToAnalysisExtension on FunctionIr {
  /// Runs points-to analysis on this function.
  PointsToAnalysis runPointsToAnalysis() {
    return PointsToAnalysis.analyzeFunction(this);
  }
}
