import 'package:analyzer/dart/ast/ast.dart';

import 'control_flow_graph.dart';

/// Builds a Control Flow Graph from a Dart AST.
///
/// Uses the visitor pattern to traverse AST nodes and construct
/// a graph of basic blocks connected by control flow edges.
class CfgBuilder {
  int _blockIdCounter = 0;
  int _tempVarCounter = 0;

  /// Current block being built.
  BasicBlock? _currentBlock;

  /// All blocks in the CFG.
  final List<BasicBlock> _blocks = [];

  /// Exit block for the function.
  BasicBlock? _exitBlock;

  /// Stack for loop continue targets.
  final List<BasicBlock> _continueTargets = [];

  /// Stack for loop break targets.
  final List<BasicBlock> _breakTargets = [];

  /// Builds a CFG from a function declaration.
  ControlFlowGraph buildFromFunction(FunctionDeclaration node) {
    return _build(node.name.lexeme, node.functionExpression.body);
  }

  /// Builds a CFG from a method declaration.
  ControlFlowGraph buildFromMethod(MethodDeclaration node) {
    return _build(node.name.lexeme, node.body);
  }

  /// Builds a CFG from a constructor declaration.
  ///
  /// Handles field initializers by generating StoreFieldInstruction
  /// for each ConstructorFieldInitializer, with 'this' as the base.
  /// Super/redirect constructor calls are modeled as CallInstruction.
  ControlFlowGraph buildFromConstructor(
    ConstructorDeclaration node,
    String className,
  ) {
    _reset();

    final constructorName = node.name?.lexeme;
    final name = constructorName != null
        ? '$className.$constructorName'
        : '$className.<constructor>';

    final entry = _createBlock();
    _exitBlock = _createBlock();
    _currentBlock = entry;

    // Process initializers first (field initializers, super calls, etc.)
    for (final initializer in node.initializers) {
      _processInitializer(initializer);
    }

    // Process constructor body
    final body = node.body;
    if (body is BlockFunctionBody) {
      _visitBlock(body.block);
    } else if (body is ExpressionFunctionBody) {
      final value = _evaluateExpression(body.expression);
      _addInstruction(ReturnInstruction(
        offset: body.expression.offset,
        value: value,
      ));
    }

    // Connect last block to exit if not already terminated
    if (_currentBlock != null && !_isTerminated(_currentBlock!)) {
      _addInstruction(ReturnInstruction(offset: node.offset));
      _currentBlock!.connectTo(_exitBlock!);
    }

    return ControlFlowGraph(
      functionName: name,
      entry: entry,
      blocks: _blocks,
    );
  }

  /// Processes a constructor initializer.
  void _processInitializer(ConstructorInitializer initializer) {
    switch (initializer) {
      case ConstructorFieldInitializer():
        // Field initialization: this.field = value
        final value = _evaluateExpression(initializer.expression);
        _addInstruction(StoreFieldInstruction(
          offset: initializer.offset,
          base: const VariableValue(Variable('this')),
          fieldName: initializer.fieldName.name,
          value: value,
        ));

      case SuperConstructorInvocation():
        // super(...) or super.name(...)
        final arguments = initializer.argumentList.arguments
            .map((arg) => _evaluateExpression(arg is NamedExpression ? arg.expression : arg))
            .toList();
        final methodName = initializer.constructorName?.name ?? '<super>';
        _addInstruction(CallInstruction(
          offset: initializer.offset,
          receiver: const VariableValue(Variable('super')),
          methodName: methodName,
          arguments: arguments,
        ));

      case RedirectingConstructorInvocation():
        // this(...) or this.name(...)
        final arguments = initializer.argumentList.arguments
            .map((arg) => _evaluateExpression(arg is NamedExpression ? arg.expression : arg))
            .toList();
        final methodName = initializer.constructorName?.name ?? '<this>';
        _addInstruction(CallInstruction(
          offset: initializer.offset,
          receiver: const VariableValue(Variable('this')),
          methodName: methodName,
          arguments: arguments,
        ));

      case AssertInitializer():
        // Assert in initializer list - evaluate condition but don't affect flow
        _evaluateExpression(initializer.condition);
    }
  }

  ControlFlowGraph _build(String name, FunctionBody body) {
    _reset();

    final entry = _createBlock();
    _exitBlock = _createBlock();
    _currentBlock = entry;

    if (body is BlockFunctionBody) {
      _visitBlock(body.block);
    } else if (body is ExpressionFunctionBody) {
      final value = _evaluateExpression(body.expression);
      _addInstruction(ReturnInstruction(
        offset: body.expression.offset,
        value: value,
      ));
    } else if (body is EmptyFunctionBody) {
      // No body, just return
    }

    // Connect last block to exit if not already terminated
    if (_currentBlock != null && !_isTerminated(_currentBlock!)) {
      _addInstruction(ReturnInstruction(offset: body.offset));
      _currentBlock!.connectTo(_exitBlock!);
    }

    return ControlFlowGraph(
      functionName: name,
      entry: entry,
      blocks: _blocks,
    );
  }

  void _reset() {
    _blockIdCounter = 0;
    _tempVarCounter = 0;
    _currentBlock = null;
    _blocks.clear();
    _exitBlock = null;
    _continueTargets.clear();
    _breakTargets.clear();
  }

