import 'dart:collection';

import '../../ir/cfg/control_flow_graph.dart';
import 'abstract_domain.dart';

/// Result of abstract interpretation analysis.
class AnalysisResult<D extends AbstractDomain<D>> {
  AnalysisResult({
    required this.entryStates,
    required this.exitStates,
    required this.iterations,
    required this.wideningApplied,
    this.narrowingApplied = false,
    this.narrowingIterations = 0,
  });

  /// Abstract state at the entry of each block.
  final Map<int, AbstractState<D>> entryStates;

  /// Abstract state at the exit of each block.
  final Map<int, AbstractState<D>> exitStates;

  /// Number of iterations to reach fixpoint.
  final int iterations;

  /// Whether widening was applied.
  final bool wideningApplied;

  /// Whether narrowing was applied after widening.
  final bool narrowingApplied;

  /// Number of narrowing iterations performed.
  final int narrowingIterations;

  /// Gets the abstract value of a variable at block entry.
  D? getValueAtEntry(int blockId, String variable) {
    return entryStates[blockId]?[variable];
  }

  /// Gets the abstract value of a variable at block exit.
  D? getValueAtExit(int blockId, String variable) {
    return exitStates[blockId]?[variable];
  }
}

/// Abstract interpreter using worklist algorithm with widening.
///
/// Performs forward dataflow analysis on CFG using abstract domains.
/// Supports interval analysis for integer variables and can be extended
/// for other domains.
class AbstractInterpreter<D extends AbstractDomain<D>> {
  AbstractInterpreter(
    this._defaultValue, {
    this.wideningThreshold = 3,
    this.maxIterations = 1000,
  });

  final D _defaultValue;

  /// Maximum iterations before forcing widening.
  final int wideningThreshold;

  /// Maximum total iterations before giving up.
  final int maxIterations;

  /// Tracks how many times each block has been visited (for widening).
  final Map<int, int> _blockVisitCount = {};

  /// Analyzes a CFG and returns the abstract state at each program point.
  AnalysisResult<D> analyze(ControlFlowGraph cfg) {
    final entryStates = <int, AbstractState<D>>{};
    final exitStates = <int, AbstractState<D>>{};
    var wideningApplied = false;
    var iterations = 0;

    // Initialize all blocks with bottom state
    for (final block in cfg.blocks) {
      entryStates[block.id] = AbstractState<D>(_defaultValue);
      exitStates[block.id] = AbstractState<D>(_defaultValue);
      _blockVisitCount[block.id] = 0;
    }

    // Worklist algorithm using Queue for O(1) dequeue
    final worklist = Queue<BasicBlock>()..add(cfg.entry);
    final inWorklist = <int>{cfg.entry.id};

    while (worklist.isNotEmpty && iterations < maxIterations) {
      iterations++;

      final block = worklist.removeFirst();
      inWorklist.remove(block.id);

      // Compute entry state by joining predecessor exit states
      AbstractState<D> entryState;
      if (block.predecessors.isEmpty) {
        entryState = AbstractState<D>(_defaultValue);
      } else {
        entryState = block.predecessors
            .map((p) => exitStates[p.id]!)
            .reduce((a, b) => a.join(b));
      }

      // Apply widening if we've visited this block too many times
      _blockVisitCount[block.id] = (_blockVisitCount[block.id] ?? 0) + 1;
      if (_blockVisitCount[block.id]! > wideningThreshold) {
        entryState = entryStates[block.id]!.widen(entryState);
        wideningApplied = true;
      }

      // Check if entry state changed
      final oldEntryState = entryStates[block.id]!;
      if (_statesEqual(entryState, oldEntryState) &&
          _blockVisitCount[block.id]! > 1) {
        continue; // No change, skip processing
      }

      entryStates[block.id] = entryState;

      // Transfer function: process instructions
      final exitState = _transferBlock(block, entryState);
      exitStates[block.id] = exitState;

      // Add successors to worklist
      for (final succ in block.successors) {
        if (!inWorklist.contains(succ.id)) {
          worklist.add(succ);
          inWorklist.add(succ.id);
        }
      }
    }

    // Apply narrowing phase to recover precision after widening
    var narrowingIterations = 0;
    var narrowingApplied = false;
    if (wideningApplied) {
      narrowingIterations = _applyNarrowing(cfg, entryStates, exitStates);
      narrowingApplied = narrowingIterations > 0;
    }

    return AnalysisResult(
      entryStates: entryStates,
      exitStates: exitStates,
      iterations: iterations,
      wideningApplied: wideningApplied,
      narrowingApplied: narrowingApplied,
      narrowingIterations: narrowingIterations,
    );
  }

  /// Applies narrowing iterations to recover precision after widening.
  ///
  /// Returns the number of narrowing iterations performed.
  int _applyNarrowing(
    ControlFlowGraph cfg,
    Map<int, AbstractState<D>> entryStates,
    Map<int, AbstractState<D>> exitStates,
  ) {
    const maxNarrowIterations = 10;
    var changed = true;
    var narrowIterations = 0;

    while (changed && narrowIterations < maxNarrowIterations) {
      changed = false;
      narrowIterations++;

      for (final block in cfg.reversePostOrder) {
        final oldEntry = entryStates[block.id]!;

        // Recompute entry from predecessors
        AbstractState<D> newEntry;
        if (block.predecessors.isEmpty) {
          newEntry = AbstractState<D>(_defaultValue);
        } else {
          newEntry = block.predecessors
              .map((p) => exitStates[p.id]!)
              .reduce((a, b) => a.join(b));
        }

        // Apply narrowing: old state narrowed with new computed state
        final narrowedEntry = oldEntry.narrow(newEntry);

        if (!_statesEqual(narrowedEntry, oldEntry)) {
          changed = true;
          entryStates[block.id] = narrowedEntry;
          exitStates[block.id] = _transferBlock(block, narrowedEntry);
        }
      }
    }

    return narrowIterations;
  }

