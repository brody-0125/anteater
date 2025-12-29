import 'package:anteater/ir/cfg/control_flow_graph.dart';
import 'package:anteater/reasoner/abstract/abstract_domain.dart';
import 'package:anteater/reasoner/abstract/abstract_interpreter.dart';
import 'package:anteater/reasoner/abstract/bounds_checker.dart';
import 'package:anteater/reasoner/abstract/null_verifier.dart';
import 'package:test/test.dart';

void main() {
  group('IntervalDomain', () {
    test('constant creates point interval', () {
      final interval = IntervalDomain.constant(5);
      expect(interval.min, equals(5));
      expect(interval.max, equals(5));
    });

    test('join computes least upper bound', () {
      const a = IntervalDomain(0, 5);
      const b = IntervalDomain(3, 10);
      final result = a.join(b);

      expect(result.min, equals(0));
      expect(result.max, equals(10));
    });

    test('meet computes greatest lower bound', () {
      const a = IntervalDomain(0, 5);
      const b = IntervalDomain(3, 10);
      final result = a.meet(b);

      expect(result.min, equals(3));
      expect(result.max, equals(5));
    });

    test('meet of disjoint intervals is bottom', () {
      const a = IntervalDomain(0, 5);
      const b = IntervalDomain(10, 15);
      final result = a.meet(b);

      expect(result.isBottom, isTrue);
    });

    test('widening jumps to infinity on growth', () {
      const a = IntervalDomain(0, 5);
      const b = IntervalDomain(0, 10);
      final result = a.widen(b);

      expect(result.min, equals(0));
      expect(result.max, isNull); // +∞
    });

    test('narrowing restores finite bound', () {
      const a = IntervalDomain(0, null); // [0, +∞)
      const b = IntervalDomain(0, 100);
      final result = a.narrow(b);

      expect(result.min, equals(0));
      expect(result.max, equals(100));
    });

    test('add computes interval sum', () {
      const a = IntervalDomain(1, 5);
      const b = IntervalDomain(10, 20);
      final result = a.add(b);

      expect(result.min, equals(11));
      expect(result.max, equals(25));
    });

    test('subtract computes interval difference', () {
      const a = IntervalDomain(10, 20);
      const b = IntervalDomain(1, 5);
      final result = a.subtract(b);

      expect(result.min, equals(5)); // 10 - 5
      expect(result.max, equals(19)); // 20 - 1
    });

    test('isValidArrayIndex validates bounds', () {
      const valid = IntervalDomain(0, 4);
      const invalid = IntervalDomain(-1, 10);
      const outOfBounds = IntervalDomain(5, 10);

      expect(valid.isValidArrayIndex(5), isTrue);
      expect(invalid.isValidArrayIndex(5), isFalse);
      expect(outOfBounds.isValidArrayIndex(5), isFalse);
    });

    test('divide computes interval quotient', () {
      const a = IntervalDomain(10, 20);
      const b = IntervalDomain(2, 5);
      final result = a.divide(b);

      // [10,20] / [2,5] = [10/5, 20/2] = [2, 10]
      expect(result.min, equals(2));
      expect(result.max, equals(10));
    });

    test('divide by zero interval returns top', () {
      const a = IntervalDomain(10, 20);
      const zeroContaining = IntervalDomain(-1, 1);
      final result = a.divide(zeroContaining);

      expect(result.isTop, isTrue);
    });

    test('divide point intervals', () {
      final a = IntervalDomain.constant(20);
      final b = IntervalDomain.constant(4);
      final result = a.divide(b);

      expect(result.min, equals(5));
      expect(result.max, equals(5));
    });

    test('modulo computes interval modulo', () {
      const a = IntervalDomain(10, 20);
      const b = IntervalDomain(3, 3);
      final result = a.modulo(b);

      // % 3 results in [0, 2]
      expect(result.min, equals(0));
      expect(result.max, equals(2));
    });

    test('modulo by zero interval returns top', () {
      const a = IntervalDomain(10, 20);
      const zeroContaining = IntervalDomain(-1, 1);
      final result = a.modulo(zeroContaining);

      expect(result.isTop, isTrue);
    });

    test('containsValue checks interval membership', () {
      const interval = IntervalDomain(5, 10);

      expect(interval.containsValue(5), isTrue);
      expect(interval.containsValue(7), isTrue);
      expect(interval.containsValue(10), isTrue);
      expect(interval.containsValue(4), isFalse);
      expect(interval.containsValue(11), isFalse);
    });

    test('containsValue handles infinite bounds', () {
      const unboundedAbove = IntervalDomain(0, null);
      const unboundedBelow = IntervalDomain(null, 10);
      const topValue = IntervalDomain.topValue;

      expect(unboundedAbove.containsValue(1000000), isTrue);
      expect(unboundedAbove.containsValue(-1), isFalse);
      expect(unboundedBelow.containsValue(-1000000), isTrue);
      expect(unboundedBelow.containsValue(11), isFalse);
      expect(topValue.containsValue(0), isTrue);
    });
  });

  group('NullabilityDomain', () {
    test('join of different non-bottom states is top', () {
      const a = NullabilityDomain.nullValue;
      const b = NullabilityDomain.nonNullValue;
      final result = a.join(b);

      expect(result.isTop, isTrue);
    });

    test('meet of null and nonNull is bottom', () {
      const a = NullabilityDomain.nullValue;
      const b = NullabilityDomain.nonNullValue;
      final result = a.meet(b);

      expect(result.isBottom, isTrue);
    });

    test('applyNonNullConstraint on maybeNull gives nonNull', () {
      const maybeNull = NullabilityDomain.topValue;
      final result = maybeNull.applyNonNullConstraint();

      expect(result.isDefinitelyNonNull, isTrue);
    });

    test('applyNonNullConstraint on definitelyNull gives bottom', () {
      const definitelyNull = NullabilityDomain.nullValue;
      final result = definitelyNull.applyNonNullConstraint();

      expect(result.isBottom, isTrue);
    });
  });

  group('AbstractState', () {
    test('join combines variable states', () {
      final a = AbstractState<IntervalDomain>(IntervalDomain.topValue);
      a['x'] = const IntervalDomain(0, 10);
      a['y'] = const IntervalDomain(5, 15);

      final b = AbstractState<IntervalDomain>(IntervalDomain.topValue);
      b['x'] = const IntervalDomain(5, 20);
      b['z'] = const IntervalDomain(0, 5);

      final result = a.join(b);

      // x is in both: [0,10] join [5,20] = [0,20]
      expect(result['x'].min, equals(0));
      expect(result['x'].max, equals(20));

      // y is only in a: [5,15] join bottom = [5,15]
      // (Missing variables are treated as BOTTOM for correct worklist behavior)
      expect(result['y'].min, equals(5));
      expect(result['y'].max, equals(15));

      // z is only in b: bottom join [0,5] = [0,5]
      expect(result['z'].min, equals(0));
      expect(result['z'].max, equals(5));
    });

    test('join combines overlapping variables', () {
      final a = AbstractState<IntervalDomain>(IntervalDomain.topValue);
      a['x'] = const IntervalDomain(0, 10);
      a['y'] = const IntervalDomain(5, 15);

      final b = AbstractState<IntervalDomain>(IntervalDomain.topValue);
      b['x'] = const IntervalDomain(5, 20);
      b['y'] = const IntervalDomain(10, 25);

      final result = a.join(b);

      // x: [0,10] join [5,20] = [0,20]
      expect(result['x'].min, equals(0));
      expect(result['x'].max, equals(20));

      // y: [5,15] join [10,25] = [5,25]
      expect(result['y'].min, equals(5));
      expect(result['y'].max, equals(25));
    });
  });

  group('AbstractInterpreter', () {
    test('analyzes simple assignment', () {
      final block = BasicBlock(id: 0);
      block.addInstruction(AssignInstruction(
        offset: 0,
        target: const Variable('x'),
        value: const ConstantValue(5),
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );

      final analyzer = IntervalAnalyzer();
      final result = analyzer.analyze(cfg);

      final xInterval = result.getValueAtExit(0, 'x');
      expect(xInterval?.min, equals(5));
      expect(xInterval?.max, equals(5));
    });

    test('analyzes binary operations', () {
      final block = BasicBlock(id: 0);
      block.addInstruction(AssignInstruction(
        offset: 0,
        target: const Variable('x'),
        value: const ConstantValue(5),
      ));
      block.addInstruction(AssignInstruction(
        offset: 1,
        target: const Variable('y'),
        value: const ConstantValue(3),
      ));
      block.addInstruction(AssignInstruction(
        offset: 2,
        target: const Variable('z'),
        value: const BinaryOpValue(
          '+',
          VariableValue(Variable('x')),
          VariableValue(Variable('y')),
        ),
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );

      final analyzer = IntervalAnalyzer();
      final result = analyzer.analyze(cfg);

      final zInterval = result.getValueAtExit(0, 'z');
      expect(zInterval?.min, equals(8));
      expect(zInterval?.max, equals(8));
    });

    test('analyzes division and modulo operations', () {
      final block = BasicBlock(id: 0);
      block.addInstruction(AssignInstruction(
        offset: 0,
        target: const Variable('x'),
        value: const ConstantValue(20),
      ));
      block.addInstruction(AssignInstruction(
        offset: 1,
        target: const Variable('y'),
        value: const ConstantValue(4),
      ));
      block.addInstruction(AssignInstruction(
        offset: 2,
        target: const Variable('div'),
        value: const BinaryOpValue(
          '~/',
          VariableValue(Variable('x')),
          VariableValue(Variable('y')),
        ),
      ));
      block.addInstruction(AssignInstruction(
        offset: 3,
        target: const Variable('mod'),
        value: const BinaryOpValue(
          '%',
          VariableValue(Variable('x')),
          VariableValue(Variable('y')),
        ),
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );

      final analyzer = IntervalAnalyzer();
      final result = analyzer.analyze(cfg);

      // 20 ~/ 4 = 5
      final divInterval = result.getValueAtExit(0, 'div');
      expect(divInterval?.min, equals(5));
      expect(divInterval?.max, equals(5));

      // 20 % 4 = [0, 3] (modulo bounds)
      final modInterval = result.getValueAtExit(0, 'mod');
      expect(modInterval?.min, equals(0));
      expect(modInterval?.max, equals(3));
    });

    test('handles control flow merge', () {
      // if (cond) { x = 5 } else { x = 10 }
      // At merge point, x should be joined to [5, 10]
      final entry = BasicBlock(id: 0);
      final thenBlock = BasicBlock(id: 1);
      final elseBlock = BasicBlock(id: 2);
      final merge = BasicBlock(id: 3);

      entry.connectTo(thenBlock);
      entry.connectTo(elseBlock);
      thenBlock.connectTo(merge);
      elseBlock.connectTo(merge);

      thenBlock.addInstruction(AssignInstruction(
        offset: 0,
        target: const Variable('x'),
        value: const ConstantValue(5),
      ));

      elseBlock.addInstruction(AssignInstruction(
        offset: 1,
        target: const Variable('x'),
        value: const ConstantValue(10),
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: entry,
        blocks: [entry, thenBlock, elseBlock, merge],
      );

      final analyzer = IntervalAnalyzer();
      final result = analyzer.analyze(cfg);

      // Verify branches have correct values
      final xThen = result.getValueAtExit(1, 'x');
      final xElse = result.getValueAtExit(2, 'x');
      expect(xThen?.min, equals(5));
      expect(xElse?.min, equals(10));

      // At merge entry, x from predecessors should be joined to [5, 10]
      final xMerge = result.getValueAtEntry(3, 'x');
      // Join of [5,5] and [10,10] should give [5,10]
      expect(xMerge?.min, equals(5));
      expect(xMerge?.max, equals(10));
    });

    test('applies widening for loops', () {
      // Loop: i = 0; while (i < 100) { i = i + 1 }
      final entry = BasicBlock(id: 0);
      final header = BasicBlock(id: 1);
      final body = BasicBlock(id: 2);
      final exit = BasicBlock(id: 3);

      entry.connectTo(header);
      header.connectTo(body);
      header.connectTo(exit);
      body.connectTo(header);

      entry.addInstruction(AssignInstruction(
        offset: 0,
        target: const Variable('i'),
        value: const ConstantValue(0),
      ));

      body.addInstruction(AssignInstruction(
        offset: 1,
        target: const Variable('i'),
        value: const BinaryOpValue(
          '+',
          VariableValue(Variable('i')),
          ConstantValue(1),
        ),
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: entry,
        blocks: [entry, header, body, exit],
      );

      // Use low threshold to ensure widening is triggered
      final analyzer = IntervalAnalyzer(wideningThreshold: 1, maxIterations: 20);
      final result = analyzer.analyze(cfg);

      // Widening should have been applied on the loop header
      expect(result.wideningApplied, isTrue);

      // After widening and optional narrowing, bounds at header
      final iInterval = result.getValueAtEntry(header.id, 'i');
      expect(iInterval?.min, equals(0)); // Lower bound stays 0

      // Upper bound may be infinity after widening, or may be recovered
      // by narrowing. Without loop condition semantics, narrowing may
      // not recover precision, so we just verify widening was applied.
      // The max can be null (infinity) or a finite value after narrowing.
      expect(iInterval?.max == null || iInterval!.max! >= 1, isTrue);
    });
  });

  group('BoundsChecker', () {
    test('detects safe array access', () {
      final block = BasicBlock(id: 0);
      block.addInstruction(AssignInstruction(
        offset: 0,
        target: const Variable('i'),
        value: const ConstantValue(2),
      ));
      block.addInstruction(LoadIndexInstruction(
        offset: 1,
        base: const VariableValue(Variable('arr')),
        index: const VariableValue(Variable('i')),
        result: const Variable('elem'),
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );

      final checker = BoundsChecker();
      checker.registerArrayLength('arr', 5);
      final results = checker.checkCfg(cfg);

      expect(results, hasLength(1));
      expect(results.first.isSafe, isTrue);
    });

    test('detects unsafe array access with negative index', () {
      final block = BasicBlock(id: 0);
      block.addInstruction(AssignInstruction(
        offset: 0,
        target: const Variable('i'),
        value: const ConstantValue(-1),
      ));
      block.addInstruction(LoadIndexInstruction(
        offset: 1,
        base: const VariableValue(Variable('arr')),
        index: const VariableValue(Variable('i')),
        result: const Variable('elem'),
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );

      final checker = BoundsChecker();
      checker.registerArrayLength('arr', 5);
      final results = checker.checkCfg(cfg);

      expect(results, hasLength(1));
      expect(results.first.isDefinitelyUnsafe, isTrue);
    });

    test('detects out of bounds access', () {
      final block = BasicBlock(id: 0);
      block.addInstruction(AssignInstruction(
        offset: 0,
        target: const Variable('i'),
        value: const ConstantValue(10),
      ));
      block.addInstruction(LoadIndexInstruction(
        offset: 1,
        base: const VariableValue(Variable('arr')),
        index: const VariableValue(Variable('i')),
        result: const Variable('elem'),
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );

      final checker = BoundsChecker();
      checker.registerArrayLength('arr', 5);
      final results = checker.checkCfg(cfg);

      expect(results, hasLength(1));
      expect(results.first.isDefinitelyUnsafe, isTrue);
    });
  });

  group('NullVerifier', () {
    test('detects safe dereference of non-null', () {
      final block = BasicBlock(id: 0);
      block.addInstruction(AssignInstruction(
        offset: 0,
        target: const Variable('obj'),
        value: const NewObjectValue(typeName: 'MyClass', arguments: []),
      ));
      block.addInstruction(CallInstruction(
        offset: 1,
        receiver: const VariableValue(Variable('obj')),
        methodName: 'doSomething',
        arguments: [],
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );

      final verifier = NullVerifier();
      final results = verifier.verifyCfg(cfg);

      expect(results, hasLength(1));
      expect(results.first.isSafe, isTrue);
    });

    test('detects unsafe dereference of null', () {
      final block = BasicBlock(id: 0);
      block.addInstruction(AssignInstruction(
        offset: 0,
        target: const Variable('obj'),
        value: const ConstantValue(null),
      ));
      block.addInstruction(CallInstruction(
        offset: 1,
        receiver: const VariableValue(Variable('obj')),
        methodName: 'doSomething',
        arguments: [],
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );

      final verifier = NullVerifier();
      final results = verifier.verifyCfg(cfg);

      expect(results, hasLength(1));
      expect(results.first.isDefinitelyNull, isTrue);
    });

    test('detects unknown nullability for maybeNull', () {
      final block = BasicBlock(id: 0);
      block.addInstruction(CallInstruction(
        offset: 0,
        receiver: const VariableValue(Variable('unknownObj')),
        methodName: 'doSomething',
        arguments: [],
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );

      final verifier = NullVerifier();
      final results = verifier.verifyCfg(cfg);

      expect(results, hasLength(1));
      expect(results.first.isUnknown, isTrue);
    });

    test('handles null check promotion', () {
      final block = BasicBlock(id: 0);
      block.addInstruction(NullCheckInstruction(
        offset: 0,
        operand: const VariableValue(Variable('maybeNull')),
        result: const Variable('definitelyNonNull'),
      ));
      block.addInstruction(CallInstruction(
        offset: 1,
        receiver: const VariableValue(Variable('definitelyNonNull')),
        methodName: 'doSomething',
        arguments: [],
      ));

      final cfg = ControlFlowGraph(
        functionName: 'test',
        entry: block,
        blocks: [block],
      );

      final verifier = NullVerifier();
      final results = verifier.verifyCfg(cfg);

      // Should have 2 dereferences: the null bang and the method call
      final methodCallResult = results.firstWhere(
        (r) => r.dereference.type == DereferenceType.methodCall,
      );
      expect(methodCallResult.isSafe, isTrue);
    });
  });

  group('CombinedDomain', () {
    test('combines interval and nullability', () {
      const a = CombinedDomain(
        IntervalDomain(0, 10),
        NullabilityDomain.nonNullValue,
      );
      const b = CombinedDomain(
        IntervalDomain(5, 15),
        NullabilityDomain.nullValue,
      );

      final joined = a.join(b);

      expect(joined.interval.min, equals(0));
      expect(joined.interval.max, equals(15));
      expect(joined.nullability.isTop, isTrue); // maybeNull
    });

    test('meet produces refined bounds', () {
      const a = CombinedDomain(
        IntervalDomain(0, 10),
        NullabilityDomain.topValue, // maybeNull
      );
      const b = CombinedDomain(
        IntervalDomain(5, 15),
        NullabilityDomain.nonNullValue,
      );

      final met = a.meet(b);

      expect(met.interval.min, equals(5));
      expect(met.interval.max, equals(10));
      expect(met.nullability.isDefinitelyNonNull, isTrue);
    });
  });
}