  BasicBlock _createBlock() {
    final block = BasicBlock(id: _blockIdCounter++);
    _blocks.add(block);
    return block;
  }

  Variable _createTemp() {
    return Variable('_t${_tempVarCounter++}');
  }

  void _addInstruction(Instruction instruction) {
    _currentBlock?.addInstruction(instruction);
  }

  bool _isTerminated(BasicBlock block) {
    if (block.instructions.isEmpty) return false;
    final last = block.instructions.last;
    return last is ReturnInstruction ||
        last is JumpInstruction ||
        last is BranchInstruction ||
        last is ThrowInstruction ||
        last is AwaitInstruction;
  }

  // ============================================================
  // Statement Visitors
  // ============================================================

  void _visitBlock(Block block) {
    for (final statement in block.statements) {
      _visitStatement(statement);
      if (_currentBlock == null || _isTerminated(_currentBlock!)) {
        break;
      }
    }
  }

  void _visitStatement(Statement statement) {
    switch (statement) {
      case VariableDeclarationStatement():
        _visitVariableDeclaration(statement);
      case ExpressionStatement():
        _visitExpressionStatement(statement);
      case IfStatement():
        _visitIfStatement(statement);
      case WhileStatement():
        _visitWhileStatement(statement);
      case DoStatement():
        _visitDoStatement(statement);
      case ForStatement():
        _visitForStatement(statement);
      // ForEachStatement was merged into ForStatement with ForEachParts
      // Handled in _visitForStatement
      case ReturnStatement():
        _visitReturnStatement(statement);
      case BreakStatement():
        _visitBreakStatement(statement);
      case ContinueStatement():
        _visitContinueStatement(statement);
      case SwitchStatement():
        _visitSwitchStatement(statement);
      case TryStatement():
        _visitTryStatement(statement);
      case Block():
        _visitBlock(statement);
      case EmptyStatement():
        // No-op
        break;
      case AssertStatement():
        _visitAssertStatement(statement);
      default:
        // Unsupported statement - skip
        break;
    }
  }

  void _visitVariableDeclaration(VariableDeclarationStatement statement) {
    for (final variable in statement.variables.variables) {
      if (variable.initializer != null) {
        final value = _evaluateExpression(variable.initializer!);
        final target = Variable(variable.name.lexeme);
        _addInstruction(AssignInstruction(
          offset: variable.offset,
          target: target,
          value: value,
        ));
      }
    }
  }

  void _visitExpressionStatement(ExpressionStatement statement) {
    _evaluateExpression(statement.expression);
  }

  void _visitIfStatement(IfStatement statement) {
    // Evaluate condition
    final condition = _evaluateExpression(statement.expression);

    // Create blocks
    final thenBlock = _createBlock();
    final elseBlock = _createBlock();
    final mergeBlock = _createBlock();

    // Branch instruction
    _addInstruction(BranchInstruction(
      offset: statement.offset,
      condition: condition,
      thenBlock: thenBlock,
      elseBlock: elseBlock,
    ));
    _currentBlock!.connectTo(thenBlock);
    _currentBlock!.connectTo(elseBlock);

    // Visit then branch
    _currentBlock = thenBlock;
    _visitStatement(statement.thenStatement);
    if (_currentBlock != null && !_isTerminated(_currentBlock!)) {
      _addInstruction(JumpInstruction(offset: statement.offset, target: mergeBlock));
      _currentBlock!.connectTo(mergeBlock);
    }

    // Visit else branch
    _currentBlock = elseBlock;
    if (statement.elseStatement != null) {
      _visitStatement(statement.elseStatement!);
    }
    if (_currentBlock != null && !_isTerminated(_currentBlock!)) {
      _addInstruction(JumpInstruction(offset: statement.offset, target: mergeBlock));
      _currentBlock!.connectTo(mergeBlock);
    }

    // Continue from merge block
    _currentBlock = mergeBlock;
  }

  void _visitWhileStatement(WhileStatement statement) {
    final headerBlock = _createBlock();
    final bodyBlock = _createBlock();
    final exitBlock = _createBlock();

    // Jump to header
    _addInstruction(JumpInstruction(offset: statement.offset, target: headerBlock));
    _currentBlock!.connectTo(headerBlock);

    // Header: evaluate condition and branch
    _currentBlock = headerBlock;
    final condition = _evaluateExpression(statement.condition);
    _addInstruction(BranchInstruction(
      offset: statement.offset,
      condition: condition,
      thenBlock: bodyBlock,
      elseBlock: exitBlock,
    ));
    headerBlock.connectTo(bodyBlock);
    headerBlock.connectTo(exitBlock);

    // Body
    _continueTargets.add(headerBlock);
    _breakTargets.add(exitBlock);
    _currentBlock = bodyBlock;
    _visitStatement(statement.body);
    if (_currentBlock != null && !_isTerminated(_currentBlock!)) {
      _addInstruction(JumpInstruction(offset: statement.offset, target: headerBlock));
      _currentBlock!.connectTo(headerBlock);
    }
    _continueTargets.removeLast();
    _breakTargets.removeLast();

    // Continue from exit
    _currentBlock = exitBlock;
  }

