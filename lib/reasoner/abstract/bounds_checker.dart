import '../../ir/cfg/control_flow_graph.dart';
import 'abstract_domain.dart';
import 'abstract_interpreter.dart';

/// Represents an array access location in the CFG.
class ArrayAccess {
  ArrayAccess({
    required this.blockId,
    required this.offset,
    required this.arrayVariable,
    required this.indexExpression,
    required this.instruction,
  });

  /// Block ID where the access occurs.
  final int blockId;

  /// Offset within the source file.
  final int offset;

  /// The array/list variable being accessed.
  final String arrayVariable;

  /// The index expression (variable name or constant).
  final String indexExpression;

  /// Instruction that performs the access.
  final Instruction instruction;

  @override
  String toString() =>
      'ArrayAccess($arrayVariable[$indexExpression] at block $blockId)';
}

/// Result of bounds checking for a single array access.
class BoundsCheckResult {
  BoundsCheckResult({
    required this.access,
    required this.isSafe,
    required this.isDefinitelyUnsafe,
    this.indexInterval,
    this.arrayLength,
    required this.reason,
  });

  /// The array access being checked.
  final ArrayAccess access;

  /// Whether the access is provably safe.
  final bool isSafe;

  /// Whether the access is provably unsafe.
  final bool isDefinitelyUnsafe;

  /// The computed index interval.
  final IntervalDomain? indexInterval;

  /// The known array length (if available).
  final int? arrayLength;

  /// Human-readable reason for the result.
  final String reason;

  /// Access is unknown (neither provably safe nor unsafe).
  bool get isUnknown => !isSafe && !isDefinitelyUnsafe;

  @override
  String toString() {
    final status = isSafe
        ? 'SAFE'
        : isDefinitelyUnsafe
            ? 'UNSAFE'
            : 'UNKNOWN';
    return 'BoundsCheck[$status]: ${access.arrayVariable}[${access.indexExpression}] - $reason';
  }
}

/// Array bounds checker using interval analysis.
///
/// Analyzes CFG to find array accesses and verifies that indices
/// are within valid bounds using interval domain abstract interpretation.
class BoundsChecker {
  final IntervalAnalyzer _analyzer = IntervalAnalyzer();

  /// Known array lengths for variables.
  final Map<String, int> _arrayLengths = {};

  /// Registers the length of an array variable.
  void registerArrayLength(String variable, int length) {
    _arrayLengths[variable] = length;
  }

  /// Checks all array accesses in a CFG.
  List<BoundsCheckResult> checkCfg(ControlFlowGraph cfg) {
    // Run interval analysis
    final analysisResult = _analyzer.analyze(cfg);

    // Find all array accesses
    final accesses = _findArrayAccesses(cfg);

    // Check each access
    return accesses.map((access) {
      return _checkAccess(access, analysisResult);
    }).toList();
  }

  /// Finds all array/index accesses in the CFG.
  List<ArrayAccess> _findArrayAccesses(ControlFlowGraph cfg) {
    final accesses = <ArrayAccess>[];

    for (final block in cfg.blocks) {
      for (final instr in block.instructions) {
        final access = _extractArrayAccess(block.id, instr);
        if (access != null) {
          accesses.add(access);
        }
      }
    }

    return accesses;
  }

  /// Extracts array access information from an instruction.
  ArrayAccess? _extractArrayAccess(int blockId, Instruction instr) {
    if (instr is LoadIndexInstruction) {
      return ArrayAccess(
        blockId: blockId,
        offset: instr.offset,
        arrayVariable: _valueToString(instr.base),
        indexExpression: _valueToString(instr.index),
        instruction: instr,
      );
    }

    if (instr is StoreIndexInstruction) {
      return ArrayAccess(
        blockId: blockId,
        offset: instr.offset,
        arrayVariable: _valueToString(instr.base),
        indexExpression: _valueToString(instr.index),
        instruction: instr,
      );
    }

    // Check for IndexAccessValue in assignments
    if (instr is AssignInstruction && instr.value is IndexAccessValue) {
      final indexAccess = instr.value as IndexAccessValue;
      return ArrayAccess(
        blockId: blockId,
        offset: instr.offset,
        arrayVariable: _valueToString(indexAccess.receiver),
        indexExpression: _valueToString(indexAccess.index),
        instruction: instr,
      );
    }

    return null;
  }

  String _valueToString(Value value) {
    if (value is VariableValue) {
      return value.variable.toString();
    }
    if (value is ConstantValue) {
      return value.value?.toString() ?? 'null';
    }
    return value.toString();
  }

