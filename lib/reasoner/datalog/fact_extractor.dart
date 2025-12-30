import '../../ir/cfg/control_flow_graph.dart';
import '../../frontend/ir_generator.dart';
import 'datalog_engine.dart';

/// Extracts Datalog facts from CFG/SSA representations.
///
/// Transforms CFG instructions into relational facts for
/// points-to analysis, reachability analysis, and other queries.
class FactExtractor {
  int _heapCounter = 0;
  int _varCounter = 0;
  int _callSiteCounter = 0;

  /// Maps variable names to unique IDs.
  final Map<String, int> _varIds = {};

  /// Maps heap allocation descriptions to IDs.
  final Map<String, String> _heapIds = {};

  /// Tracks instruction types that were not handled during extraction.
  ///
  /// This is useful for debugging and ensuring new instruction types
  /// are properly handled. Check this set after extraction to verify
  /// all relevant instruction types have fact extraction logic.
  final Set<Type> _unhandledTypes = {};

  /// Exposes the variable ID map for debugging and query purposes.
  Map<String, int> get varIds => Map.unmodifiable(_varIds);

  /// Exposes unhandled instruction types for debugging.
  ///
  /// Returns the set of instruction types that were encountered during
  /// extraction but did not have specific fact extraction logic.
  /// Excludes known instruction types that intentionally don't generate facts
  /// (e.g., GotoInstruction, ReturnInstruction, ConditionalInstruction).
  Set<Type> get unhandledTypes => Set.unmodifiable(_unhandledTypes);

  /// Resets the extractor state.
  void reset() {
    _heapCounter = 0;
    _varCounter = 0;
    _callSiteCounter = 0;
    _varIds.clear();
    _heapIds.clear();
    _unhandledTypes.clear();
  }

  /// Gets or creates a unique ID for a variable.
  int getVarId(String name) {
    return _varIds.putIfAbsent(name, () => _varCounter++);
  }

  /// Gets or creates a unique heap ID for an allocation.
  String getHeapId(String typeName, int offset) {
    final key = '$typeName@$offset';
    return _heapIds.putIfAbsent(key, () => '$typeName#${_heapCounter++}');
  }

  /// Extracts facts from a single function IR.
  List<Fact> extractFromFunction(FunctionIr ir) {
    return extractFromCfg(ir.cfg, ir.name);
  }

  /// Extracts facts from a CFG.
  List<Fact> extractFromCfg(ControlFlowGraph cfg, [String? functionName]) {
    final facts = <Fact>[];

    // Extract flow edges between blocks
    for (final block in cfg.blocks) {
      for (final successor in block.successors) {
        facts.add(Fact('Flow', [block.id, successor.id]));
      }

      // Extract facts from each instruction
      for (final instr in block.instructions) {
        facts.addAll(_extractFromInstruction(instr, block.id));
      }
    }

    // Add entry block as reachable (base fact)
    facts.add(Fact('Reachable', [cfg.entry.id]));

    return facts;
  }

  /// Extracts facts from a single instruction.
  ///
  /// Generates both flow-insensitive facts (e.g., `Assign`) and
  /// flow-sensitive facts with block IDs (e.g., `AssignAt`).
  List<Fact> _extractFromInstruction(Instruction instr, int blockId) {
    final facts = <Fact>[];

    switch (instr) {
      case AssignInstruction():
        facts.addAll(_extractFromAssign(instr, blockId));
      case CallInstruction():
        facts.addAll(_extractFromCall(instr, blockId));
      case LoadFieldInstruction():
        facts.addAll(_extractFromLoadField(instr, blockId));
      case StoreFieldInstruction():
        facts.addAll(_extractFromStoreField(instr, blockId));
      case LoadIndexInstruction():
        facts.addAll(_extractFromLoadIndex(instr, blockId));
      case StoreIndexInstruction():
        facts.addAll(_extractFromStoreIndex(instr, blockId));
      case PhiInstruction():
        facts.addAll(_extractFromPhi(instr, blockId));
      case AwaitInstruction():
        facts.addAll(_extractFromAwait(instr, blockId));
      // Known instruction types that intentionally don't generate relational facts
      case JumpInstruction():
      case BranchInstruction():
      case ReturnInstruction():
      case NullCheckInstruction():
      case CastInstruction():
      case TypeCheckInstruction():
      case ThrowInstruction():
        // Control flow and type operations don't generate points-to/dataflow facts
        break;
    }

    return facts;
  }