  void _visitDoStatement(DoStatement statement) {
    final bodyBlock = _createBlock();
    final conditionBlock = _createBlock();
    final exitBlock = _createBlock();

    // Jump to body
    _addInstruction(JumpInstruction(offset: statement.offset, target: bodyBlock));
    _currentBlock!.connectTo(bodyBlock);

    // Body
    _continueTargets.add(conditionBlock);
    _breakTargets.add(exitBlock);
    _currentBlock = bodyBlock;
    _visitStatement(statement.body);
    if (_currentBlock != null && !_isTerminated(_currentBlock!)) {
      _addInstruction(JumpInstruction(offset: statement.offset, target: conditionBlock));
      _currentBlock!.connectTo(conditionBlock);
    }
    _continueTargets.removeLast();
    _breakTargets.removeLast();

    // Condition
    _currentBlock = conditionBlock;
    final condition = _evaluateExpression(statement.condition);
    _addInstruction(BranchInstruction(
      offset: statement.offset,
      condition: condition,
      thenBlock: bodyBlock,
      elseBlock: exitBlock,
    ));
    conditionBlock.connectTo(bodyBlock);
    conditionBlock.connectTo(exitBlock);

    // Continue from exit
    _currentBlock = exitBlock;
  }

  void _visitForStatement(ForStatement statement) {
    final parts = statement.forLoopParts;

    // Handle for-each loops (for-in)
    if (parts is ForEachParts) {
      _visitForEachParts(statement, parts);
      return;
    }

    // Handle regular for loops
    if (parts is ForPartsWithDeclarations) {
      // Initialize variables
      for (final variable in parts.variables.variables) {
        if (variable.initializer != null) {
          final value = _evaluateExpression(variable.initializer!);
          _addInstruction(AssignInstruction(
            offset: variable.offset,
            target: Variable(variable.name.lexeme),
            value: value,
          ));
        }
      }
    } else if (parts is ForPartsWithExpression && parts.initialization != null) {
      _evaluateExpression(parts.initialization!);
    }

    final headerBlock = _createBlock();
    final bodyBlock = _createBlock();
    final updateBlock = _createBlock();
    final exitBlock = _createBlock();

    // Jump to header
    _addInstruction(JumpInstruction(offset: statement.offset, target: headerBlock));
    _currentBlock!.connectTo(headerBlock);

    // Header: condition check
    _currentBlock = headerBlock;
    if (parts is ForParts && parts.condition != null) {
      final condition = _evaluateExpression(parts.condition!);
      _addInstruction(BranchInstruction(
        offset: statement.offset,
        condition: condition,
        thenBlock: bodyBlock,
        elseBlock: exitBlock,
      ));
      headerBlock.connectTo(bodyBlock);
      headerBlock.connectTo(exitBlock);
    } else {
      // Infinite loop (no condition)
      _addInstruction(JumpInstruction(offset: statement.offset, target: bodyBlock));
      headerBlock.connectTo(bodyBlock);
    }

    // Body
    _continueTargets.add(updateBlock);
    _breakTargets.add(exitBlock);
    _currentBlock = bodyBlock;
    _visitStatement(statement.body);
    if (_currentBlock != null && !_isTerminated(_currentBlock!)) {
      _addInstruction(JumpInstruction(offset: statement.offset, target: updateBlock));
      _currentBlock!.connectTo(updateBlock);
    }
    _continueTargets.removeLast();
    _breakTargets.removeLast();

    // Update
    _currentBlock = updateBlock;
    if (parts is ForParts) {
      for (final updater in parts.updaters) {
        _evaluateExpression(updater);
      }
    }
    _addInstruction(JumpInstruction(offset: statement.offset, target: headerBlock));
    updateBlock.connectTo(headerBlock);

    // Continue from exit
    _currentBlock = exitBlock;
  }

  /// Handles for-each loops (for-in statements).
  void _visitForEachParts(ForStatement statement, ForEachParts parts) {
    // Simplified: treat as while loop over iterator
    final iterable = _evaluateExpression(parts.iterable);
    final iterator = _createTemp();
    _addInstruction(AssignInstruction(
      offset: statement.offset,
      target: iterator,
      value: CallValue(
        receiver: iterable,
        methodName: 'iterator',
        arguments: [],
      ),
    ));

    final headerBlock = _createBlock();
    final bodyBlock = _createBlock();
    final exitBlock = _createBlock();

    _addInstruction(JumpInstruction(offset: statement.offset, target: headerBlock));
    _currentBlock!.connectTo(headerBlock);

    // Header: check moveNext()
    _currentBlock = headerBlock;
    final hasNext = _createTemp();
    _addInstruction(AssignInstruction(
      offset: statement.offset,
      target: hasNext,
      value: CallValue(
        receiver: VariableValue(iterator),
        methodName: 'moveNext',
        arguments: [],
      ),
    ));
    _addInstruction(BranchInstruction(
      offset: statement.offset,
      condition: VariableValue(hasNext),
      thenBlock: bodyBlock,
      elseBlock: exitBlock,
    ));
    headerBlock.connectTo(bodyBlock);
    headerBlock.connectTo(exitBlock);

    // Body: assign current element
    _continueTargets.add(headerBlock);
    _breakTargets.add(exitBlock);
    _currentBlock = bodyBlock;

    // Get loop variable name based on ForEachParts type
    String? loopVarName;
    if (parts is ForEachPartsWithDeclaration) {
      loopVarName = parts.loopVariable.name.lexeme;
    } else if (parts is ForEachPartsWithIdentifier) {
      loopVarName = parts.identifier.name;
    }

    if (loopVarName != null) {
      _addInstruction(AssignInstruction(
        offset: statement.offset,
        target: Variable(loopVarName),
        value: FieldAccessValue(VariableValue(iterator), 'current'),
      ));
    }

    _visitStatement(statement.body);
    if (_currentBlock != null && !_isTerminated(_currentBlock!)) {
      _addInstruction(JumpInstruction(offset: statement.offset, target: headerBlock));
      _currentBlock!.connectTo(headerBlock);
    }
    _continueTargets.removeLast();
    _breakTargets.removeLast();

    _currentBlock = exitBlock;
  }