  /// Checks a single array access.
  BoundsCheckResult _checkAccess(
    ArrayAccess access,
    AnalysisResult<IntervalDomain> analysisResult,
  ) {
    // Get the index interval at this program point
    final indexInterval = _getIndexInterval(access, analysisResult);

    // Get the array length if known
    final arrayLength = _arrayLengths[access.arrayVariable];

    if (indexInterval == null) {
      return BoundsCheckResult(
        access: access,
        isSafe: false,
        isDefinitelyUnsafe: false,
        reason: 'Could not determine index interval',
      );
    }

    if (indexInterval.isBottom) {
      return BoundsCheckResult(
        access: access,
        isSafe: true,
        isDefinitelyUnsafe: false,
        indexInterval: indexInterval,
        arrayLength: arrayLength,
        reason: 'Unreachable code (bottom state)',
      );
    }

    // Check if index is definitely negative
    if (indexInterval.max != null && indexInterval.max! < 0) {
      return BoundsCheckResult(
        access: access,
        isSafe: false,
        isDefinitelyUnsafe: true,
        indexInterval: indexInterval,
        arrayLength: arrayLength,
        reason: 'Index is definitely negative: $indexInterval',
      );
    }

    // Check if we can verify against known array length
    if (arrayLength != null) {
      if (indexInterval.isValidArrayIndex(arrayLength)) {
        return BoundsCheckResult(
          access: access,
          isSafe: true,
          isDefinitelyUnsafe: false,
          indexInterval: indexInterval,
          arrayLength: arrayLength,
          reason: 'Index $indexInterval is within bounds [0, ${arrayLength - 1}]',
        );
      }

      // Check if definitely out of bounds
      if (indexInterval.min != null && indexInterval.min! >= arrayLength) {
        return BoundsCheckResult(
          access: access,
          isSafe: false,
          isDefinitelyUnsafe: true,
          indexInterval: indexInterval,
          arrayLength: arrayLength,
          reason:
              'Index $indexInterval is definitely >= array length $arrayLength',
        );
      }
    }

    // Check if index is at least non-negative
    if (indexInterval.min != null && indexInterval.min! >= 0) {
      if (arrayLength == null) {
        return BoundsCheckResult(
          access: access,
          isSafe: false,
          isDefinitelyUnsafe: false,
          indexInterval: indexInterval,
          reason:
              'Index $indexInterval is non-negative but array length unknown',
        );
      }
    }

    return BoundsCheckResult(
      access: access,
      isSafe: false,
      isDefinitelyUnsafe: false,
      indexInterval: indexInterval,
      arrayLength: arrayLength,
      reason: 'Could not prove safety: index=$indexInterval, length=$arrayLength',
    );
  }

  /// Gets the interval for an index expression.
  IntervalDomain? _getIndexInterval(
    ArrayAccess access,
    AnalysisResult<IntervalDomain> analysisResult,
  ) {
    // Try to parse as constant
    final constValue = int.tryParse(access.indexExpression);
    if (constValue != null) {
      return IntervalDomain.constant(constValue);
    }

    // Look up variable in analysis result
    // Use exit state because assignment might be in the same block
    return analysisResult.getValueAtExit(
      access.blockId,
      access.indexExpression,
    );
  }
}

/// Summary of bounds checking results for a function.
class BoundsCheckSummary {
  BoundsCheckSummary({
    required this.functionName,
    required this.results,
  });

  final String functionName;
  final List<BoundsCheckResult> results;

  /// Number of provably safe accesses.
  int get safeCount => results.where((r) => r.isSafe).length;

  /// Number of provably unsafe accesses.
  int get unsafeCount => results.where((r) => r.isDefinitelyUnsafe).length;

  /// Number of unknown accesses.
  int get unknownCount => results.where((r) => r.isUnknown).length;

  /// Total number of array accesses.
  int get totalCount => results.length;

  /// Percentage of provably safe accesses.
  double get safePercentage =>
      totalCount > 0 ? (safeCount / totalCount) * 100 : 0;

  /// All unsafe access results.
  List<BoundsCheckResult> get unsafeAccesses =>
      results.where((r) => r.isDefinitelyUnsafe).toList();

  @override
  String toString() {
    return '''
BoundsCheckSummary for $functionName:
  Total accesses: $totalCount
  Safe: $safeCount (${safePercentage.toStringAsFixed(1)}%)
  Unsafe: $unsafeCount
  Unknown: $unknownCount
''';
  }
}