  /// Transfer function for a basic block.
  AbstractState<D> _transferBlock(BasicBlock block, AbstractState<D> state) {
    var currentState = AbstractState<D>(
      _defaultValue,
      Map<String, D>.from(state.values),
    );

    for (final instr in block.instructions) {
      currentState = _transferInstruction(instr, currentState);
    }

    return currentState;
  }

  /// Transfer function for a single instruction.
  AbstractState<D> _transferInstruction(
    Instruction instr,
    AbstractState<D> state,
  ) {
    if (instr is AssignInstruction) {
      return _transferAssign(instr, state);
    }
    if (instr is PhiInstruction) {
      return _transferPhi(instr, state);
    }
    // Other instructions don't modify abstract state for interval analysis
    return state;
  }

  /// Transfer function for assignment.
  AbstractState<D> _transferAssign(
    AssignInstruction instr,
    AbstractState<D> state,
  ) {
    final newState = AbstractState<D>(
      _defaultValue,
      Map<String, D>.from(state.values),
    );

    final value = _evaluateValue(instr.value, state);
    newState[instr.target.toString()] = value;

    return newState;
  }

  /// Transfer function for phi instruction.
  AbstractState<D> _transferPhi(
    PhiInstruction instr,
    AbstractState<D> state,
  ) {
    final newState = AbstractState<D>(
      _defaultValue,
      Map<String, D>.from(state.values),
    );

    // Join all incoming values
    D result = _defaultValue.bottom;
    for (final operand in instr.operands.values) {
      final value = _evaluateValue(operand, state);
      result = result.join(value);
    }

    newState[instr.target.toString()] = result;

    return newState;
  }

  /// Evaluates a value expression in the abstract domain.
  D _evaluateValue(Value value, AbstractState<D> state) {
    if (value is ConstantValue) {
      return _evaluateConstant(value);
    }
    if (value is VariableValue) {
      return state[value.variable.toString()];
    }
    if (value is BinaryOpValue) {
      return _evaluateBinaryOp(value, state);
    }
    if (value is UnaryOpValue) {
      return _evaluateUnaryOp(value, state);
    }
    // Default to top for unknown values
    return _defaultValue.top;
  }

  /// Evaluates a constant value.
  D _evaluateConstant(ConstantValue constant) {
    if (_defaultValue is IntervalDomain && constant.value is int) {
      return IntervalDomain.constant(constant.value as int) as D;
    }
    return _defaultValue.top;
  }

  /// Evaluates a binary operation.
  D _evaluateBinaryOp(BinaryOpValue op, AbstractState<D> state) {
    final left = _evaluateValue(op.left, state);
    final right = _evaluateValue(op.right, state);

    // Handle IntervalDomain operations
    if (_defaultValue is IntervalDomain) {
      final leftInterval = left as IntervalDomain;
      final rightInterval = right as IntervalDomain;
      final IntervalDomain result = switch (op.operator) {
        '+' => leftInterval.add(rightInterval),
        '-' => leftInterval.subtract(rightInterval),
        '*' => leftInterval.multiply(rightInterval),
        '/' || '~/' => leftInterval.divide(rightInterval),
        '%' => leftInterval.modulo(rightInterval),
        _ => IntervalDomain.topValue,
      };
      return result as D;
    }

    return _defaultValue.top;
  }

  /// Evaluates a unary operation.
  D _evaluateUnaryOp(UnaryOpValue op, AbstractState<D> state) {
    final operand = _evaluateValue(op.operand, state);

    // Handle IntervalDomain operations
    if (_defaultValue is IntervalDomain) {
      final intervalOperand = operand as IntervalDomain;
      final IntervalDomain result = switch (op.operator) {
        '-' => IntervalDomain(
            intervalOperand.max != null ? -intervalOperand.max! : null,
            intervalOperand.min != null ? -intervalOperand.min! : null,
          ),
        _ => IntervalDomain.topValue,
      };
      return result as D;
    }

    return _defaultValue.top;
  }

  /// Checks if two states are equal.
  bool _statesEqual(AbstractState<D> a, AbstractState<D> b) {
    final allVars = <String>{...a.values.keys, ...b.values.keys};
    for (final v in allVars) {
      if (a[v] != b[v]) return false;
    }
    return true;
  }
}

/// Specialized interval analysis interpreter.
class IntervalAnalyzer extends AbstractInterpreter<IntervalDomain> {
  IntervalAnalyzer({
    super.wideningThreshold,
    super.maxIterations,
  }) : super(IntervalDomain.topValue);

  /// Convenience method to get interval at a specific program point.
  IntervalDomain? getIntervalAtBlockEntry(
    AnalysisResult<IntervalDomain> result,
    int blockId,
    String variable,
  ) {
    return result.getValueAtEntry(blockId, variable);
  }

  /// Checks if an array access is safe at a given program point.
  bool isArrayAccessSafe(
    AnalysisResult<IntervalDomain> result,
    int blockId,
    String indexVariable,
    int arrayLength,
  ) {
    final interval = result.getValueAtEntry(blockId, indexVariable);
    if (interval == null) return false;
    return interval.isValidArrayIndex(arrayLength);
  }
}
