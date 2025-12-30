import '../cfg/control_flow_graph.dart';

/// SSA (Static Single Assignment) builder using Braun et al. algorithm.
///
/// Converts CFG to SSA form on-the-fly without requiring dominator tree
/// computation. Key features:
/// - Direct AST-to-SSA conversion
/// - Lazy phi insertion
/// - Trivial phi elimination
/// - Complete use-renaming
///
/// Reference: "Simple and Efficient Construction of Static Single Assignment Form"
/// - Braun et al., 2013
class SsaBuilder {
  /// Current definition of each variable in each block.
  /// `Map<BlockId, Map<VariableName, Value>>`
  final Map<int, Map<String, Value>> _currentDef = {};

  /// Tracks incomplete phis that need operands filled in.
  final Map<int, List<PhiInstruction>> _incompletePhis = {};

  /// Tracks sealed blocks (all predecessors known).
  final Set<int> _sealedBlocks = {};

  /// Tracks phi instructions created for each block (for insertion).
  final Map<int, List<PhiInstruction>> _blockPhis = {};

  /// Tracks substitutions for eliminated trivial phis.
  /// When a phi is trivial (all operands same), map phi.target -> replacement.
  final Map<Variable, Value> _substitutions = {};

  int _versionCounter = 0;

  /// Writes a variable definition in a block.
  void writeVariable(Variable variable, BasicBlock block, Value value) {
    _currentDef.putIfAbsent(block.id, () => {});
    _currentDef[block.id]![variable.name] = value;
  }

  /// Reads a variable's value in a block.
  ///
  /// If the variable is not defined locally, searches predecessors
  /// and inserts phi functions as needed. The result is resolved through
  /// substitution chains from eliminated trivial phis.
  Value readVariable(Variable variable, BasicBlock block) {
    final localDef = _currentDef[block.id]?[variable.name];
    if (localDef != null) {
      return _resolveValue(localDef);
    }
    return _readVariableRecursive(variable, block);
  }

  /// Recursively searches for variable definition in predecessors.
  Value _readVariableRecursive(Variable variable, BasicBlock block) {
    Value value;

    if (!_sealedBlocks.contains(block.id)) {
      // Block not sealed yet - create incomplete phi
      final phi = PhiInstruction(
        offset: 0,
        target: variable.withVersion(++_versionCounter),
      );
      _incompletePhis.putIfAbsent(block.id, () => []).add(phi);
      _blockPhis.putIfAbsent(block.id, () => []).add(phi);
      value = VariableValue(phi.target);
    } else if (block.predecessors.isEmpty) {
      // Entry block - undefined variable (could be parameter or error)
      value = VariableValue(variable);
    } else if (block.predecessors.length == 1) {
      // Single predecessor - no phi needed
      value = readVariable(variable, block.predecessors.first);
    } else {
      // Multiple predecessors - insert phi
      final phi = PhiInstruction(
        offset: 0,
        target: variable.withVersion(++_versionCounter),
      );
      // Write before reading to break infinite recursion
      writeVariable(variable, block, VariableValue(phi.target));

      // Fill in phi operands
      for (final pred in block.predecessors) {
        phi.addOperand(pred, readVariable(variable, pred));
      }

      // Try to remove trivial phi, but track non-trivial ones
      final result = _tryRemoveTrivialPhi(phi);
      if (result is VariableValue && result.variable == phi.target) {
        // Non-trivial phi - track for insertion into block
        _blockPhis.putIfAbsent(block.id, () => []).add(phi);
      }
      value = result;
    }

    writeVariable(variable, block, value);
    return value;
  }

  /// Removes trivial phis where all operands are the same or self-referential.
  Value _tryRemoveTrivialPhi(PhiInstruction phi) {
    Value? same;

    for (final operand in phi.operands.values) {
      // Skip self-references
      if (operand is VariableValue && operand.variable == phi.target) {
        continue;
      }

      // If we've seen a different value, phi is non-trivial
      if (same != null && !_valuesEqual(operand, same)) {
        return VariableValue(phi.target); // Non-trivial phi
      }
      same = operand;
    }

    // Trivial phi - all operands are the same
    if (same == null) {
      return VariableValue(phi.target); // Undefined - keep phi
    }

    // Replace phi with the single value
    // Record substitution so all uses are updated
    _substitutions[phi.target] = same;

    // Recursively check if the replacement creates more trivial phis
    // (e.g., if same is a phi variable that was also eliminated)
    return _resolveValue(same);
  }

  bool _valuesEqual(Value a, Value b) {
    if (a is VariableValue && b is VariableValue) {
      return a.variable == b.variable;
    }
    if (a is ConstantValue && b is ConstantValue) {
      return a.value == b.value;
    }
    return false;
  }

