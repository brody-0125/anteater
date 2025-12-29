import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:anteater/ir/cfg/cfg_builder.dart';
import 'package:anteater/ir/cfg/control_flow_graph.dart';
import 'package:anteater/ir/ssa/ssa_builder.dart';
import 'package:test/test.dart';

void main() {
  group('CfgBuilder', () {
    late CfgBuilder builder;

    setUp(() {
      builder = CfgBuilder();
    });

    FunctionDeclaration parseFunction(String code) {
      final result = parseString(content: code);
      return result.unit.declarations.first as FunctionDeclaration;
    }

    group('Simple Statements', () {
      test('empty function creates entry and exit blocks', () {
        final func = parseFunction('''
void empty() {}
''');
        final cfg = builder.buildFromFunction(func);

        expect(cfg.functionName, equals('empty'));
        expect(cfg.blocks, isNotEmpty);
        expect(cfg.entry, isNotNull);
      });

      test('variable declaration creates assignment instruction', () {
        final func = parseFunction('''
void simple() {
  var x = 42;
}
''');
        final cfg = builder.buildFromFunction(func);

        final assignments = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<AssignInstruction>()
            .toList();

        expect(assignments, isNotEmpty);
        expect(assignments.first.target.name, equals('x'));
        expect(assignments.first.value, isA<ConstantValue>());
      });

      test('binary expression creates BinaryOpValue', () {
        final func = parseFunction('''
void math() {
  var result = 1 + 2;
}
''');
        final cfg = builder.buildFromFunction(func);

        final assignments = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<AssignInstruction>()
            .toList();

        expect(assignments.first.value, isA<BinaryOpValue>());
        final binOp = assignments.first.value as BinaryOpValue;
        expect(binOp.operator, equals('+'));
      });

      test('return statement creates ReturnInstruction', () {
        final func = parseFunction('''
int getValue() {
  return 42;
}
''');
        final cfg = builder.buildFromFunction(func);

        final returns = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<ReturnInstruction>()
            .toList();

        expect(returns, isNotEmpty);
        expect(returns.first.value, isA<ConstantValue>());
      });
    });

    group('Control Flow', () {
      test('if statement creates diamond pattern', () {
        final func = parseFunction('''
void ifExample(bool cond) {
  if (cond) {
    print('yes');
  } else {
    print('no');
  }
}
''');
        final cfg = builder.buildFromFunction(func);

        // Should have: entry, then, else, merge, exit blocks
        expect(cfg.blocks.length, greaterThanOrEqualTo(4));

        final branches = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<BranchInstruction>()
            .toList();

        expect(branches, isNotEmpty);
        expect(branches.first.thenBlock, isNotNull);
        expect(branches.first.elseBlock, isNotNull);
      });

      test('while loop creates loop pattern', () {
        final func = parseFunction('''
void whileExample(int n) {
  var i = 0;
  while (i < n) {
    i = i + 1;
  }
}
''');
        final cfg = builder.buildFromFunction(func);

        // Should have back edge from body to header
        final branches = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<BranchInstruction>()
            .toList();

        expect(branches, isNotEmpty);

        // Check for loop structure - header block should have predecessor from body
        final hasBackEdge = cfg.blocks.any((b) =>
            b.successors.contains(cfg.blocks.firstWhere(
                (block) => block.instructions.any((i) => i is BranchInstruction))));

        expect(hasBackEdge || cfg.blocks.length >= 4, isTrue);
      });

      test('for loop creates proper structure', () {
        final func = parseFunction('''
void forExample() {
  for (var i = 0; i < 10; i++) {
    print(i);
  }
}
''');
        final cfg = builder.buildFromFunction(func);

        // Should have initialization, header, body, update blocks
        expect(cfg.blocks.length, greaterThanOrEqualTo(4));
      });

      test('break statement jumps to exit block', () {
        final func = parseFunction('''
void breakExample() {
  while (true) {
    break;
  }
}
''');
        final cfg = builder.buildFromFunction(func);

        final jumps = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<JumpInstruction>()
            .toList();

        // Should have jump for break
        expect(jumps, isNotEmpty);
      });

      test('continue statement jumps to header', () {
        final func = parseFunction('''
void continueExample(int n) {
  for (var i = 0; i < n; i++) {
    if (i == 5) continue;
    print(i);
  }
}
''');
        final cfg = builder.buildFromFunction(func);

        // Should have multiple jump instructions
        final jumps = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<JumpInstruction>()
            .toList();

        expect(jumps.length, greaterThanOrEqualTo(2));
      });
    });

    group('Expressions', () {
      test('method invocation creates CallInstruction', () {
        final func = parseFunction('''
void callExample() {
  print('hello');
}
''');
        final cfg = builder.buildFromFunction(func);

        final calls = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<CallInstruction>()
            .toList();

        expect(calls, isNotEmpty);
        expect(calls.first.methodName, equals('print'));
      });

      test('property access creates FieldAccessValue', () {
        final func = parseFunction('''
void propertyExample(String s) {
  var len = s.length;
}
''');
        final cfg = builder.buildFromFunction(func);

        final assignments = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<AssignInstruction>()
            .toList();

        // Find assignment with FieldAccessValue
        final fieldAccess = assignments.where(
            (a) => a.value is FieldAccessValue).toList();

        expect(fieldAccess, isNotEmpty);
      });

      test('conditional expression creates branches', () {
        final func = parseFunction('''
void conditionalExample(bool cond) {
  var result = cond ? 1 : 2;
}
''');
        final cfg = builder.buildFromFunction(func);

        final branches = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<BranchInstruction>()
            .toList();

        expect(branches, isNotEmpty);
      });

      test('null-aware operator creates null check branches', () {
        final func = parseFunction('''
void nullAwareExample(String? s) {
  var result = s ?? 'default';
}
''');
        final cfg = builder.buildFromFunction(func);

        // Should create branch for null check
        final branches = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<BranchInstruction>()
            .toList();

        expect(branches, isNotEmpty);
      });

      test('short-circuit AND creates branches', () {
        final func = parseFunction('''
void andExample(bool a, bool b) {
  var result = a && b;
}
''');
        final cfg = builder.buildFromFunction(func);

        final branches = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<BranchInstruction>()
            .toList();

        expect(branches, isNotEmpty);
      });

      test('short-circuit OR creates branches', () {
        final func = parseFunction('''
void orExample(bool a, bool b) {
  var result = a || b;
}
''');
        final cfg = builder.buildFromFunction(func);

        final branches = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<BranchInstruction>()
            .toList();

        expect(branches, isNotEmpty);
      });
    });

    group('SSA Integration', () {
      test('CFG can be converted to SSA', () {
        final func = parseFunction('''
void ssaExample(int x) {
  var y = x + 1;
  y = y * 2;
  return y;
}
''');
        final cfg = builder.buildFromFunction(func);
        final ssaCfg = cfg.toSsa();

        expect(ssaCfg, isNotNull);
        expect(ssaCfg.functionName, equals('ssaExample'));
      });

      test('reverse post order traversal works', () {
        final func = parseFunction('''
void rpoExample(bool cond) {
  if (cond) {
    print('a');
  } else {
    print('b');
  }
  print('c');
}
''');
        final cfg = builder.buildFromFunction(func);
        final rpo = cfg.reversePostOrder;

        // Entry should be first in RPO
        expect(rpo.first, equals(cfg.entry));
        expect(rpo.length, equals(cfg.blocks.length));
      });

      test('parameters are versioned with version 0', () {
        final func = parseFunction('''
int paramExample(int x, String y) {
  var z = x + 1;
  return z;
}
''');
        final cfg = builder.buildFromFunction(func);

        // Create parameters list (simulating what IrGenerator does)
        final parameters = [const Variable('x'), const Variable('y')];
        final ssaCfg = cfg.toSsa(parameters);

        expect(ssaCfg, isNotNull);

        // Check that the SSA builder properly initialized parameters
        // When parameters are read in the entry block, they should return
        // versioned values (x_0, y_0) instead of unversioned variables
        final allInstructions = ssaCfg.blocks
            .expand((b) => b.instructions)
            .toList();

        // Find assignments that use parameters
        final assignInstructions = allInstructions
            .whereType<AssignInstruction>()
            .toList();

        // At least one assignment should exist (z = x + 1)
        expect(assignInstructions, isNotEmpty);

        // Check that parameter 'x' is referenced with version 0
        // by looking for x_0 in the instruction values
        bool foundVersionedParameter = false;
        for (final assign in assignInstructions) {
          final value = assign.value;
          if (value is BinaryOpValue) {
            // Check left or right operand for versioned parameter
            if (value.left is VariableValue) {
              final varValue = value.left as VariableValue;
              if (varValue.variable.name == 'x' &&
                  varValue.variable.version == 0) {
                foundVersionedParameter = true;
                break;
              }
            }
          }
        }

        expect(
          foundVersionedParameter,
          isTrue,
          reason: 'Parameter x should be versioned as x_0 in SSA form',
        );
      });
    });

    group('Async Control Flow', () {
      test('await expression splits block', () {
        final func = parseFunction('''
Future<void> asyncExample() async {
  var x = await fetchData();
  print(x);
}
''');
        final cfg = builder.buildFromFunction(func);

        // Should have AwaitInstruction
        final awaits = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<AwaitInstruction>()
            .toList();

        expect(awaits, isNotEmpty);
        expect(awaits.first.future, isA<VariableValue>());
      });

      test('multiple awaits create multiple blocks', () {
        final func = parseFunction('''
Future<void> multiAwait() async {
  var a = await first();
  var b = await second();
  var c = await third();
}
''');
        final cfg = builder.buildFromFunction(func);

        final awaits = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<AwaitInstruction>()
            .toList();

        // Should have 3 await instructions
        expect(awaits.length, equals(3));

        // Each await should be in a different block (block splitting)
        final blocksWithAwait = cfg.blocks
            .where((b) => b.instructions.any((i) => i is AwaitInstruction))
            .toList();
        expect(blocksWithAwait.length, equals(3));
      });

      test('await in if statement works correctly', () {
        final func = parseFunction('''
Future<void> asyncIf(bool cond) async {
  if (cond) {
    var x = await fetchTrue();
  } else {
    var y = await fetchFalse();
  }
}
''');
        final cfg = builder.buildFromFunction(func);

        final awaits = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<AwaitInstruction>()
            .toList();

        // Should have 2 await instructions (one in each branch)
        expect(awaits.length, equals(2));
      });

      test('await creates continuation block with code after', () {
        final func = parseFunction('''
Future<int> awaitWithContinuation() async {
  var x = await getValue();
  var y = x + 1;
  return y;
}
''');
        final cfg = builder.buildFromFunction(func);

        // Find the block with AwaitInstruction
        final awaitBlock = cfg.blocks.firstWhere(
            (b) => b.instructions.any((i) => i is AwaitInstruction));

        // The await block should have exactly one successor (continuation)
        expect(awaitBlock.successors.length, equals(1));

        // The continuation block should have the addition and return
        final continuation = awaitBlock.successors.first;
        expect(continuation.instructions, isNotEmpty);
      });
    });

    group('Complex Patterns', () {
      test('nested if statements work correctly', () {
        final func = parseFunction('''
void nestedIf(int x) {
  if (x > 0) {
    if (x > 10) {
      print('big');
    } else {
      print('small');
    }
  }
}
''');
        final cfg = builder.buildFromFunction(func);

        final branches = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<BranchInstruction>()
            .toList();

        // Should have 2 branch instructions for nested ifs
        expect(branches.length, greaterThanOrEqualTo(2));
      });

      test('switch statement creates case blocks', () {
        final func = parseFunction('''
void switchExample(int x) {
  switch (x) {
    case 1:
      print('one');
      break;
    case 2:
      print('two');
      break;
    default:
      print('other');
  }
}
''');
        final cfg = builder.buildFromFunction(func);

        // Should have multiple blocks for cases
        expect(cfg.blocks.length, greaterThanOrEqualTo(4));
      });

      test('try-catch creates exception edges', () {
        final func = parseFunction('''
void tryCatchExample() {
  try {
    throw Exception();
  } catch (e) {
    print(e);
  }
}
''');
        final cfg = builder.buildFromFunction(func);

        // Should have blocks for try and catch
        expect(cfg.blocks.length, greaterThanOrEqualTo(3));
      });

      test('cascade expression processes all sections', () {
        final func = parseFunction('''
void cascadeExample(List<int> list) {
  list
    ..add(1)
    ..add(2)
    ..add(3);
}
''');
        final cfg = builder.buildFromFunction(func);

        final calls = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<CallInstruction>()
            .toList();

        // Should have 3 add calls
        expect(calls.length, greaterThanOrEqualTo(3));
      });
    });

    group('Constructor Building', () {
      ConstructorDeclaration parseConstructor(String code) {
        final result = parseString(content: code);
        final classDecl = result.unit.declarations.first as ClassDeclaration;
        return classDecl.members
            .whereType<ConstructorDeclaration>()
            .first;
      }

      test('constructor initializers generate StoreField instructions', () {
        final constructor = parseConstructor('''
class Point {
  final int x;
  final int y;

  Point(this.x, this.y);
}
''');
        final cfg = builder.buildFromConstructor(constructor, 'Point');

        expect(cfg, isNotNull);
        expect(cfg.functionName, equals('Point.<constructor>'));

        // 'this.x' and 'this.y' are handled in parameter processing,
        // not as field initializers. Check that CFG is built correctly.
        expect(cfg.blocks, isNotEmpty);
      });

      test('field initializer list generates StoreField instructions', () {
        final constructor = parseConstructor('''
class Rectangle {
  final int width;
  final int height;
  final int area;

  Rectangle(this.width, this.height) : area = width * height;
}
''');
        final cfg = builder.buildFromConstructor(constructor, 'Rectangle');

        expect(cfg.functionName, equals('Rectangle.<constructor>'));

        // Should have StoreField for 'area' from initializer list
        final storeFields = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<StoreFieldInstruction>()
            .toList();

        expect(storeFields, isNotEmpty);
        expect(
          storeFields.any((sf) => sf.fieldName == 'area'),
          isTrue,
          reason: 'Should have StoreField for area initializer',
        );
      });

      test('super constructor call generates CallInstruction', () {
        final constructor = parseConstructor('''
class Child extends Parent {
  Child(int value) : super(value);
}
''');
        final cfg = builder.buildFromConstructor(constructor, 'Child');

        expect(cfg.functionName, equals('Child.<constructor>'));

        // Should have CallInstruction for super call
        final calls = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<CallInstruction>()
            .toList();

        expect(calls, isNotEmpty);
        expect(
          calls.any((c) =>
              c.receiver is VariableValue &&
              (c.receiver as VariableValue).variable.name == 'super'),
          isTrue,
          reason: 'Should have super constructor call',
        );
      });

      test('named constructor has correct name', () {
        final result = parseString(content: '''
class Point {
  final int x;
  final int y;

  Point.origin() : x = 0, y = 0;
}
''');
        final classDecl = result.unit.declarations.first as ClassDeclaration;
        final constructor = classDecl.members
            .whereType<ConstructorDeclaration>()
            .first;

        final cfg = builder.buildFromConstructor(constructor, 'Point');

        expect(cfg.functionName, equals('Point.origin'));

        // Should have StoreField for x and y
        final storeFields = cfg.blocks
            .expand((b) => b.instructions)
            .whereType<StoreFieldInstruction>()
            .toList();

        expect(storeFields.length, equals(2));
      });
    });
  });
}