  void _visitReturnStatement(ReturnStatement statement) {
    final value =
        statement.expression != null ? _evaluateExpression(statement.expression!) : null;
    _addInstruction(ReturnInstruction(offset: statement.offset, value: value));
    _currentBlock!.connectTo(_exitBlock!);
  }

  void _visitBreakStatement(BreakStatement statement) {
    if (_breakTargets.isNotEmpty) {
      final target = _breakTargets.last;
      _addInstruction(JumpInstruction(offset: statement.offset, target: target));
      _currentBlock!.connectTo(target);
    }
  }

  void _visitContinueStatement(ContinueStatement statement) {
    if (_continueTargets.isNotEmpty) {
      final target = _continueTargets.last;
      _addInstruction(JumpInstruction(offset: statement.offset, target: target));
      _currentBlock!.connectTo(target);
    }
  }

  void _visitSwitchStatement(SwitchStatement statement) {
    final switchValue = _evaluateExpression(statement.expression);
    final switchTemp = _createTemp();
    _addInstruction(AssignInstruction(
      offset: statement.offset,
      target: switchTemp,
      value: switchValue,
    ));

    final exitBlock = _createBlock();
    _breakTargets.add(exitBlock);

    BasicBlock? previousFallthrough;

    for (final member in statement.members) {
      final caseBlock = _createBlock();

      if (previousFallthrough != null && !_isTerminated(previousFallthrough)) {
        previousFallthrough.connectTo(caseBlock);
      }

      if (member is SwitchCase) {
        // Condition check
        final caseValue = _evaluateExpression(member.expression);
        final nextCaseBlock = _createBlock();

        final conditionTemp = _createTemp();
        _addInstruction(AssignInstruction(
          offset: member.offset,
          target: conditionTemp,
          value: BinaryOpValue('==', VariableValue(switchTemp), caseValue),
        ));
        _addInstruction(BranchInstruction(
          offset: member.offset,
          condition: VariableValue(conditionTemp),
          thenBlock: caseBlock,
          elseBlock: nextCaseBlock,
        ));
        _currentBlock!.connectTo(caseBlock);
        _currentBlock!.connectTo(nextCaseBlock);
        _currentBlock = nextCaseBlock;
      } else if (member is SwitchDefault) {
        _addInstruction(JumpInstruction(offset: member.offset, target: caseBlock));
        _currentBlock!.connectTo(caseBlock);
      }

      // Visit case statements
      final savedBlock = _currentBlock;
      _currentBlock = caseBlock;
      for (final stmt in member.statements) {
        _visitStatement(stmt);
        if (_currentBlock == null || _isTerminated(_currentBlock!)) break;
      }
      previousFallthrough = _currentBlock;
      _currentBlock = savedBlock;
    }

    // Jump to exit from last position
    if (_currentBlock != null && !_isTerminated(_currentBlock!)) {
      _addInstruction(JumpInstruction(offset: statement.offset, target: exitBlock));
      _currentBlock!.connectTo(exitBlock);
    }

    _breakTargets.removeLast();
    _currentBlock = exitBlock;
  }

  void _visitTryStatement(TryStatement statement) {
    // Simplified try handling - treats as sequential blocks
    // Full implementation would track exception edges
    final tryBlock = _createBlock();
    final mergeBlock = _createBlock();

    _addInstruction(JumpInstruction(offset: statement.offset, target: tryBlock));
    _currentBlock!.connectTo(tryBlock);

    // Try body
    _currentBlock = tryBlock;
    _visitBlock(statement.body);
    if (_currentBlock != null && !_isTerminated(_currentBlock!)) {
      _addInstruction(JumpInstruction(offset: statement.offset, target: mergeBlock));
      _currentBlock!.connectTo(mergeBlock);
    }

    // Catch clauses
    for (final catchClause in statement.catchClauses) {
      final catchBlock = _createBlock();
      tryBlock.connectTo(catchBlock); // Exception edge

      _currentBlock = catchBlock;
      _visitBlock(catchClause.body);
      if (_currentBlock != null && !_isTerminated(_currentBlock!)) {
        _addInstruction(JumpInstruction(offset: statement.offset, target: mergeBlock));
        _currentBlock!.connectTo(mergeBlock);
      }
    }

    // Finally clause
    if (statement.finallyBlock != null) {
      final finallyBlock = _createBlock();
      mergeBlock.connectTo(finallyBlock);

      _currentBlock = finallyBlock;
      _visitBlock(statement.finallyBlock!);

      final afterFinally = _createBlock();
      if (_currentBlock != null && !_isTerminated(_currentBlock!)) {
        _addInstruction(JumpInstruction(offset: statement.offset, target: afterFinally));
        _currentBlock!.connectTo(afterFinally);
      }
      _currentBlock = afterFinally;
    } else {
      _currentBlock = mergeBlock;
    }
  }