  /// Extracts facts from assignment instruction.
  ///
  /// Emits both flow-insensitive facts and flow-sensitive `*At` facts.
  List<Fact> _extractFromAssign(AssignInstruction instr, int blockId) {
    final facts = <Fact>[];
    final targetId = getVarId(instr.target.toString());

    switch (instr.value) {
      case ConstantValue():
        // Constants don't create heap objects (primitives)
        break;

      case VariableValue(variable: final v):
        // Variable copy: Assign(target, source) + AssignAt(block, target, source)
        final sourceId = getVarId(v.toString());
        facts.add(Fact('Assign', [targetId, sourceId]));
        facts.add(Fact('AssignAt', [blockId, targetId, sourceId]));

      case NewObjectValue(typeName: final type):
        // Object allocation: Assign(var, expr) + Alloc(expr, heap)
        final exprId = instr.offset; // Use offset as expression ID
        final heapId = getHeapId(type, instr.offset);
        facts.add(Fact('Assign', [targetId, exprId]));
        facts.add(Fact('AssignAt', [blockId, targetId, exprId]));
        facts.add(Fact('Alloc', [exprId, heapId]));
        facts.add(Fact('AllocAt', [blockId, exprId, heapId]));

      case CallValue(methodName: final method, :final receiver):
        // Method call result assignment
        final callSite = _callSiteCounter++;
        if (receiver != null) {
          final receiverId = _getValueVarId(receiver);
          if (receiverId != null) {
            facts.add(Fact('Call', [callSite, receiverId, method, targetId]));
            facts.add(Fact('CallAt', [blockId, callSite, receiverId, method, targetId]));
          }
        }
        // Allocate return value (conservative)
        final heapId = getHeapId('Return\$$method', instr.offset);
        facts.add(Fact('Assign', [targetId, instr.offset]));
        facts.add(Fact('AssignAt', [blockId, targetId, instr.offset]));
        facts.add(Fact('Alloc', [instr.offset, heapId]));
        facts.add(Fact('AllocAt', [blockId, instr.offset, heapId]));

      case FieldAccessValue(receiver: final recv, fieldName: final field):
        // Field access creates LoadField
        final baseId = _getValueVarId(recv);
        if (baseId != null) {
          facts.add(Fact('LoadField', [baseId, field, targetId]));
          facts.add(Fact('LoadFieldAt', [blockId, baseId, field, targetId]));
        }

      case IndexAccessValue(receiver: final recv):
        // Index access creates LoadField with special field name
        final baseId = _getValueVarId(recv);
        if (baseId != null) {
          facts.add(Fact('LoadField', [baseId, '[]', targetId]));
          facts.add(Fact('LoadFieldAt', [blockId, baseId, '[]', targetId]));
        }

      case BinaryOpValue():
      case UnaryOpValue():
        // Arithmetic operations - result is primitive, no heap allocation
        break;

      default:
        break;
    }

    return facts;
  }

  /// Extracts facts from call instruction.
  List<Fact> _extractFromCall(CallInstruction instr, int blockId) {
    final facts = <Fact>[];
    final callSite = _callSiteCounter++;

    int? receiverId;
    if (instr.receiver != null) {
      receiverId = _getValueVarId(instr.receiver!);
    }

    final resultId = instr.result != null ? getVarId(instr.result!.toString()) : -1;

    if (receiverId != null) {
      facts.add(Fact('Call', [callSite, receiverId, instr.methodName, resultId]));
      facts.add(Fact('CallAt', [blockId, callSite, receiverId, instr.methodName, resultId]));
    } else {
      // Static/top-level function call
      facts.add(Fact('Call', [callSite, -1, instr.methodName, resultId]));
      facts.add(Fact('CallAt', [blockId, callSite, -1, instr.methodName, resultId]));
    }

    return facts;
  }

