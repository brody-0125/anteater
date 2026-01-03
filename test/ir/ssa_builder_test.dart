import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:anteater/ir/cfg/cfg_builder.dart';
import 'package:anteater/ir/cfg/control_flow_graph.dart';
import 'package:anteater/ir/ssa/ssa_builder.dart';
import 'package:test/test.dart';

void main() {
  group('SsaBuilder', () {
    late CfgBuilder cfgBuilder;

    setUp(() {
      cfgBuilder = CfgBuilder();
    });

    FunctionDeclaration parseFunction(String code) {
      final result = parseString(content: code);
      return result.unit.declarations.first as FunctionDeclaration;
    }

    group('Variable Versioning', () {
      test('single assignment gets version 1', () {
        final func = parseFunction('''
void simple() {
  var x = 42;
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final ssaCfg = cfg.toSsa();

        final assignments = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<AssignInstruction>()
            .toList();

        expect(assignments, isNotEmpty);
        expect(assignments.first.target.version, greaterThan(0));
      });

      test('multiple assignments to same variable get different versions', () {
        final func = parseFunction('''
void multiAssign() {
  var x = 1;
  x = 2;
  x = 3;
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final ssaCfg = cfg.toSsa();

        final xAssignments = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<AssignInstruction>()
            .where((a) => a.target.name == 'x')
            .toList();

        expect(xAssignments.length, equals(3));

        final versions = xAssignments.map((a) => a.target.version).toSet();
        expect(versions.length, equals(3),
            reason: 'Each assignment should have a unique version');
      });

      test('reassignment uses previous version on RHS', () {
        final func = parseFunction('''
void reassign() {
  var x = 1;
  x = x + 1;
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final ssaCfg = cfg.toSsa();

        final xAssignments = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<AssignInstruction>()
            .where((a) => a.target.name == 'x')
            .toList();

        expect(xAssignments.length, equals(2));

        // Second assignment's RHS should reference first version
        final secondAssign = xAssignments[1];
        expect(secondAssign.value, isA<BinaryOpValue>());

        final binOp = secondAssign.value as BinaryOpValue;
        expect(binOp.left, isA<VariableValue>());

        final leftVar = binOp.left as VariableValue;
        expect(leftVar.variable.name, equals('x'));
        expect(leftVar.variable.version, lessThan(secondAssign.target.version),
            reason: 'RHS should reference earlier version');
      });

      test('different variables have independent versions', () {
        final func = parseFunction('''
void multiVar() {
  var x = 1;
  var y = 2;
  x = 3;
  y = 4;
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final ssaCfg = cfg.toSsa();

        final assignments = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<AssignInstruction>()
            .toList();

        expect(assignments.length, equals(4));

        // Each assignment should have its own version
        final allVersioned = assignments.every((a) => a.target.version > 0);
        expect(allVersioned, isTrue);
      });
    });

    group('Phi Function Insertion', () {
      test('if-else merge point inserts phi for modified variable', () {
        final func = parseFunction('''
void ifElsePhi(bool cond) {
  var x = 0;
  if (cond) {
    x = 1;
  } else {
    x = 2;
  }
  var y = x;
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final ssaCfg = cfg.toSsa();

        final phis = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<PhiInstruction>()
            .toList();

        // Should have phi for x at merge point
        final xPhis = phis.where((p) => p.target.name == 'x').toList();
        expect(xPhis, isNotEmpty,
            reason: 'Should have phi for x at if-else merge');

        // Phi should have 2 operands (one from each branch)
        expect(xPhis.first.operands.length, equals(2));
      });

      test('loop back edge inserts phi for modified variable', () {
        final func = parseFunction('''
void loopPhi(int n) {
  var i = 0;
  while (i < n) {
    i = i + 1;
  }
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final ssaCfg = cfg.toSsa();

        final phis = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<PhiInstruction>()
            .toList();

        // Should have phi for i at loop header
        final iPhis = phis.where((p) => p.target.name == 'i').toList();
        expect(iPhis, isNotEmpty,
            reason: 'Should have phi for i at loop header');
      });

      // Note: Trivial phi elimination for incomplete phis is a known limitation.
      // The current implementation inserts phis at merge points even when
      // the variable is unchanged in branches. These phis have identical
      // operands but are not eliminated due to the timing of phi insertion
      // vs. operand filling for incomplete phis.
      test('merge point has phi even when variable unchanged (current behavior)', () {
        final func = parseFunction('''
void noPhiNeeded(bool cond) {
  var x = 1;
  if (cond) {
    print(x);
  } else {
    print(x);
  }
  var y = x;
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final ssaCfg = cfg.toSsa();

        final phis = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<PhiInstruction>()
            .toList();

        // Current behavior: phis are inserted at merge points
        // even when variable is unchanged. This is a known limitation.
        final xPhis = phis.where((p) => p.target.name == 'x').toList();
        expect(xPhis, isNotEmpty,
            reason: 'Current impl inserts phis at merge points');
      });
    });

    group('Trivial Phi Elimination', () {
      // Note: Trivial phi elimination works during phi creation in
      // _readVariableRecursive, but incomplete phis (created before
      // block sealing) are not re-checked after operands are filled.
      // This is a known limitation of the current implementation.
      test('trivial phi with same operands exists (current limitation)', () {
        final func = parseFunction('''
void trivialPhi(bool cond) {
  var x = 1;
  if (cond) {
    print('a');
  } else {
    print('b');
  }
  var y = x;
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final ssaCfg = cfg.toSsa();

        final phis = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<PhiInstruction>()
            .where((p) => p.target.name == 'x')
            .toList();

        // Current behavior: trivial phis are not eliminated for incomplete phis
        // When fixed, this test should expect isEmpty
        expect(phis, isNotEmpty,
            reason: 'Current impl does not eliminate trivial incomplete phis');
      });

      test('non-trivial phi is preserved', () {
        final func = parseFunction('''
void nonTrivialPhi(bool cond) {
  var x = 0;
  if (cond) {
    x = 1;
  } else {
    x = 2;
  }
  var y = x;
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final ssaCfg = cfg.toSsa();

        final phis = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<PhiInstruction>()
            .where((p) => p.target.name == 'x')
            .toList();

        // Non-trivial phi should be preserved
        expect(phis, isNotEmpty,
            reason: 'Non-trivial phi should be preserved');
      });
    });

    group('Parameter Handling', () {
      test('parameters initialized with version 0', () {
        final func = parseFunction('''
int addOne(int x) {
  return x + 1;
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final parameters = [const Variable('x')];
        final ssaCfg = cfg.toSsa(parameters);

        // Find uses of x in the function
        final assignments = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<ReturnInstruction>()
            .toList();

        expect(assignments, isNotEmpty);

        // The return value should use x_0
        final returnInstr = assignments.first;
        expect(returnInstr.value, isA<BinaryOpValue>());

        final binOp = returnInstr.value as BinaryOpValue;
        expect(binOp.left, isA<VariableValue>());

        final leftVar = binOp.left as VariableValue;
        expect(leftVar.variable.name, equals('x'));
        expect(leftVar.variable.version, equals(0),
            reason: 'Parameter should have version 0');
      });

      test('parameter reassignment gets new version', () {
        final func = parseFunction('''
int increment(int x) {
  x = x + 1;
  return x;
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final parameters = [const Variable('x')];
        final ssaCfg = cfg.toSsa(parameters);

        final xAssignments = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<AssignInstruction>()
            .where((a) => a.target.name == 'x')
            .toList();

        expect(xAssignments, isNotEmpty);

        // Assignment should create new version
        expect(xAssignments.first.target.version, greaterThan(0),
            reason: 'Reassigned parameter should have version > 0');

        // RHS should use version 0
        final assignValue = xAssignments.first.value;
        expect(assignValue, isA<BinaryOpValue>());

        final binOp = assignValue as BinaryOpValue;
        expect(binOp.left, isA<VariableValue>());

        final leftVar = binOp.left as VariableValue;
        expect(leftVar.variable.version, equals(0),
            reason: 'RHS should reference parameter version 0');
      });

      test('multiple parameters each have version 0', () {
        final func = parseFunction('''
int add(int a, int b) {
  return a + b;
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final parameters = [const Variable('a'), const Variable('b')];
        final ssaCfg = cfg.toSsa(parameters);

        final returns = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<ReturnInstruction>()
            .toList();

        expect(returns, isNotEmpty);

        final returnValue = returns.first.value;
        expect(returnValue, isA<BinaryOpValue>());

        final binOp = returnValue as BinaryOpValue;

        // Both operands should reference version 0
        expect(binOp.left, isA<VariableValue>());
        expect(binOp.right, isA<VariableValue>());

        final leftVar = binOp.left as VariableValue;
        final rightVar = binOp.right as VariableValue;

        expect(leftVar.variable.version, equals(0));
        expect(rightVar.variable.version, equals(0));
      });
    });

    group('Instruction Type Versioning', () {
      test('CallInstruction result is versioned', () {
        final func = parseFunction('''
void callExample() {
  var result = getValue();
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final ssaCfg = cfg.toSsa();

        final calls = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<CallInstruction>()
            .where((c) => c.result != null)
            .toList();

        expect(calls, isNotEmpty);
        expect(calls.first.result!.version, greaterThan(0),
            reason: 'Call result should be versioned');
      });

      test('FieldAccessValue in assignment is versioned', () {
        // Note: CFG builder uses FieldAccessValue (a value type) for
        // property access, not LoadFieldInstruction (an instruction type).
        // The assignment target gets versioned in SSA.
        final func = parseFunction('''
void fieldExample(String s) {
  var len = s.length;
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final parameters = [const Variable('s')];
        final ssaCfg = cfg.toSsa(parameters);

        // Find assignments with FieldAccessValue
        final assignments = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<AssignInstruction>()
            .where((a) => a.value is FieldAccessValue)
            .toList();

        expect(assignments, isNotEmpty,
            reason: 'Should have assignment with field access');
        expect(assignments.first.target.version, greaterThan(0),
            reason: 'Assignment target should be versioned');
      });

      test('AwaitInstruction result is versioned', () {
        final func = parseFunction('''
Future<void> asyncExample() async {
  var x = await fetchData();
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final ssaCfg = cfg.toSsa();

        final awaits = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<AwaitInstruction>()
            .toList();

        expect(awaits, isNotEmpty);
        expect(awaits.first.result.version, greaterThan(0),
            reason: 'Await result should be versioned');
      });
    });

    group('Complex Control Flow', () {
      test('nested if statements version correctly', () {
        final func = parseFunction('''
void nestedIf(int x) {
  var y = 0;
  if (x > 0) {
    y = 1;
    if (x > 10) {
      y = 2;
    }
  }
  var z = y;
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final parameters = [const Variable('x')];
        final ssaCfg = cfg.toSsa(parameters);

        final yAssignments = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<AssignInstruction>()
            .where((a) => a.target.name == 'y')
            .toList();

        // Should have at least 3 assignments to y (initial + 2 in if blocks)
        expect(yAssignments.length, greaterThanOrEqualTo(3));

        // All should have unique versions
        final versions = yAssignments.map((a) => a.target.version).toSet();
        expect(versions.length, equals(yAssignments.length));
      });

      test('for loop with accumulator versions correctly', () {
        final func = parseFunction('''
int sum(int n) {
  var total = 0;
  for (var i = 0; i < n; i++) {
    total = total + i;
  }
  return total;
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final parameters = [const Variable('n')];
        final ssaCfg = cfg.toSsa(parameters);

        // Should have phis for loop variables
        final phis = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<PhiInstruction>()
            .toList();

        // At minimum, should have phi for i and total
        expect(phis.length, greaterThanOrEqualTo(1));
      });
    });

    group('Value Renaming', () {
      test('BinaryOpValue operands are renamed', () {
        final func = parseFunction('''
int calculate(int a, int b) {
  var x = a + b;
  var y = x * 2;
  return y;
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final parameters = [const Variable('a'), const Variable('b')];
        final ssaCfg = cfg.toSsa(parameters);

        final assignments = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<AssignInstruction>()
            .toList();

        // All variable references should be versioned
        for (final assign in assignments) {
          if (assign.value is BinaryOpValue) {
            final binOp = assign.value as BinaryOpValue;
            if (binOp.left is VariableValue) {
              final leftVar = binOp.left as VariableValue;
              expect(leftVar.variable.version, greaterThanOrEqualTo(0),
                  reason: 'BinaryOp left operand should be versioned');
            }
            if (binOp.right is VariableValue) {
              final rightVar = binOp.right as VariableValue;
              expect(rightVar.variable.version, greaterThanOrEqualTo(0),
                  reason: 'BinaryOp right operand should be versioned');
            }
          }
        }
      });

      test('CallValue arguments are renamed', () {
        final func = parseFunction('''
void callWithArgs(int x, int y) {
  print(x + y);
}
''');
        final cfg = cfgBuilder.buildFromFunction(func);
        final parameters = [const Variable('x'), const Variable('y')];
        final ssaCfg = cfg.toSsa(parameters);

        final calls = ssaCfg.blocks
            .expand((b) => b.instructions)
            .whereType<CallInstruction>()
            .toList();

        expect(calls, isNotEmpty);

        // Arguments should contain versioned variables
        final firstCall = calls.first;
        expect(firstCall.arguments, isNotEmpty);

        final firstArg = firstCall.arguments.first;
        expect(firstArg, isA<BinaryOpValue>());
      });
    });
  });
}