  void _visitThrowExpression(ThrowExpression expression) {
    final value = _evaluateExpression(expression.expression);
    _addInstruction(ThrowInstruction(offset: expression.offset, exception: value));
  }

  void _visitAssertStatement(AssertStatement statement) {
    final condition = _evaluateExpression(statement.condition);
    // Simplified: generate a conditional that could throw
    final assertPass = _createBlock();
    final assertFail = _createBlock();

    _addInstruction(BranchInstruction(
      offset: statement.offset,
      condition: condition,
      thenBlock: assertPass,
      elseBlock: assertFail,
    ));
    _currentBlock!.connectTo(assertPass);
    _currentBlock!.connectTo(assertFail);

    // Fail block throws AssertionError
    _currentBlock = assertFail;
    _addInstruction(ThrowInstruction(
      offset: statement.offset,
      exception: const NewObjectValue(
        typeName: 'AssertionError',
        arguments: [],
      ),
    ));

    _currentBlock = assertPass;
  }

  // ============================================================
  // Expression Evaluator
  // ============================================================

  Value _evaluateExpression(Expression expression) {
    switch (expression) {
      case IntegerLiteral():
        return ConstantValue(expression.value);
      case DoubleLiteral():
        return ConstantValue(expression.value);
      case BooleanLiteral():
        return ConstantValue(expression.value);
      case StringLiteral():
        return ConstantValue(expression.stringValue);
      case NullLiteral():
        return const ConstantValue(null);
      case SimpleIdentifier():
        return VariableValue(Variable(expression.name));
      case PrefixedIdentifier():
        return FieldAccessValue(
          VariableValue(Variable(expression.prefix.name)),
          expression.identifier.name,
        );
      case BinaryExpression():
        return _evaluateBinaryExpression(expression);
      case PrefixExpression():
        return _evaluatePrefixExpression(expression);
      case PostfixExpression():
        return _evaluatePostfixExpression(expression);
      case AssignmentExpression():
        return _evaluateAssignment(expression);
      case ConditionalExpression():
        return _evaluateConditional(expression);
      case PropertyAccess():
        return _evaluatePropertyAccess(expression);
      case IndexExpression():
        return _evaluateIndexExpression(expression);
      case MethodInvocation():
        return _evaluateMethodInvocation(expression);
      case FunctionExpressionInvocation():
        return _evaluateFunctionInvocation(expression);
      case InstanceCreationExpression():
        return _evaluateInstanceCreation(expression);
      case ListLiteral():
        return _evaluateListLiteral(expression);
      case SetOrMapLiteral():
        return _evaluateSetOrMapLiteral(expression);
      case ParenthesizedExpression():
        return _evaluateExpression(expression.expression);
      case AsExpression():
        return _evaluateCast(expression);
      case IsExpression():
        return _evaluateTypeCheck(expression);
      case ThrowExpression():
        _visitThrowExpression(expression);
        return const ConstantValue(null); // Never reached
      case AwaitExpression():
        return _evaluateAwait(expression);
      case CascadeExpression():
        return _evaluateCascade(expression);
      default:
        // Unsupported expression - return placeholder
        return ConstantValue('<unsupported: ${expression.runtimeType}>');
    }
  }

  Value _evaluateBinaryExpression(BinaryExpression expression) {
    // Handle short-circuit operators
    if (expression.operator.lexeme == '&&') {
      return _evaluateShortCircuitAnd(expression);
    }
    if (expression.operator.lexeme == '||') {
      return _evaluateShortCircuitOr(expression);
    }
    if (expression.operator.lexeme == '??') {
      return _evaluateNullCoalescing(expression);
    }

    final left = _evaluateExpression(expression.leftOperand);
    final right = _evaluateExpression(expression.rightOperand);
    return BinaryOpValue(expression.operator.lexeme, left, right);
  }

  Value _evaluateShortCircuitAnd(BinaryExpression expression) {
    final left = _evaluateExpression(expression.leftOperand);
    final result = _createTemp();

    final rightBlock = _createBlock();
    final falseBlock = _createBlock();
    final mergeBlock = _createBlock();

    _addInstruction(BranchInstruction(
      offset: expression.offset,
      condition: left,
      thenBlock: rightBlock,
      elseBlock: falseBlock,
    ));
    _currentBlock!.connectTo(rightBlock);
    _currentBlock!.connectTo(falseBlock);

    // Left is true, evaluate right
    _currentBlock = rightBlock;
    final right = _evaluateExpression(expression.rightOperand);
    _addInstruction(AssignInstruction(
      offset: expression.offset,
      target: result,
      value: right,
    ));
    _addInstruction(JumpInstruction(offset: expression.offset, target: mergeBlock));
    _currentBlock!.connectTo(mergeBlock);

    // Left is false
    _currentBlock = falseBlock;
    _addInstruction(AssignInstruction(
      offset: expression.offset,
      target: result,
      value: const ConstantValue(false),
    ));
    _addInstruction(JumpInstruction(offset: expression.offset, target: mergeBlock));
    _currentBlock!.connectTo(mergeBlock);

    _currentBlock = mergeBlock;
    return VariableValue(result);
  }

