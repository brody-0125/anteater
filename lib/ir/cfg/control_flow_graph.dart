/// Control Flow Graph (CFG) representation.
///
/// Represents the flow of control through a function as a directed graph
/// of basic blocks connected by edges.
library;

/// A basic block in the CFG.
///
/// Contains a sequence of instructions with:
/// - Single entry point (first instruction)
/// - Single exit point (last instruction)
/// - No internal branches
class BasicBlock {
  final int id;
  final List<Instruction> instructions;
  final List<BasicBlock> predecessors;
  final List<BasicBlock> successors;

  BasicBlock({
    required this.id,
    List<Instruction>? instructions,
    List<BasicBlock>? predecessors,
    List<BasicBlock>? successors,
  })  : instructions = instructions ?? [],
        predecessors = predecessors ?? [],
        successors = successors ?? [];

  /// The terminator instruction (last instruction).
  Instruction? get terminator =>
      instructions.isNotEmpty ? instructions.last : null;

  /// Adds an instruction to this block.
  void addInstruction(Instruction instruction) {
    instructions.add(instruction);
  }

  /// Connects this block to a successor.
  void connectTo(BasicBlock successor) {
    if (!successors.contains(successor)) {
      successors.add(successor);
      successor.predecessors.add(this);
    }
  }

  @override
  String toString() => 'BB$id';
}

/// Base class for CFG instructions.
///
/// This is a sealed class hierarchy, enabling exhaustive pattern matching
/// in switch statements. All instruction types must be defined in this library.
sealed class Instruction {
  final int offset;

  Instruction({required this.offset});
}

/// Assignment instruction: target = value
class AssignInstruction extends Instruction {
  final Variable target;
  final Value value;

  AssignInstruction({
    required super.offset,
    required this.target,
    required this.value,
  });

  @override
  String toString() => '$target = $value';
}

/// Conditional branch instruction.
class BranchInstruction extends Instruction {
  final Value condition;
  final BasicBlock thenBlock;
  final BasicBlock elseBlock;

  BranchInstruction({
    required super.offset,
    required this.condition,
    required this.thenBlock,
    required this.elseBlock,
  });

  @override
  String toString() => 'if ($condition) goto $thenBlock else $elseBlock';
}

/// Unconditional jump instruction.
class JumpInstruction extends Instruction {
  final BasicBlock target;

  JumpInstruction({required super.offset, required this.target});

  @override
  String toString() => 'goto $target';
}

/// Return instruction.
class ReturnInstruction extends Instruction {
  final Value? value;

  ReturnInstruction({required super.offset, this.value});

  @override
  String toString() => value != null ? 'return $value' : 'return';
}

/// Phi function for SSA form.
class PhiInstruction extends Instruction {
  final Variable target;
  final Map<BasicBlock, Value> operands;

  PhiInstruction({
    required super.offset,
    required this.target,
    Map<BasicBlock, Value>? operands,
  }) : operands = operands ?? {};

  void addOperand(BasicBlock predecessor, Value value) {
    operands[predecessor] = value;
  }

  @override
  String toString() {
    final ops = operands.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    return '$target = φ($ops)';
  }
}

/// Represents a variable in the CFG.
class Variable {
  final String name;
  final int version;

  const Variable(this.name, [this.version = 0]);

  Variable withVersion(int newVersion) => Variable(name, newVersion);

  @override
  String toString() => version > 0 ? '${name}_$version' : name;

  @override
  bool operator ==(Object other) =>
      other is Variable && other.name == name && other.version == version;

  @override
  int get hashCode => Object.hash(name, version);
}

/// Base class for values in instructions.
///
/// This is a sealed class hierarchy, enabling exhaustive pattern matching
/// in switch statements. All value types must be defined in this library.
sealed class Value {
  const Value();
}

/// A variable reference as a value.
class VariableValue extends Value {
  final Variable variable;

  const VariableValue(this.variable) : super();

  @override
  String toString() => variable.toString();
}

/// A constant value.
class ConstantValue extends Value {
  final Object? value;

  const ConstantValue(this.value) : super();

  @override
  String toString() => value?.toString() ?? 'null';
}

/// A binary operation value.
class BinaryOpValue extends Value {
  final String operator;
  final Value left;
  final Value right;

  const BinaryOpValue(this.operator, this.left, this.right) : super();

  @override
  String toString() => '($left $operator $right)';
}

/// A unary operation value.
class UnaryOpValue extends Value {
  final String operator;
  final Value operand;

  const UnaryOpValue(this.operator, this.operand) : super();

  @override
  String toString() => '($operator$operand)';
}

/// Function/method call value.
class CallValue extends Value {
  final Value? receiver;
  final String methodName;
  final List<Value> arguments;

  const CallValue({
    this.receiver,
    required this.methodName,
    required this.arguments,
  }) : super();

  @override
  String toString() {
    final args = arguments.join(', ');
    if (receiver != null) {
      return '$receiver.$methodName($args)';
    }
    return '$methodName($args)';
  }
}

/// Field access value.
class FieldAccessValue extends Value {
  final Value receiver;
  final String fieldName;

  const FieldAccessValue(this.receiver, this.fieldName) : super();

  @override
  String toString() => '$receiver.$fieldName';
}

/// Index access value (e.g., list[i]).
class IndexAccessValue extends Value {
  final Value receiver;
  final Value index;

