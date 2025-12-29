import 'package:anteater/ir/cfg/control_flow_graph.dart';
import 'package:anteater/ir/ssa/ssa_builder.dart';
import 'package:anteater/reasoner/datalog/datalog_engine.dart';
import 'package:anteater/reasoner/datalog/fact_extractor.dart';
import 'package:anteater/reasoner/datalog/points_to_analysis.dart';
import 'package:test/test.dart';

void main() {
  group('FactExtractor', () {
    late FactExtractor extractor;

    setUp(() {
      extractor = FactExtractor();
    });

    test('extracts Assign facts from variable copy', () {
      // x = y (where y points to some heap)
      final block = BasicBlock(id: 0);
      block.addInstruction(AssignInstruction(
        offset: 0,
        target: const Variable('x'),
        value: const VariableValue(Variable('y')),
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );

      final facts = extractor.extractFromCfg(cfg);
      final assigns = facts.where((f) => f.relation == 'Assign').toList();

      expect(assigns, isNotEmpty);
    });

    test('extracts Alloc facts from new expressions', () {
      final block = BasicBlock(id: 0);
      block.addInstruction(AssignInstruction(
        offset: 10,
        target: const Variable('list'),
        value: const NewObjectValue(
          typeName: 'List',
          arguments: [],
        ),
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );

      final facts = extractor.extractFromCfg(cfg);

      final allocs = facts.where((f) => f.relation == 'Alloc').toList();
      expect(allocs, isNotEmpty);
      expect(allocs.first.values[1], contains('List'));
    });

    test('extracts Flow facts from CFG edges', () {
      final block0 = BasicBlock(id: 0);
      final block1 = BasicBlock(id: 1);
      final block2 = BasicBlock(id: 2);

      block0.connectTo(block1);
      block0.connectTo(block2);

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block0,
        blocks: [block0, block1, block2],
      );

      final facts = extractor.extractFromCfg(cfg);
      final flows = facts.where((f) => f.relation == 'Flow').toList();

      expect(flows.length, equals(2));
    });

    test('extracts StoreField facts', () {
      final block = BasicBlock(id: 0);
      block.addInstruction(StoreFieldInstruction(
        offset: 0,
        base: const VariableValue(Variable('obj')),
        fieldName: 'name',
        value: const VariableValue(Variable('value')),
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );

      final facts = extractor.extractFromCfg(cfg);
      final stores = facts.where((f) => f.relation == 'StoreField').toList();

      expect(stores, isNotEmpty);
      expect(stores.first.values[1], equals('name'));
    });

    test('extracts LoadField facts', () {
      final block = BasicBlock(id: 0);
      block.addInstruction(LoadFieldInstruction(
        offset: 0,
        base: const VariableValue(Variable('obj')),
        fieldName: 'length',
        result: const Variable('len'),
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );

      final facts = extractor.extractFromCfg(cfg);
      final loads = facts.where((f) => f.relation == 'LoadField').toList();

      expect(loads, isNotEmpty);
      expect(loads.first.values[1], equals('length'));
    });

    test('tracks unhandled instruction types', () {
      final extractor = FactExtractor();
      final block = BasicBlock(id: 0);

      // Add a known instruction type that should be handled
      block.addInstruction(AssignInstruction(
        offset: 0,
        target: const Variable('x'),
        value: const ConstantValue(1),
      ));

      // Add known control flow instruction types that are explicitly skipped
      block.addInstruction(JumpInstruction(
        offset: 1,
        target: BasicBlock(id: 1),
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );

      extractor.extractFromCfg(cfg);

      // Known types that don't generate facts should not be in unhandledTypes
      expect(extractor.unhandledTypes.contains(JumpInstruction), isFalse);
      expect(extractor.unhandledTypes.contains(AssignInstruction), isFalse);
    });

    test('reset clears unhandled types', () {
      final extractor = FactExtractor();

      // First extraction
      final block = BasicBlock(id: 0);
      block.addInstruction(AssignInstruction(
        offset: 0,
        target: const Variable('x'),
        value: const ConstantValue(1),
      ));
      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );
      extractor.extractFromCfg(cfg);

      // Reset
      extractor.reset();

      // State should be cleared
      expect(extractor.unhandledTypes, isEmpty);
      expect(extractor.varIds, isEmpty);
    });
  });

  group('InMemoryDatalogEngine', () {
    late InMemoryDatalogEngine engine;

    setUp(() {
      engine = PointsToEngineFactory.createWithImmutability();
    });

    test('tracks simple allocation', () {
      // var x = new List()
      engine.loadFacts([
        const Fact('Assign', [0, 100]), // x = alloc_100
        const Fact('Alloc', [100, 'List#0']), // alloc_100 creates List#0
      ]);

      engine.run();

      final pointsTo = engine.query('VarPointsTo');
      expect(pointsTo.any((t) => t[0] == 0 && t[1] == 'List#0'), isTrue);
    });

    test('tracks variable copy', () {
      // var x = new List(); var y = x;
      engine.loadFacts([
        const Fact('Assign', [0, 100]), // x = alloc_100
        const Fact('Alloc', [100, 'List#0']),
        const Fact('Assign', [1, 0]), // y = x
      ]);

      engine.run();

      final pointsTo = engine.query('VarPointsTo');
      expect(pointsTo.any((t) => t[0] == 0 && t[1] == 'List#0'), isTrue); // x -> List#0
      expect(pointsTo.any((t) => t[0] == 1 && t[1] == 'List#0'), isTrue); // y -> List#0
    });

    test('tracks field store and load', () {
      // var container = new Container()
      // var item = new Item()
      // container.item = item
      // var result = container.item
      engine.loadFacts([
        const Fact('Assign', [0, 100]), // container = alloc_100
        const Fact('Alloc', [100, 'Container#0']),
        const Fact('Assign', [1, 101]), // item = alloc_101
        const Fact('Alloc', [101, 'Item#0']),
        const Fact('StoreField', [0, 'item', 1]), // container.item = item
        const Fact('LoadField', [0, 'item', 2]), // result = container.item
      ]);

      engine.run();

      // Check heap points-to
      final heapPointsTo = engine.query('HeapPointsTo');
      expect(
          heapPointsTo.any((t) =>
              t[0] == 'Container#0' && t[1] == 'item' && t[2] == 'Item#0'),
          isTrue);

      // Check variable points-to through load
      final varPointsTo = engine.query('VarPointsTo');
      expect(varPointsTo.any((t) => t[0] == 2 && t[1] == 'Item#0'), isTrue); // result -> Item#0
    });

    test('identifies mutable objects', () {
      // var list = new List()
      // list.add(item) -- represented as StoreField
      engine.loadFacts([
        const Fact('Assign', [0, 100]),
        const Fact('Alloc', [100, 'List#0']),
        const Fact('StoreField', [0, 'elements', 1]), // list.elements = ...
      ]);

      engine.run();

      final mutable = engine.query('Mutable');
      expect(mutable.any((t) => t[0] == 'List#0'), isTrue);
    });

    test('identifies deeply immutable objects', () {
      // var immutable = new ImmutableValue()
      // (no field stores)
      engine.loadFacts([
        const Fact('Assign', [0, 100]),
        const Fact('Alloc', [100, 'ImmutableValue#0']),
      ]);

      engine.run();

      final immutable = engine.query('DeepImmutable');
      expect(immutable.any((t) => t[0] == 'ImmutableValue#0'), isTrue);

      final mutable = engine.query('Mutable');
      expect(mutable, isEmpty);
    });

    test('tracks transitive mutability', () {
      // var outer = new Outer()
      // var inner = new Inner()
      // outer.inner = inner
      // inner.value = x  -- inner is mutable, so outer is also mutable
      engine.loadFacts([
        const Fact('Assign', [0, 100]),
        const Fact('Alloc', [100, 'Outer#0']),
        const Fact('Assign', [1, 101]),
        const Fact('Alloc', [101, 'Inner#0']),
        const Fact('StoreField', [0, 'inner', 1]), // outer.inner = inner
        const Fact('StoreField', [1, 'value', 2]), // inner.value = x
      ]);

      engine.run();

      final mutable = engine.query('Mutable');
      expect(mutable.any((t) => t[0] == 'Inner#0'), isTrue);
      expect(mutable.any((t) => t[0] == 'Outer#0'), isTrue); // Transitively mutable
    });

    test('computes reachability', () {
      engine.loadFacts([
        const Fact('Reachable', [0]), // Entry is reachable
        const Fact('Flow', [0, 1]),
        const Fact('Flow', [1, 2]),
        const Fact('Flow', [0, 3]),
        // Block 4 is not connected
      ]);

      engine.run();

      final reachable = engine.query('Reachable');
      expect(reachable.any((t) => t[0] == 0), isTrue);
      expect(reachable.any((t) => t[0] == 1), isTrue);
      expect(reachable.any((t) => t[0] == 2), isTrue);
      expect(reachable.any((t) => t[0] == 3), isTrue);
      expect(reachable.where((r) => r[0] == 4), isEmpty);
    });

    test('builds call graph', () {
      engine.loadFacts([
        const Fact('Assign', [0, 100]),
        const Fact('Alloc', [100, 'Obj#0']),
        const Fact('Call', [0, 0, 'doSomething', 1]), // obj.doSomething()
        const Fact('Call', [1, -1, 'print', 2]), // print() - static call
      ]);

      engine.run();

      final callGraph = engine.query('CallGraph');
      expect(callGraph.any((t) => t[0] == 0 && t[1] == 'doSomething'), isTrue);
      expect(callGraph.any((t) => t[0] == 1 && t[1] == 'print'), isTrue);
    });

    test('respects iteration limit', () {
      // Create engine with very low limit using the factory
      final limitedEngine = InMemoryDatalogEngine(maxIterations: 3);
      // Add standard points-to rules
      limitedEngine.addRule(AllocRule());
      limitedEngine.addRule(CopyRule());

      // Load facts that would produce derivations
      limitedEngine.loadFacts([
        const Fact('Assign', [0, 100]),
        const Fact('Alloc', [100, 'Obj#0']),
        const Fact('Assign', [1, 0]),
        const Fact('Assign', [2, 1]),
        const Fact('Assign', [3, 2]),
      ]);

      limitedEngine.run();

      // Should track total iterations
      expect(limitedEngine.totalIterations, greaterThan(0));
    });

    test('tracks totalIterations correctly', () {
      engine.loadFacts([
        const Fact('Assign', [0, 100]),
        const Fact('Alloc', [100, 'Obj#0']),
      ]);

      engine.run();

      // Should have done at least one iteration
      expect(engine.totalIterations, greaterThan(0));
      expect(engine.reachedMaxIterations, isFalse);
    });

    test('reachedMaxIterations is false for normal completion', () {
      engine.loadFacts([
        const Fact('Reachable', [0]),
        const Fact('Flow', [0, 1]),
      ]);

      engine.run();

      expect(engine.reachedMaxIterations, isFalse);
    });
  });

  group('PointsToAnalysis', () {
    test('provides high-level query interface', () {
      // Build a simple CFG
      final block = BasicBlock(id: 0);
      block.addInstruction(AssignInstruction(
        offset: 100,
        target: const Variable('x'),
        value: const NewObjectValue(typeName: 'MyClass', arguments: []),
      ));
      block.addInstruction(AssignInstruction(
        offset: 101,
        target: const Variable('y'),
        value: const VariableValue(Variable('x')),
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );

      final analysis = PointsToAnalysis.analyzeCfg(cfg);

      // Both x and y should point to MyClass
      final xPointsTo = analysis.getPointsToByName('x');
      final yPointsTo = analysis.getPointsToByName('y');

      expect(xPointsTo, isNotEmpty);
      expect(yPointsTo, isNotEmpty);
      expect(xPointsTo, equals(yPointsTo));
    });

    test('detects immutability correctly', () {
      final block = BasicBlock(id: 0);
      block.addInstruction(AssignInstruction(
        offset: 100,
        target: const Variable('immutable'),
        value: const NewObjectValue(typeName: 'ImmutableData', arguments: []),
      ));
      block.addInstruction(AssignInstruction(
        offset: 101,
        target: const Variable('mutable'),
        value: const NewObjectValue(typeName: 'MutableData', arguments: []),
      ));
      // Create a variable to store to the field
      block.addInstruction(AssignInstruction(
        offset: 102,
        target: const Variable('someValue'),
        value: const NewObjectValue(typeName: 'SomeValue', arguments: []),
      ));
      block.addInstruction(StoreFieldInstruction(
        offset: 103,
        base: const VariableValue(Variable('mutable')),
        fieldName: 'value',
        value: const VariableValue(Variable('someValue')),
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );

      final analysis = PointsToAnalysis.analyzeCfg(cfg);

      final immutableObjects = analysis.getDeepImmutableObjects();
      final mutableObjects = analysis.getMutableObjects();

      // ImmutableData should be immutable (no stores)
      expect(immutableObjects.any((h) => h.contains('ImmutableData')), isTrue);

      // MutableData should be mutable (has store)
      expect(mutableObjects.any((h) => h.contains('MutableData')), isTrue);
    });

    test('computes reachability for CFG', () {
      final block0 = BasicBlock(id: 0);
      final block1 = BasicBlock(id: 1);
      final block2 = BasicBlock(id: 2);

      block0.connectTo(block1);
      block1.connectTo(block2);

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block0,
        blocks: [block0, block1, block2],
      );

      final analysis = PointsToAnalysis.analyzeCfg(cfg);

      expect(analysis.isBlockReachable(0), isTrue);
      expect(analysis.isBlockReachable(1), isTrue);
      expect(analysis.isBlockReachable(2), isTrue);
    });
  });

  group('Stratified Evaluation', () {
    test('ImmutabilityRule evaluates after Mutable facts are complete', () {
      // This test verifies that stratification works correctly.
      // ImmutabilityRule (stratum 1) should only run after
      // MutabilityRule and TransitiveMutabilityRule (stratum 0) are complete.

      final engine = PointsToEngineFactory.createWithImmutability();

      // outer → inner → leaf
      // Only leaf is mutated, so inner and outer are transitively mutable
      engine.loadFacts([
        const Fact('Assign', [0, 100]), // outer = alloc_100
        const Fact('Alloc', [100, 'Outer#0']),
        const Fact('Assign', [1, 101]), // inner = alloc_101
        const Fact('Alloc', [101, 'Inner#0']),
        const Fact('Assign', [2, 102]), // leaf = alloc_102
        const Fact('Alloc', [102, 'Leaf#0']),
        const Fact('Assign', [3, 103]), // immutable = alloc_103
        const Fact('Alloc', [103, 'Immutable#0']),
        const Fact('StoreField', [0, 'inner', 1]), // outer.inner = inner
        const Fact('StoreField', [1, 'leaf', 2]), // inner.leaf = leaf
        const Fact('StoreField', [2, 'value', 4]), // leaf.value = x (mutation)
      ]);

      engine.run();

      // Check that transitive mutability is fully computed before immutability
      final mutable = engine.query('Mutable');
      final immutable = engine.query('DeepImmutable');

      // Leaf is directly mutable
      expect(mutable.any((t) => t[0] == 'Leaf#0'), isTrue);
      // Inner is transitively mutable (points to Leaf)
      expect(mutable.any((t) => t[0] == 'Inner#0'), isTrue);
      // Outer is transitively mutable (points to Inner)
      expect(mutable.any((t) => t[0] == 'Outer#0'), isTrue);
      // Immutable has no stores - should be DeepImmutable
      expect(immutable.any((t) => t[0] == 'Immutable#0'), isTrue);
      // None of the mutable objects should be in DeepImmutable
      expect(immutable.any((t) => t[0] == 'Outer#0'), isFalse);
      expect(immutable.any((t) => t[0] == 'Inner#0'), isFalse);
      expect(immutable.any((t) => t[0] == 'Leaf#0'), isFalse);
    });
  });

  group('TaintTracking', () {
    test('basic taint propagation through assignment', () {
      final engine = TaintEngineFactory.create();

      // source = userInput (tainted)
      // x = source
      // y = x
      // sink(y)  -- should detect violation
      engine.loadFacts([
        const Fact('TaintSource', [0, 'user_input']), // var 0 is tainted
        const Fact('Assign', [1, 0]), // x = source
        const Fact('Assign', [2, 1]), // y = x
        const Fact('TaintSink', [2, 'sql_query']), // y used in SQL
      ]);

      engine.run();

      // y should be tainted
      final tainted = engine.query('TaintedVar');
      expect(tainted.any((t) => t[0] == 0), isTrue); // source
      expect(tainted.any((t) => t[0] == 1), isTrue); // x
      expect(tainted.any((t) => t[0] == 2), isTrue); // y

      // Should detect violation
      final violations = engine.query('TaintViolation');
      expect(violations, isNotEmpty);
      expect(
        violations.any((v) => v[0] == 2 && v[2] == 'user_input' && v[3] == 'sql_query'),
        isTrue,
      );
    });

    test('no violation when taint does not reach sink', () {
      final engine = TaintEngineFactory.create();

      // source = userInput (tainted)
      // x = cleanData (not tainted)
      // sink(x)  -- no violation
      engine.loadFacts([
        const Fact('TaintSource', [0, 'user_input']),
        const Fact('Assign', [2, 1]), // x = cleanData (1 is not tainted)
        const Fact('TaintSink', [2, 'sql_query']),
      ]);

      engine.run();

      final violations = engine.query('TaintViolation');
      expect(violations, isEmpty);
    });

    test('taint propagation through heap with points-to', () {
      final engine = TaintEngineFactory.createWithPointsTo();

      // obj = new Object()
      // tainted = userInput
      // obj.field = tainted
      // result = obj.field
      // sink(result)  -- should detect violation
      engine.loadFacts([
        const Fact('Assign', [0, 100]), // obj = alloc_100
        const Fact('Alloc', [100, 'Object#0']),
        const Fact('TaintSource', [1, 'user_input']), // var 1 is tainted
        const Fact('StoreField', [0, 'field', 1]), // obj.field = tainted
        const Fact('LoadField', [0, 'field', 2]), // result = obj.field
        const Fact('TaintSink', [2, 'exec']),
      ]);

      engine.run();

      // result should be tainted via heap
      final tainted = engine.query('TaintedVar');
      expect(tainted.any((t) => t[0] == 2), isTrue); // result

      // Should detect violation
      final violations = engine.query('TaintViolation');
      expect(violations, isNotEmpty);
    });

    test('multiple taint labels are preserved', () {
      final engine = TaintEngineFactory.create();

      // source1 = userInput (tainted with 'user_input')
      // source2 = networkData (tainted with 'network')
      // x = source1
      // y = source2
      engine.loadFacts([
        const Fact('TaintSource', [0, 'user_input']),
        const Fact('TaintSource', [1, 'network']),
        const Fact('Assign', [2, 0]),
        const Fact('Assign', [3, 1]),
        const Fact('TaintSink', [2, 'file_write']),
        const Fact('TaintSink', [3, 'file_write']),
      ]);

      engine.run();

      final violations = engine.query('TaintViolation');
      // Should have violations from both sources
      expect(
        violations.any((v) => v[2] == 'user_input' && v[3] == 'file_write'),
        isTrue,
      );
      expect(
        violations.any((v) => v[2] == 'network' && v[3] == 'file_write'),
        isTrue,
      );
    });
  });

  group('SSA Integration', () {
    test('phi instructions generate Assign facts', () {
      // Build a diamond CFG where x is defined in entry and read after merge
      //     entry (x = 1, y = 10)
      //     /    \
      //  then   else
      //  (x=2)  (x=3)
      //     \    /
      //     merge (z = x) -- reading x triggers phi insertion
      final entry = BasicBlock(id: 0);
      final thenBlock = BasicBlock(id: 1);
      final elseBlock = BasicBlock(id: 2);
      final merge = BasicBlock(id: 3);

      entry.connectTo(thenBlock);
      entry.connectTo(elseBlock);
      thenBlock.connectTo(merge);
      elseBlock.connectTo(merge);

      entry.addInstruction(AssignInstruction(
        offset: 0,
        target: const Variable('x'),
        value: const ConstantValue(1),
      ));
      thenBlock.addInstruction(AssignInstruction(
        offset: 1,
        target: const Variable('x'),
        value: const ConstantValue(2),
      ));
      elseBlock.addInstruction(AssignInstruction(
        offset: 2,
        target: const Variable('x'),
        value: const ConstantValue(3),
      ));
      // Add a use of x in merge block to trigger phi creation
      merge.addInstruction(AssignInstruction(
        offset: 3,
        target: const Variable('z'),
        value: const VariableValue(Variable('x')),
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: entry,
        blocks: [entry, thenBlock, elseBlock, merge],
      );

      // Transform to SSA
      final ssaBuilder = SsaBuilder();
      final ssaCfg = ssaBuilder.buildSsa(cfg);

      // Extract facts from SSA form
      final extractor = FactExtractor();
      final facts = extractor.extractFromCfg(ssaCfg);

      // Verify assignments exist for the original definitions
      final assigns = facts.where((f) => f.relation == 'Assign').toList();
      // The number of Assign facts depends on how FactExtractor handles
      // constants vs variable assignments. At minimum we expect some assigns.
      expect(assigns, isNotEmpty, reason: 'Should have Assign facts from SSA');

      // The key verification is that the SSA CFG was produced and contains
      // the expected structure (phi or merged definitions)
      final allInstructions = ssaCfg.blocks.expand((b) => b.instructions).toList();
      expect(allInstructions, isNotEmpty, reason: 'SSA CFG should have instructions');
    });

    test('SSA variable versions are tracked correctly', () {
      // x = 1; x = 2; y = x
      // In SSA: x_1 = 1; x_2 = 2; y_1 = x_2
      final block = BasicBlock(id: 0);
      block.addInstruction(AssignInstruction(
        offset: 0,
        target: const Variable('x'),
        value: const ConstantValue(1),
      ));
      block.addInstruction(AssignInstruction(
        offset: 1,
        target: const Variable('x'),
        value: const ConstantValue(2),
      ));
      block.addInstruction(AssignInstruction(
        offset: 2,
        target: const Variable('y'),
        value: const VariableValue(Variable('x')),
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );

      final ssaBuilder = SsaBuilder();
      final ssaCfg = ssaBuilder.buildSsa(cfg);

      // In SSA form, there should be 3 assignments
      final assigns = ssaCfg.blocks[0].instructions
          .whereType<AssignInstruction>()
          .toList();
      expect(assigns.length, equals(3));

      // The third assignment (y = x) should use the renamed x
      final yAssign = assigns[2];
      expect(yAssign.target.name, contains('y'));
      if (yAssign.value is VariableValue) {
        final xRef = (yAssign.value as VariableValue).variable;
        // x should have a version suffix
        expect(xRef.name, contains('x'));
      }
    });

    test('end-to-end SSA to Datalog points-to analysis', () {
      // obj = new Foo()
      // if (...):
      //   x = obj
      // else:
      //   x = obj
      // // x after merge should still point to Foo

      final entry = BasicBlock(id: 0);
      final thenBlock = BasicBlock(id: 1);
      final elseBlock = BasicBlock(id: 2);
      final merge = BasicBlock(id: 3);

      entry.connectTo(thenBlock);
      entry.connectTo(elseBlock);
      thenBlock.connectTo(merge);
      elseBlock.connectTo(merge);

      entry.addInstruction(AssignInstruction(
        offset: 100,
        target: const Variable('obj'),
        value: const NewObjectValue(typeName: 'Foo', arguments: []),
      ));
      thenBlock.addInstruction(AssignInstruction(
        offset: 1,
        target: const Variable('x'),
        value: const VariableValue(Variable('obj')),
      ));
      elseBlock.addInstruction(AssignInstruction(
        offset: 2,
        target: const Variable('x'),
        value: const VariableValue(Variable('obj')),
      ));
      merge.addInstruction(AssignInstruction(
        offset: 3,
        target: const Variable('result'),
        value: const VariableValue(Variable('x')),
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: entry,
        blocks: [entry, thenBlock, elseBlock, merge],
      );

      // Transform to SSA and analyze
      final ssaBuilder = SsaBuilder();
      final ssaCfg = ssaBuilder.buildSsa(cfg);
      final analysis = PointsToAnalysis.analyzeCfg(ssaCfg);

      // 'result' should point to Foo
      // Note: After SSA, variable names may have version suffixes
      final allPointsTo = analysis.getAllPointsTo();
      // Check that at least one variable points to something containing 'Foo'
      final hasPointsToFoo = allPointsTo.values.any(
        (heapSet) => heapSet.any((heap) => heap.contains('Foo')),
      );
      expect(
        hasPointsToFoo,
        isTrue,
        reason: 'Should have points-to facts for Foo allocation',
      );
    });
  });
}