  Value _evaluateShortCircuitOr(BinaryExpression expression) {
    final left = _evaluateExpression(expression.leftOperand);
    final result = _createTemp();

    final trueBlock = _createBlock();
    final rightBlock = _createBlock();
    final mergeBlock = _createBlock();

    _addInstruction(BranchInstruction(
      offset: expression.offset,
      condition: left,
      thenBlock: trueBlock,
      elseBlock: rightBlock,
    ));
    _currentBlock!.connectTo(trueBlock);
    _currentBlock!.connectTo(rightBlock);

    // Left is true
    _currentBlock = trueBlock;
    _addInstruction(AssignInstruction(
      offset: expression.offset,
      target: result,
      value: const ConstantValue(true),
    ));
    _addInstruction(JumpInstruction(offset: expression.offset, target: mergeBlock));
    _currentBlock!.connectTo(mergeBlock);

    // Left is false, evaluate right
    _currentBlock = rightBlock;
    final right = _evaluateExpression(expression.rightOperand);
    _addInstruction(AssignInstruction(
      offset: expression.offset,
      target: result,
      value: right,
    ));
    _addInstruction(JumpInstruction(offset: expression.offset, target: mergeBlock));
    _currentBlock!.connectTo(mergeBlock);

    _currentBlock = mergeBlock;
    return VariableValue(result);
  }

  Value _evaluateNullCoalescing(BinaryExpression expression) {
    final left = _evaluateExpression(expression.leftOperand);
    final leftTemp = _createTemp();
    _addInstruction(AssignInstruction(
      offset: expression.offset,
      target: leftTemp,
      value: left,
    ));

    final result = _createTemp();
    final nullBlock = _createBlock();
    final nonNullBlock = _createBlock();
    final mergeBlock = _createBlock();

    // Check if left is null
    final isNull = _createTemp();
    _addInstruction(AssignInstruction(
      offset: expression.offset,
      target: isNull,
      value: BinaryOpValue('==', VariableValue(leftTemp), const ConstantValue(null)),
    ));
    _addInstruction(BranchInstruction(
      offset: expression.offset,
      condition: VariableValue(isNull),
      thenBlock: nullBlock,
      elseBlock: nonNullBlock,
    ));
    _currentBlock!.connectTo(nullBlock);
    _currentBlock!.connectTo(nonNullBlock);

    // Left is null, use right
    _currentBlock = nullBlock;
    final right = _evaluateExpression(expression.rightOperand);
    _addInstruction(AssignInstruction(
      offset: expression.offset,
      target: result,
      value: right,
    ));
    _addInstruction(JumpInstruction(offset: expression.offset, target: mergeBlock));
    _currentBlock!.connectTo(mergeBlock);

    // Left is not null
    _currentBlock = nonNullBlock;
    _addInstruction(AssignInstruction(
      offset: expression.offset,
      target: result,
      value: VariableValue(leftTemp),
    ));
    _addInstruction(JumpInstruction(offset: expression.offset, target: mergeBlock));
    _currentBlock!.connectTo(mergeBlock);

    _currentBlock = mergeBlock;
    return VariableValue(result);
  }

  Value _evaluatePrefixExpression(PrefixExpression expression) {
    final operand = _evaluateExpression(expression.operand);
    final op = expression.operator.lexeme;

    // Handle increment/decrement
    if (op == '++' || op == '--') {
      if (expression.operand is SimpleIdentifier) {
        final varName = (expression.operand as SimpleIdentifier).name;
        final variable = Variable(varName);
        final newValue = BinaryOpValue(
          op == '++' ? '+' : '-',
          operand,
          const ConstantValue(1),
        );
        _addInstruction(AssignInstruction(
          offset: expression.offset,
          target: variable,
          value: newValue,
        ));
        return VariableValue(variable);
      }
    }

    return UnaryOpValue(op, operand);
  }

  Value _evaluatePostfixExpression(PostfixExpression expression) {
    final operand = _evaluateExpression(expression.operand);
    final op = expression.operator.lexeme;

    if (op == '!' && expression.operand is! SimpleIdentifier) {
      // Null assertion
      final result = _createTemp();
      _addInstruction(NullCheckInstruction(
        offset: expression.offset,
        operand: operand,
        result: result,
      ));
      return VariableValue(result);
    }

    if ((op == '++' || op == '--') && expression.operand is SimpleIdentifier) {
      final varName = (expression.operand as SimpleIdentifier).name;
      final variable = Variable(varName);
      final oldValue = _createTemp();
      _addInstruction(AssignInstruction(
        offset: expression.offset,
        target: oldValue,
        value: operand,
      ));
      final newValue = BinaryOpValue(
        op == '++' ? '+' : '-',
        operand,
        const ConstantValue(1),
      );
      _addInstruction(AssignInstruction(
        offset: expression.offset,
        target: variable,
        value: newValue,
      ));
      return VariableValue(oldValue);
    }

    return UnaryOpValue(op, operand);
  }