  const IndexAccessValue(this.receiver, this.index) : super();

  @override
  String toString() => '$receiver[$index]';
}

/// Object instantiation value.
class NewObjectValue extends Value {
  final String typeName;
  final String? constructorName;
  final List<Value> arguments;

  const NewObjectValue({
    required this.typeName,
    this.constructorName,
    required this.arguments,
  }) : super();

  @override
  String toString() {
    final args = arguments.join(', ');
    final ctor = constructorName != null ? '.$constructorName' : '';
    return '$typeName$ctor($args)';
  }
}

/// Phi value reference (for SSA).
class PhiValue extends Value {
  final Variable variable;

  const PhiValue(this.variable) : super();

  @override
  String toString() => 'φ(${variable.name})';
}

/// Function call instruction.
class CallInstruction extends Instruction {
  final Value? receiver;
  final String methodName;
  final List<Value> arguments;
  final Variable? result;

  CallInstruction({
    required super.offset,
    this.receiver,
    required this.methodName,
    required this.arguments,
    this.result,
  });

  @override
  String toString() {
    final args = arguments.join(', ');
    final call =
        receiver != null ? '$receiver.$methodName($args)' : '$methodName($args)';
    return result != null ? '$result = $call' : call;
  }
}

/// Field load instruction.
class LoadFieldInstruction extends Instruction {
  final Value base;
  final String fieldName;
  final Variable result;

  LoadFieldInstruction({
    required super.offset,
    required this.base,
    required this.fieldName,
    required this.result,
  });

  @override
  String toString() => '$result = $base.$fieldName';
}

/// Field store instruction.
class StoreFieldInstruction extends Instruction {
  final Value base;
  final String fieldName;
  final Value value;

  StoreFieldInstruction({
    required super.offset,
    required this.base,
    required this.fieldName,
    required this.value,
  });

  @override
  String toString() => '$base.$fieldName = $value';
}

/// Index load instruction.
class LoadIndexInstruction extends Instruction {
  final Value base;
  final Value index;
  final Variable result;

  LoadIndexInstruction({
    required super.offset,
    required this.base,
    required this.index,
    required this.result,
  });

  @override
  String toString() => '$result = $base[$index]';
}

/// Index store instruction.
class StoreIndexInstruction extends Instruction {
  final Value base;
  final Value index;
  final Value value;

  StoreIndexInstruction({
    required super.offset,
    required this.base,
    required this.index,
    required this.value,
  });

  @override
  String toString() => '$base[$index] = $value';
}

/// Null check instruction (for type promotion).
class NullCheckInstruction extends Instruction {
  final Value operand;
  final Variable result;

  NullCheckInstruction({
    required super.offset,
    required this.operand,
    required this.result,
  });

  @override
  String toString() => '$result = $operand!';
}

/// Type cast instruction.
class CastInstruction extends Instruction {
  final Value operand;
  final String targetType;
  final Variable result;
  final bool isNullable;

  CastInstruction({
    required super.offset,
    required this.operand,
    required this.targetType,
    required this.result,
    this.isNullable = false,
  });

  @override
  String toString() {
    final op = isNullable ? 'as?' : 'as';
    return '$result = $operand $op $targetType';
  }
}

/// Type check instruction (is/is!).
class TypeCheckInstruction extends Instruction {
  final Value operand;
  final String targetType;
  final Variable result;
  final bool negated;

  TypeCheckInstruction({
    required super.offset,
    required this.operand,
    required this.targetType,
    required this.result,
    this.negated = false,
  });

  @override
  String toString() {
    final op = negated ? 'is!' : 'is';
    return '$result = $operand $op $targetType';
  }
}

/// Throw instruction.
class ThrowInstruction extends Instruction {
  final Value exception;

  ThrowInstruction({required super.offset, required this.exception});

  @override
  String toString() => 'throw $exception';
}

/// Await instruction - represents an async suspension point.
///
/// This instruction terminates the current block and creates a
/// continuation point. The [future] operand is the value being awaited,
/// and [result] receives the unwrapped value when the future completes.
class AwaitInstruction extends Instruction {
  final Value future;
  final Variable result;

  AwaitInstruction({
    required super.offset,
    required this.future,
    required this.result,
  });

  @override
  String toString() => '$result = await $future';
}

/// Control Flow Graph for a function.
class ControlFlowGraph {
  final String functionName;
  final BasicBlock entry;
  final List<BasicBlock> blocks;

  ControlFlowGraph({
    required this.functionName,
    required this.entry,
    required this.blocks,
  });

  /// Returns blocks in reverse postorder (useful for dataflow analysis).
  List<BasicBlock> get reversePostOrder {
    final visited = <BasicBlock>{};
    final result = <BasicBlock>[];

    void visit(BasicBlock block) {
      if (visited.contains(block)) return;
      visited.add(block);
      for (final succ in block.successors) {
        visit(succ);
      }
      result.add(block);
    }

    visit(entry);
    return result.reversed.toList();
  }

  /// Prints the CFG in a human-readable format.
  void dump() {
    for (final block in blocks) {
      print('$block:');
      print('  predecessors: ${block.predecessors}');
      for (final instr in block.instructions) {
        print('  $instr');
      }
      print('  successors: ${block.successors}');
      print('');
    }
  }
}
