import '../../ir/cfg/control_flow_graph.dart';
import 'abstract_domain.dart';

/// Represents a potential null dereference location.
class NullDereference {
  /// Block ID where the dereference occurs.
  final int blockId;

  /// Offset within the source file.
  final int offset;

  /// The variable being dereferenced.
  final String variable;

  /// Type of dereference (method call, field access, etc.).
  final DereferenceType type;

  /// The instruction performing the dereference.
  final Instruction instruction;

  NullDereference({
    required this.blockId,
    required this.offset,
    required this.variable,
    required this.type,
    required this.instruction,
  });

  @override
  String toString() =>
      'NullDereference($variable.$type at block $blockId, offset $offset)';
}

/// Types of dereferences that can cause null pointer exceptions.
enum DereferenceType {
  methodCall,
  fieldAccess,
  indexAccess,
  nullBang, // The ! operator
}

/// Result of null safety verification for a single dereference.
class NullCheckResult {
  /// The dereference being checked.
  final NullDereference dereference;

  /// Whether the dereference is provably safe (non-null).
  final bool isSafe;

  /// Whether the dereference is definitely null (will throw).
  final bool isDefinitelyNull;

  /// The nullability state at this point.
  final NullabilityDomain? nullability;

  /// Human-readable reason for the result.
  final String reason;

  NullCheckResult({
    required this.dereference,
    required this.isSafe,
    required this.isDefinitelyNull,
    this.nullability,
    required this.reason,
  });

  /// Unknown: neither provably safe nor definitely null.
  bool get isUnknown => !isSafe && !isDefinitelyNull;

  @override
  String toString() {
    final status = isSafe
        ? 'SAFE'
        : isDefinitelyNull
            ? 'NULL'
            : 'UNKNOWN';
    return 'NullCheck[$status]: ${dereference.variable} - $reason';
  }
}

/// Null safety verifier using nullability analysis.
///
/// Analyzes CFG to find potential null dereferences and verifies
/// that variables are non-null at dereference points.
class NullVerifier {
  /// Analysis state for each block.
  final Map<int, AbstractState<NullabilityDomain>> _entryStates = {};
  final Map<int, AbstractState<NullabilityDomain>> _exitStates = {};

  /// Known nullable variables.
  final Set<String> _nullableVariables = {};

  /// Known non-null variables.
  final Set<String> _nonNullVariables = {};

  /// Registers a variable as nullable.
  void registerNullable(String variable) {
    _nullableVariables.add(variable);
  }

  /// Registers a variable as non-null.
  void registerNonNull(String variable) {
    _nonNullVariables.add(variable);
  }

  /// Verifies null safety for all dereferences in a CFG.
  List<NullCheckResult> verifyCfg(ControlFlowGraph cfg) {
    // Run nullability analysis
    _analyzeNullability(cfg);

    // Find all dereferences
    final dereferences = _findDereferences(cfg);

    // Check each dereference
    return dereferences.map((deref) {
      return _checkDereference(deref);
    }).toList();
  }

  /// Performs nullability analysis on the CFG.
  void _analyzeNullability(ControlFlowGraph cfg) {
    final defaultValue = NullabilityDomain.topValue;

    // Initialize all blocks
    for (final block in cfg.blocks) {
      _entryStates[block.id] = AbstractState<NullabilityDomain>(defaultValue);
      _exitStates[block.id] = AbstractState<NullabilityDomain>(defaultValue);
    }

    // Worklist algorithm
    final worklist = <BasicBlock>[cfg.entry];
    final inWorklist = <int>{cfg.entry.id};
    var iterations = 0;
    const maxIterations = 1000;

    while (worklist.isNotEmpty && iterations < maxIterations) {
      iterations++;

      final block = worklist.removeAt(0);
      inWorklist.remove(block.id);

      // Compute entry state
      AbstractState<NullabilityDomain> entryState;
      if (block.predecessors.isEmpty) {
        entryState = _createInitialState();
      } else {
        entryState = block.predecessors
            .map((p) => _exitStates[p.id]!)
            .reduce((a, b) => a.join(b));
      }

      _entryStates[block.id] = entryState;

      // Transfer function
      final exitState = _transferBlock(block, entryState);

      // Check if state changed
      final oldExitState = _exitStates[block.id]!;
      if (!_statesChanged(oldExitState, exitState)) {
        continue;
      }

      _exitStates[block.id] = exitState;

      // Add successors
      for (final succ in block.successors) {
        if (!inWorklist.contains(succ.id)) {
          worklist.add(succ);
          inWorklist.add(succ.id);
        }
      }
    }
  }