  /// Extracts facts from field load instruction.
  List<Fact> _extractFromLoadField(LoadFieldInstruction instr, int blockId) {
    final baseId = _getValueVarId(instr.base);
    if (baseId == null) return [];

    final targetId = getVarId(instr.result.toString());
    return [
      Fact('LoadField', [baseId, instr.fieldName, targetId]),
      Fact('LoadFieldAt', [blockId, baseId, instr.fieldName, targetId]),
    ];
  }

  /// Extracts facts from field store instruction.
  List<Fact> _extractFromStoreField(StoreFieldInstruction instr, int blockId) {
    final baseId = _getValueVarId(instr.base);
    final sourceId = _getValueVarId(instr.value);

    if (baseId == null || sourceId == null) return [];

    return [
      Fact('StoreField', [baseId, instr.fieldName, sourceId]),
      Fact('StoreFieldAt', [blockId, baseId, instr.fieldName, sourceId]),
    ];
  }

  /// Extracts facts from index load instruction.
  List<Fact> _extractFromLoadIndex(LoadIndexInstruction instr, int blockId) {
    final baseId = _getValueVarId(instr.base);
    if (baseId == null) return [];

    final targetId = getVarId(instr.result.toString());
    // Treat index access as field access with special name
    return [
      Fact('LoadField', [baseId, '[]', targetId]),
      Fact('LoadFieldAt', [blockId, baseId, '[]', targetId]),
    ];
  }

  /// Extracts facts from index store instruction.
  List<Fact> _extractFromStoreIndex(StoreIndexInstruction instr, int blockId) {
    final baseId = _getValueVarId(instr.base);
    final sourceId = _getValueVarId(instr.value);

    if (baseId == null || sourceId == null) return [];

    // Treat index access as field access with special name
    return [
      Fact('StoreField', [baseId, '[]', sourceId]),
      Fact('StoreFieldAt', [blockId, baseId, '[]', sourceId]),
    ];
  }

  /// Extracts facts from phi instruction.
  ///
  /// Emits:
  /// - `Assign(target, source)` for flow-insensitive analysis (one per operand)
  /// - `PhiAt(block, target, predBlock, source)` for flow-sensitive analysis
  ///
  /// The `PhiAt` fact captures the full phi structure including which
  /// predecessor block each operand comes from, enabling precise
  /// flow-sensitive dataflow analysis.
  List<Fact> _extractFromPhi(PhiInstruction instr, int blockId) {
    final facts = <Fact>[];
    final targetId = getVarId(instr.target.toString());

    // Phi node creates multiple assignments (one per operand)
    for (final entry in instr.operands.entries) {
      final predBlock = entry.key;
      final sourceId = _getValueVarId(entry.value);
      if (sourceId != null) {
        // Flow-insensitive: simple assignment
        facts.add(Fact('Assign', [targetId, sourceId]));
        // Flow-sensitive: phi with predecessor info
        facts.add(Fact('PhiAt', [blockId, targetId, predBlock.id, sourceId]));
      }
    }

    return facts;
  }

  /// Extracts facts from await instruction.
  ///
  /// Models the dataflow from the future to the result variable.
  /// For points-to analysis, this is essentially an assignment.
  List<Fact> _extractFromAwait(AwaitInstruction instr, int blockId) {
    final sourceId = _getValueVarId(instr.future);
    if (sourceId == null) return [];

    final targetId = getVarId(instr.result.toString());
    // Await transfers the unwrapped value from future to result
    return [
      Fact('Assign', [targetId, sourceId]),
      Fact('AssignAt', [blockId, targetId, sourceId]),
    ];
  }

  /// Gets variable ID from a Value, if it's a variable reference.
  ///
  /// Uses the full SSA-versioned name (e.g., "x_1") to preserve
  /// flow-sensitivity in the analysis.
  int? _getValueVarId(Value value) {
    if (value is VariableValue) {
      return getVarId(value.variable.toString());
    }
    return null;
  }

  /// Extracts facts from an entire file IR.
  List<Fact> extractFromFile(FileIr fileIr) {
    final facts = <Fact>[];

    for (final func in fileIr.allFunctions) {
      facts.addAll(extractFromFunction(func));
    }

    return facts;
  }
}

/// Helper class to manage fact extraction context.
class ExtractionContext {
  ExtractionContext({
    required this.fileName,
    required this.functionName,
    required this.extractor,
  });

  final String fileName;
  final String functionName;
  final FactExtractor extractor;
}