  /// Resolves a value by following substitution chains.
  ///
  /// When a trivial phi is eliminated, its target is mapped to the
  /// replacement value. This method follows the chain until reaching
  /// a non-substituted value.
  Value _resolveValue(Value value) {
    if (value is! VariableValue) return value;

    // Explicitly typed as Value since substitutions can be any Value type
    Value current = value;
    // Follow substitution chain (with cycle detection)
    final visited = <Variable>{};
    while (current is VariableValue) {
      final variable = current.variable;
      if (visited.contains(variable)) break; // Cycle detected
      visited.add(variable);

      final substitution = _substitutions[variable];
      if (substitution == null) break;
      current = substitution;
    }
    return current;
  }

  /// Seals a block, indicating all predecessors are known.
  ///
  /// This triggers filling in incomplete phis.
  void sealBlock(BasicBlock block) {
    if (_sealedBlocks.contains(block.id)) return;

    final incompletePhis = _incompletePhis[block.id] ?? [];
    for (final phi in incompletePhis) {
      final variable = Variable(phi.target.name);
      for (final pred in block.predecessors) {
        phi.addOperand(pred, readVariable(variable, pred));
      }
    }

    _sealedBlocks.add(block.id);
  }

  /// Builds SSA form for a CFG.
  ///
  /// [parameters] is an optional list of function parameters that should be
  /// initialized with version 0 in the entry block. This ensures SSA invariant
  /// (single definition per variable) is maintained for parameters.
  ControlFlowGraph buildSsa(ControlFlowGraph cfg, [List<Variable>? parameters]) {
    // Initialize parameters in entry block with version 0
    // This ensures parameters have proper SSA versioning for Def-Use chains
    if (parameters != null) {
      for (final param in parameters) {
        final versioned = param.withVersion(0);
        writeVariable(param, cfg.entry, VariableValue(versioned));
      }
    }

    // Process blocks in reverse postorder
    for (final block in cfg.reversePostOrder) {
      _processBlock(block);
    }

    // Seal all blocks
    for (final block in cfg.blocks) {
      sealBlock(block);
    }

    // Insert phi instructions into blocks
    _insertPhisIntoBlocks(cfg);

    return cfg;
  }

  /// Inserts tracked phi instructions at the beginning of their blocks.
  void _insertPhisIntoBlocks(ControlFlowGraph cfg) {
    for (final block in cfg.blocks) {
      final phis = _blockPhis[block.id];
      if (phis != null && phis.isNotEmpty) {
        // Remove duplicates (same target variable) and filter eliminated phis
        final seenTargets = <String>{};
        final uniquePhis = <PhiInstruction>[];
        for (final phi in phis) {
          // Skip phis that were eliminated (have substitution)
          if (_substitutions.containsKey(phi.target)) continue;

          final targetKey = phi.target.name;
          if (!seenTargets.contains(targetKey)) {
            seenTargets.add(targetKey);
            // Only add non-trivial phis with operands
            if (phi.operands.isNotEmpty) {
              // Resolve operands through substitution chains
              _resolvePhiOperands(phi);
              uniquePhis.add(phi);
            }
          }
        }

        // Insert phis at the beginning of the block (O(k+n) instead of O(k*n))
        block.instructions.insertAll(0, uniquePhis);
      }
    }
  }

  /// Resolves phi operands through substitution chains.
  void _resolvePhiOperands(PhiInstruction phi) {
    final resolvedOperands = <BasicBlock, Value>{};
    for (final entry in phi.operands.entries) {
      resolvedOperands[entry.key] = _resolveValue(entry.value);
    }
    phi.operands
      ..clear()
      ..addAll(resolvedOperands);
  }

  void _processBlock(BasicBlock block) {
    final renamedInstructions = <Instruction>[];

    for (final instr in block.instructions) {
      final renamed = _processInstruction(instr, block);
      renamedInstructions.add(renamed);
    }

    // Replace instructions with renamed versions
    block.instructions
      ..clear()
      ..addAll(renamedInstructions);
  }