  /// Creates the initial state at function entry.
  AbstractState<NullabilityDomain> _createInitialState() {
    final state = AbstractState<NullabilityDomain>(NullabilityDomain.topValue);

    // Set known nullable variables
    for (final v in _nullableVariables) {
      state[v] = NullabilityDomain.topValue; // maybeNull
    }

    // Set known non-null variables
    for (final v in _nonNullVariables) {
      state[v] = NullabilityDomain.nonNullValue;
    }

    return state;
  }

  /// Transfer function for a block.
  AbstractState<NullabilityDomain> _transferBlock(
    BasicBlock block,
    AbstractState<NullabilityDomain> state,
  ) {
    var currentState = AbstractState<NullabilityDomain>(
      NullabilityDomain.topValue,
      Map.from(state.values),
    );

    for (final instr in block.instructions) {
      currentState = _transferInstruction(instr, currentState, block);
    }

    return currentState;
  }

  /// Transfer function for a single instruction.
  AbstractState<NullabilityDomain> _transferInstruction(
    Instruction instr,
    AbstractState<NullabilityDomain> state,
    BasicBlock block,
  ) {
    if (instr is AssignInstruction) {
      final newState = AbstractState<NullabilityDomain>(
        NullabilityDomain.topValue,
        Map.from(state.values),
      );

      final nullability = _evaluateNullability(instr.value, state);
      newState[instr.target.toString()] = nullability;

      return newState;
    }

    if (instr is NullCheckInstruction) {
      // After null check (!), the value is definitely non-null
      final newState = AbstractState<NullabilityDomain>(
        NullabilityDomain.topValue,
        Map.from(state.values),
      );

      newState[instr.result.toString()] = NullabilityDomain.nonNullValue;

      return newState;
    }

    if (instr is PhiInstruction) {
      final newState = AbstractState<NullabilityDomain>(
        NullabilityDomain.topValue,
        Map.from(state.values),
      );

      // Join all incoming nullabilities
      NullabilityDomain result = NullabilityDomain.bottomValue;
      for (final operand in instr.operands.values) {
        final nullability = _evaluateNullability(operand, state);
        result = result.join(nullability);
      }

      newState[instr.target.toString()] = result;

      return newState;
    }

    // Handle branch instruction for null checks
    // This would need conditional state refinement
    // For now, we handle it in a simplified way

    return state;
  }

  /// Evaluates the nullability of a value.
  NullabilityDomain _evaluateNullability(
    Value value,
    AbstractState<NullabilityDomain> state,
  ) {
    if (value is ConstantValue) {
      if (value.value == null) {
        return NullabilityDomain.nullValue;
      }
      return NullabilityDomain.nonNullValue;
    }

    if (value is VariableValue) {
      return state[value.variable.toString()];
    }

    if (value is NewObjectValue) {
      // New objects are never null
      return NullabilityDomain.nonNullValue;
    }

    if (value is CallValue) {
      // Method calls could return null - assume maybeNull
      return NullabilityDomain.topValue;
    }

    if (value is FieldAccessValue) {
      // Field access could be null
      return NullabilityDomain.topValue;
    }

    // Default to maybeNull for unknown values
    return NullabilityDomain.topValue;
  }

  bool _statesChanged(
    AbstractState<NullabilityDomain> a,
    AbstractState<NullabilityDomain> b,
  ) {
    final allVars = {...a.values.keys, ...b.values.keys};
    for (final v in allVars) {
      if (a[v] != b[v]) return true;
    }
    return false;
  }

  /// Finds all dereference points in the CFG.
  List<NullDereference> _findDereferences(ControlFlowGraph cfg) {
    final dereferences = <NullDereference>[];

    for (final block in cfg.blocks) {
      for (final instr in block.instructions) {
        dereferences.addAll(_extractDereferences(block.id, instr));
      }
    }

    return dereferences;
  }

  /// Extracts dereferences from an instruction.
  List<NullDereference> _extractDereferences(int blockId, Instruction instr) {
    final result = <NullDereference>[];

    if (instr is CallInstruction && instr.receiver != null) {
      final receiverName = _valueToVariableName(instr.receiver!);
      if (receiverName != null) {
        result.add(NullDereference(
          blockId: blockId,
          offset: instr.offset,
          variable: receiverName,
          type: DereferenceType.methodCall,
          instruction: instr,
        ));
      }
    }

    if (instr is LoadFieldInstruction) {
      final baseName = _valueToVariableName(instr.base);
      if (baseName != null) {
        result.add(NullDereference(
          blockId: blockId,
          offset: instr.offset,
          variable: baseName,
          type: DereferenceType.fieldAccess,
          instruction: instr,
        ));
      }
    }

    if (instr is StoreFieldInstruction) {
      final baseName = _valueToVariableName(instr.base);
      if (baseName != null) {
        result.add(NullDereference(
          blockId: blockId,
          offset: instr.offset,
          variable: baseName,
          type: DereferenceType.fieldAccess,
          instruction: instr,
        ));
      }
    }

    if (instr is LoadIndexInstruction) {
      final baseName = _valueToVariableName(instr.base);
      if (baseName != null) {
        result.add(NullDereference(
          blockId: blockId,
          offset: instr.offset,
          variable: baseName,
          type: DereferenceType.indexAccess,
          instruction: instr,
        ));
      }
    }

    if (instr is NullCheckInstruction) {
      final operandName = _valueToVariableName(instr.operand);
      if (operandName != null) {
        result.add(NullDereference(
          blockId: blockId,
          offset: instr.offset,
          variable: operandName,
          type: DereferenceType.nullBang,
          instruction: instr,
        ));
      }
    }

    // Check values in assignments
    if (instr is AssignInstruction) {
      result.addAll(_extractValueDereferences(blockId, instr.offset, instr.value));
    }

    return result;
  }