  Value _evaluateAssignment(AssignmentExpression expression) {
    final right = _evaluateExpression(expression.rightHandSide);

    if (expression.leftHandSide is SimpleIdentifier) {
      final varName = (expression.leftHandSide as SimpleIdentifier).name;
      final variable = Variable(varName);
      final op = expression.operator.lexeme;

      Value value;
      if (op == '=') {
        value = right;
      } else {
        // Compound assignment (+=, -=, etc.)
        final currentValue = VariableValue(variable);
        final binaryOp = op.substring(0, op.length - 1);
        value = BinaryOpValue(binaryOp, currentValue, right);
      }

      _addInstruction(AssignInstruction(
        offset: expression.offset,
        target: variable,
        value: value,
      ));
      return value;
    } else if (expression.leftHandSide is PropertyAccess) {
      final prop = expression.leftHandSide as PropertyAccess;
      final base = _evaluateExpression(prop.target!);
      _addInstruction(StoreFieldInstruction(
        offset: expression.offset,
        base: base,
        fieldName: prop.propertyName.name,
        value: right,
      ));
      return right;
    } else if (expression.leftHandSide is IndexExpression) {
      final index = expression.leftHandSide as IndexExpression;
      final base = _evaluateExpression(index.target!);
      final idx = _evaluateExpression(index.index);
      _addInstruction(StoreIndexInstruction(
        offset: expression.offset,
        base: base,
        index: idx,
        value: right,
      ));
      return right;
    }

    return right;
  }

  Value _evaluateConditional(ConditionalExpression expression) {
    final condition = _evaluateExpression(expression.condition);
    final result = _createTemp();

    final thenBlock = _createBlock();
    final elseBlock = _createBlock();
    final mergeBlock = _createBlock();

    _addInstruction(BranchInstruction(
      offset: expression.offset,
      condition: condition,
      thenBlock: thenBlock,
      elseBlock: elseBlock,
    ));
    _currentBlock!.connectTo(thenBlock);
    _currentBlock!.connectTo(elseBlock);

    // Then branch
    _currentBlock = thenBlock;
    final thenValue = _evaluateExpression(expression.thenExpression);
    _addInstruction(AssignInstruction(
      offset: expression.offset,
      target: result,
      value: thenValue,
    ));
    _addInstruction(JumpInstruction(offset: expression.offset, target: mergeBlock));
    _currentBlock!.connectTo(mergeBlock);

    // Else branch
    _currentBlock = elseBlock;
    final elseValue = _evaluateExpression(expression.elseExpression);
    _addInstruction(AssignInstruction(
      offset: expression.offset,
      target: result,
      value: elseValue,
    ));
    _addInstruction(JumpInstruction(offset: expression.offset, target: mergeBlock));
    _currentBlock!.connectTo(mergeBlock);

    _currentBlock = mergeBlock;
    return VariableValue(result);
  }

  Value _evaluatePropertyAccess(PropertyAccess expression) {
    final target = expression.target;
    if (target == null) {
      return VariableValue(Variable(expression.propertyName.name));
    }

    // Handle null-aware access (?.)
    if (expression.isNullAware) {
      return _evaluateNullAwarePropertyAccess(expression);
    }

    final receiver = _evaluateExpression(target);
    return FieldAccessValue(receiver, expression.propertyName.name);
  }

  Value _evaluateNullAwarePropertyAccess(PropertyAccess expression) {
    final receiver = _evaluateExpression(expression.target!);
    final receiverTemp = _createTemp();
    _addInstruction(AssignInstruction(
      offset: expression.offset,
      target: receiverTemp,
      value: receiver,
    ));

    final result = _createTemp();
    final nullBlock = _createBlock();
    final accessBlock = _createBlock();
    final mergeBlock = _createBlock();

    final isNull = _createTemp();
    _addInstruction(AssignInstruction(
      offset: expression.offset,
      target: isNull,
      value: BinaryOpValue('==', VariableValue(receiverTemp), const ConstantValue(null)),
    ));
    _addInstruction(BranchInstruction(
      offset: expression.offset,
      condition: VariableValue(isNull),
      thenBlock: nullBlock,
      elseBlock: accessBlock,
    ));
    _currentBlock!.connectTo(nullBlock);
    _currentBlock!.connectTo(accessBlock);

    // Null case
    _currentBlock = nullBlock;
    _addInstruction(AssignInstruction(
      offset: expression.offset,
      target: result,
      value: const ConstantValue(null),
    ));
    _addInstruction(JumpInstruction(offset: expression.offset, target: mergeBlock));
    _currentBlock!.connectTo(mergeBlock);

    // Access case
    _currentBlock = accessBlock;
    _addInstruction(AssignInstruction(
      offset: expression.offset,
      target: result,
      value: FieldAccessValue(VariableValue(receiverTemp), expression.propertyName.name),
    ));
    _addInstruction(JumpInstruction(offset: expression.offset, target: mergeBlock));
    _currentBlock!.connectTo(mergeBlock);

    _currentBlock = mergeBlock;
    return VariableValue(result);
  }

  Value _evaluateIndexExpression(IndexExpression expression) {
    final target = _evaluateExpression(expression.target!);
    final index = _evaluateExpression(expression.index);
    return IndexAccessValue(target, index);
  }