  /// Processes a single instruction, renaming uses and definitions.
  Instruction _processInstruction(Instruction instr, BasicBlock block) {
    switch (instr) {
      case AssignInstruction():
        // First, rename all uses in the RHS
        final renamedValue = _renameValue(instr.value, block);

        // Then, create new version for the target
        final newVersion = ++_versionCounter;
        final newTarget = instr.target.withVersion(newVersion);

        // Update current definition
        writeVariable(instr.target, block, VariableValue(newTarget));

        return AssignInstruction(
          offset: instr.offset,
          target: newTarget,
          value: renamedValue,
        );

      case BranchInstruction():
        return BranchInstruction(
          offset: instr.offset,
          condition: _renameValue(instr.condition, block),
          thenBlock: instr.thenBlock,
          elseBlock: instr.elseBlock,
        );

      case ReturnInstruction():
        return ReturnInstruction(
          offset: instr.offset,
          value: instr.value != null ? _renameValue(instr.value!, block) : null,
        );

      case CallInstruction():
        Variable? newResult;
        if (instr.result != null) {
          final newVersion = ++_versionCounter;
          newResult = instr.result!.withVersion(newVersion);
          writeVariable(instr.result!, block, VariableValue(newResult));
        }
        return CallInstruction(
          offset: instr.offset,
          receiver:
              instr.receiver != null ? _renameValue(instr.receiver!, block) : null,
          methodName: instr.methodName,
          arguments: instr.arguments.map((a) => _renameValue(a, block)).toList(),
          result: newResult,
        );

      case LoadFieldInstruction():
        final newVersion = ++_versionCounter;
        final newResult = instr.result.withVersion(newVersion);
        writeVariable(instr.result, block, VariableValue(newResult));
        return LoadFieldInstruction(
          offset: instr.offset,
          base: _renameValue(instr.base, block),
          fieldName: instr.fieldName,
          result: newResult,
        );

      case StoreFieldInstruction():
        return StoreFieldInstruction(
          offset: instr.offset,
          base: _renameValue(instr.base, block),
          fieldName: instr.fieldName,
          value: _renameValue(instr.value, block),
        );

      case LoadIndexInstruction():
        final newVersion = ++_versionCounter;
        final newResult = instr.result.withVersion(newVersion);
        writeVariable(instr.result, block, VariableValue(newResult));
        return LoadIndexInstruction(
          offset: instr.offset,
          base: _renameValue(instr.base, block),
          index: _renameValue(instr.index, block),
          result: newResult,
        );

      case StoreIndexInstruction():
        return StoreIndexInstruction(
          offset: instr.offset,
          base: _renameValue(instr.base, block),
          index: _renameValue(instr.index, block),
          value: _renameValue(instr.value, block),
        );

      case NullCheckInstruction():
        final newVersion = ++_versionCounter;
        final newResult = instr.result.withVersion(newVersion);
        writeVariable(instr.result, block, VariableValue(newResult));
        return NullCheckInstruction(
          offset: instr.offset,
          operand: _renameValue(instr.operand, block),
          result: newResult,
        );

      case CastInstruction():
        final newVersion = ++_versionCounter;
        final newResult = instr.result.withVersion(newVersion);
        writeVariable(instr.result, block, VariableValue(newResult));
        return CastInstruction(
          offset: instr.offset,
          operand: _renameValue(instr.operand, block),
          targetType: instr.targetType,
          result: newResult,
          isNullable: instr.isNullable,
        );

      case TypeCheckInstruction():
        final newVersion = ++_versionCounter;
        final newResult = instr.result.withVersion(newVersion);
        writeVariable(instr.result, block, VariableValue(newResult));
        return TypeCheckInstruction(
          offset: instr.offset,
          operand: _renameValue(instr.operand, block),
          targetType: instr.targetType,
          result: newResult,
          negated: instr.negated,
        );

      case ThrowInstruction():
        return ThrowInstruction(
          offset: instr.offset,
          exception: _renameValue(instr.exception, block),
        );

      case AwaitInstruction():
        final newVersion = ++_versionCounter;
        final newResult = instr.result.withVersion(newVersion);
        writeVariable(instr.result, block, VariableValue(newResult));
        return AwaitInstruction(
          offset: instr.offset,
          future: _renameValue(instr.future, block),
          result: newResult,
        );

      default:
        return instr;
    }
  }

  /// Renames variable references in a value to their SSA versions.
  Value _renameValue(Value value, BasicBlock block) {
    switch (value) {
      case VariableValue(:final variable):
        return readVariable(variable, block);

      case BinaryOpValue(:final operator, :final left, :final right):
        return BinaryOpValue(
          operator,
          _renameValue(left, block),
          _renameValue(right, block),
        );

      case UnaryOpValue(:final operator, :final operand):
        return UnaryOpValue(operator, _renameValue(operand, block));

      case CallValue(:final receiver, :final methodName, :final arguments):
        return CallValue(
          receiver: receiver != null ? _renameValue(receiver, block) : null,
          methodName: methodName,
          arguments: arguments.map((a) => _renameValue(a, block)).toList(),
        );

      case FieldAccessValue(:final receiver, :final fieldName):
        return FieldAccessValue(_renameValue(receiver, block), fieldName);

      case IndexAccessValue(:final receiver, :final index):
        return IndexAccessValue(
          _renameValue(receiver, block),
          _renameValue(index, block),
        );

      case NewObjectValue():
        return NewObjectValue(
          typeName: value.typeName,
          constructorName: value.constructorName,
          arguments: value.arguments.map((a) => _renameValue(a, block)).toList(),
        );

      case ConstantValue():
      case PhiValue():
        return value;
    }
  }
}

/// Extension to build SSA from a CFG.
extension SsaExtension on ControlFlowGraph {
  /// Converts this CFG to SSA form.
  ///
  /// [parameters] is an optional list of function parameters that should be
  /// initialized with version 0 in the entry block.
  ControlFlowGraph toSsa([List<Variable>? parameters]) {
    final builder = SsaBuilder();
    return builder.buildSsa(this, parameters);
  }
}