  /// Extracts dereferences from a value expression.
  List<NullDereference> _extractValueDereferences(
    int blockId,
    int offset,
    Value value,
  ) {
    final result = <NullDereference>[];

    if (value is CallValue && value.receiver != null) {
      final receiverName = _valueToVariableName(value.receiver!);
      if (receiverName != null) {
        result.add(NullDereference(
          blockId: blockId,
          offset: offset,
          variable: receiverName,
          type: DereferenceType.methodCall,
          instruction: AssignInstruction(
            offset: offset,
            target: Variable('_dummy'),
            value: value,
          ),
        ));
      }
    }

    if (value is FieldAccessValue) {
      final baseName = _valueToVariableName(value.receiver);
      if (baseName != null) {
        result.add(NullDereference(
          blockId: blockId,
          offset: offset,
          variable: baseName,
          type: DereferenceType.fieldAccess,
          instruction: AssignInstruction(
            offset: offset,
            target: Variable('_dummy'),
            value: value,
          ),
        ));
      }
    }

    if (value is IndexAccessValue) {
      final baseName = _valueToVariableName(value.receiver);
      if (baseName != null) {
        result.add(NullDereference(
          blockId: blockId,
          offset: offset,
          variable: baseName,
          type: DereferenceType.indexAccess,
          instruction: AssignInstruction(
            offset: offset,
            target: Variable('_dummy'),
            value: value,
          ),
        ));
      }
    }

    return result;
  }

  String? _valueToVariableName(Value value) {
    if (value is VariableValue) {
      return value.variable.toString();
    }
    return null;
  }

  /// Checks a single dereference.
  NullCheckResult _checkDereference(NullDereference deref) {
    // Use exit state because assignment might be in the same block before dereference
    final nullability = _exitStates[deref.blockId]?[deref.variable];

    if (nullability == null) {
      return NullCheckResult(
        dereference: deref,
        isSafe: false,
        isDefinitelyNull: false,
        reason: 'Could not determine nullability',
      );
    }

    if (nullability.isBottom) {
      return NullCheckResult(
        dereference: deref,
        isSafe: true,
        isDefinitelyNull: false,
        nullability: nullability,
        reason: 'Unreachable code',
      );
    }

    if (nullability.isDefinitelyNonNull) {
      return NullCheckResult(
        dereference: deref,
        isSafe: true,
        isDefinitelyNull: false,
        nullability: nullability,
        reason: 'Variable is definitely non-null',
      );
    }

    if (nullability.isDefinitelyNull) {
      return NullCheckResult(
        dereference: deref,
        isSafe: false,
        isDefinitelyNull: true,
        nullability: nullability,
        reason: 'Variable is definitely null - will throw!',
      );
    }

    return NullCheckResult(
      dereference: deref,
      isSafe: false,
      isDefinitelyNull: false,
      nullability: nullability,
      reason: 'Variable may be null',
    );
  }
}

/// Summary of null safety verification results.
class NullSafetySummary {
  final String functionName;
  final List<NullCheckResult> results;

  NullSafetySummary({
    required this.functionName,
    required this.results,
  });

  /// Number of provably safe dereferences.
  int get safeCount => results.where((r) => r.isSafe).length;

  /// Number of definitely null dereferences.
  int get nullCount => results.where((r) => r.isDefinitelyNull).length;

  /// Number of unknown dereferences.
  int get unknownCount => results.where((r) => r.isUnknown).length;

  /// Total number of dereferences.
  int get totalCount => results.length;

  /// All potentially unsafe results (definitely null or unknown).
  List<NullCheckResult> get potentialNullDereferences =>
      results.where((r) => !r.isSafe).toList();

  /// All definitely null dereferences.
  List<NullCheckResult> get definiteNullDereferences =>
      results.where((r) => r.isDefinitelyNull).toList();

  @override
  String toString() {
    return '''
NullSafetySummary for $functionName:
  Total dereferences: $totalCount
  Safe: $safeCount
  Definitely null: $nullCount
  Unknown: $unknownCount
''';
  }
}