  Value _evaluateMethodInvocation(MethodInvocation expression) {
    Value? receiver;
    if (expression.target != null) {
      receiver = _evaluateExpression(expression.target!);
    }

    final arguments = expression.argumentList.arguments
        .map((arg) => _evaluateExpression(arg))
        .toList();

    final result = _createTemp();
    _addInstruction(CallInstruction(
      offset: expression.offset,
      receiver: receiver,
      methodName: expression.methodName.name,
      arguments: arguments,
      result: result,
    ));

    return VariableValue(result);
  }

  Value _evaluateFunctionInvocation(FunctionExpressionInvocation expression) {
    final function = _evaluateExpression(expression.function);
    final arguments = expression.argumentList.arguments
        .map((arg) => _evaluateExpression(arg))
        .toList();

    return CallValue(
      receiver: function,
      methodName: 'call',
      arguments: arguments,
    );
  }

  Value _evaluateInstanceCreation(InstanceCreationExpression expression) {
    final arguments = expression.argumentList.arguments
        .map((arg) => _evaluateExpression(arg))
        .toList();

    final type = expression.constructorName.type;
    final typeName = type.name.lexeme;
    final constructorName = expression.constructorName.name?.name;

    return NewObjectValue(
      typeName: typeName,
      constructorName: constructorName,
      arguments: arguments,
    );
  }

  Value _evaluateListLiteral(ListLiteral expression) {
    final elements = expression.elements.map((e) {
      if (e is Expression) {
        return _evaluateExpression(e);
      }
      return const ConstantValue('<spread>');
    }).toList();

    final result = _createTemp();
    _addInstruction(AssignInstruction(
      offset: expression.offset,
      target: result,
      value: NewObjectValue(
        typeName: 'List',
        arguments: elements,
      ),
    ));
    return VariableValue(result);
  }

  Value _evaluateSetOrMapLiteral(SetOrMapLiteral expression) {
    final typeName = expression.isMap ? 'Map' : 'Set';
    final result = _createTemp();
    _addInstruction(AssignInstruction(
      offset: expression.offset,
      target: result,
      value: NewObjectValue(
        typeName: typeName,
        arguments: [],
      ),
    ));
    return VariableValue(result);
  }

  Value _evaluateCast(AsExpression expression) {
    final operand = _evaluateExpression(expression.expression);
    final result = _createTemp();
    final type = expression.type;
    final typeName = type.toSource();

    _addInstruction(CastInstruction(
      offset: expression.offset,
      operand: operand,
      targetType: typeName,
      result: result,
      isNullable: type.question != null,
    ));

    return VariableValue(result);
  }

  Value _evaluateTypeCheck(IsExpression expression) {
    final operand = _evaluateExpression(expression.expression);
    final result = _createTemp();
    final typeName = expression.type.toSource();

    _addInstruction(TypeCheckInstruction(
      offset: expression.offset,
      operand: operand,
      targetType: typeName,
      result: result,
      negated: expression.notOperator != null,
    ));

    return VariableValue(result);
  }

  Value _evaluateAwait(AwaitExpression expression) {
    // Evaluate the future being awaited
    final operand = _evaluateExpression(expression.expression);
    final awaitTemp = _createTemp();

    // Create continuation block for code after the await
    final continuationBlock = _createBlock();

    // Add AwaitInstruction as a terminator
    _addInstruction(AwaitInstruction(
      offset: expression.offset,
      future: operand,
      result: awaitTemp,
    ));

    // Connect current block to continuation and switch to it
    _currentBlock!.connectTo(continuationBlock);
    _currentBlock = continuationBlock;

    return VariableValue(awaitTemp);
  }

  Value _evaluateCascade(CascadeExpression expression) {
    final target = _evaluateExpression(expression.target);
    final targetTemp = _createTemp();
    _addInstruction(AssignInstruction(
      offset: expression.offset,
      target: targetTemp,
      value: target,
    ));

    for (final section in expression.cascadeSections) {
      _evaluateCascadeSection(VariableValue(targetTemp), section);
    }

    return VariableValue(targetTemp);
  }

  void _evaluateCascadeSection(Value target, Expression section) {
    if (section is MethodInvocation) {
      final arguments = section.argumentList.arguments
          .map((arg) => _evaluateExpression(arg))
          .toList();
      _addInstruction(CallInstruction(
        offset: section.offset,
        receiver: target,
        methodName: section.methodName.name,
        arguments: arguments,
      ));
    } else if (section is PropertyAccess) {
      // Cascade property access (getter call, usually no-op in CFG)
    } else if (section is AssignmentExpression) {
      if (section.leftHandSide is PropertyAccess) {
        final prop = section.leftHandSide as PropertyAccess;
        final value = _evaluateExpression(section.rightHandSide);
        _addInstruction(StoreFieldInstruction(
          offset: section.offset,
          base: target,
          fieldName: prop.propertyName.name,
          value: value,
        ));
      } else if (section.leftHandSide is IndexExpression) {
        final index = section.leftHandSide as IndexExpression;
        final idx = _evaluateExpression(index.index);
        final value = _evaluateExpression(section.rightHandSide);
        _addInstruction(StoreIndexInstruction(
          offset: section.offset,
          base: target,
          index: idx,
          value: value,
        ));
      }
    }
  }
}
