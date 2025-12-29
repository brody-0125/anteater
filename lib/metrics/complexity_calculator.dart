import 'dart:math' as math;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Calculates various complexity metrics for Dart code.
class ComplexityCalculator {
  /// Calculates cyclomatic complexity for a function/method.
  int calculateCyclomaticComplexity(AstNode node) {
    final visitor = _CyclomaticComplexityVisitor();
    node.accept(visitor);
    return visitor.complexity;
  }

  /// Calculates cognitive complexity for a function/method.
  int calculateCognitiveComplexity(AstNode node) {
    final visitor = _CognitiveComplexityVisitor();
    node.accept(visitor);
    return visitor.complexity;
  }

  /// Calculates Halstead metrics for a function/method.
  HalsteadMetrics calculateHalsteadMetrics(AstNode node) {
    final visitor = _HalsteadVisitor();
    node.accept(visitor);
    return visitor.compute();
  }

  /// Calculates maintainability index.
  double calculateMaintainabilityIndex({
    required double halsteadVolume,
    required int cyclomaticComplexity,
    required int linesOfCode,
  }) {
    if (linesOfCode <= 0 || halsteadVolume <= 0) {
      return 100.0;
    }

    final mi = 171 -
        5.2 * math.log(halsteadVolume) -
        0.23 * cyclomaticComplexity -
        16.2 * math.log(linesOfCode);

    return math.max(0, mi * 100 / 171);
  }
}

/// Visitor for calculating cyclomatic complexity.
///
/// Counts decision points in the code:
/// - if, for, while, do-while, switch cases
/// - catch clauses
/// - conditional expressions (?:)
/// - logical operators (&&, ||)
/// - null-aware operators (?., ??, ??=)
class _CyclomaticComplexityVisitor extends RecursiveAstVisitor<void> {
  int complexity = 1; // Base complexity

  @override
  void visitIfStatement(IfStatement node) {
    complexity++;
    super.visitIfStatement(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    complexity++;
    super.visitForStatement(node);
  }

  @override
  void visitForEachPartsWithDeclaration(ForEachPartsWithDeclaration node) {
    complexity++;
    super.visitForEachPartsWithDeclaration(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    complexity++;
    super.visitWhileStatement(node);
  }

  @override
  void visitDoStatement(DoStatement node) {
    complexity++;
    super.visitDoStatement(node);
  }

  @override
  void visitSwitchCase(SwitchCase node) {
    complexity++;
    super.visitSwitchCase(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    complexity++;
    super.visitCatchClause(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    complexity++;
    super.visitConditionalExpression(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final op = node.operator.lexeme;
    if (op == '&&' || op == '||') {
      complexity++;
    }
    if (op == '??') {
      complexity++; // Null-coalescing
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.operator.lexeme == '?.') {
      complexity++; // Null-aware access
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.operator?.lexeme == '?.') {
      complexity++; // Null-aware method call
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (node.operator.lexeme == '??=') {
      complexity++; // Null-aware assignment
    }
    super.visitAssignmentExpression(node);
  }
}

/// Visitor for calculating cognitive complexity.
///
/// Based on SonarQube's cognitive complexity model:
/// - Nesting increases complexity exponentially
/// - Some structures are inherently harder to understand
class _CognitiveComplexityVisitor extends RecursiveAstVisitor<void> {
  int complexity = 0;
  int _nestingLevel = 0;

  void _incrementComplexity({bool includeNesting = true}) {
    complexity += 1 + (includeNesting ? _nestingLevel : 0);
  }

  void _withNesting(void Function() body) {
    _nestingLevel++;
    body();
    _nestingLevel--;
  }

  @override
  void visitIfStatement(IfStatement node) {
    _incrementComplexity();
    _withNesting(() {
      node.thenStatement.accept(this);
    });

    final elseStatement = node.elseStatement;
    if (elseStatement != null) {
      if (elseStatement is IfStatement) {
        // else-if doesn't increase nesting
        complexity++; // But does add to complexity
        elseStatement.accept(this);
      } else {
        complexity++; // else
        _withNesting(() {
          elseStatement.accept(this);
        });
      }
    }
  }

  @override
  void visitForStatement(ForStatement node) {
    // ADR-015 2.2: Only count traditional for loops, not for-in
    // For-in loops are counted by visitForEachPartsWithDeclaration
    final parts = node.forLoopParts;
    if (parts is ForParts) {
      _incrementComplexity();
    }
    _withNesting(() => super.visitForStatement(node));
  }

  @override
  void visitForEachPartsWithDeclaration(ForEachPartsWithDeclaration node) {
    // ADR-015 2.2: Count for-in loops here (nesting handled by ForStatement)
    _incrementComplexity();
    super.visitForEachPartsWithDeclaration(node);
  }

  @override
  void visitForEachPartsWithIdentifier(ForEachPartsWithIdentifier node) {
    // ADR-015 2.2: Also handle for-in with existing identifier
    _incrementComplexity();
    super.visitForEachPartsWithIdentifier(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    _incrementComplexity();
    _withNesting(() => super.visitWhileStatement(node));
  }

  @override
  void visitDoStatement(DoStatement node) {
    _incrementComplexity();
    _withNesting(() => super.visitDoStatement(node));
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    // Switch only adds 1, regardless of case count
    _incrementComplexity();
    _withNesting(() => super.visitSwitchStatement(node));
  }

  @override
  void visitCatchClause(CatchClause node) {
    _incrementComplexity();
    _withNesting(() => super.visitCatchClause(node));
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final op = node.operator.lexeme;
    // Only count first in a sequence of same operators
    if (op == '&&' || op == '||') {
      final parent = node.parent;
      if (parent is! BinaryExpression || parent.operator.lexeme != op) {
        complexity++; // No nesting penalty for logical operators
      }
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Lambda/closure increases nesting
    _withNesting(() => super.visitFunctionExpression(node));
  }
}

/// Visitor for collecting Halstead metrics data.
class _HalsteadVisitor extends RecursiveAstVisitor<void> {
  final Set<String> uniqueOperators = {};
  final Set<String> uniqueOperands = {};
  int totalOperators = 0;
  int totalOperands = 0;

  @override
  void visitBinaryExpression(BinaryExpression node) {
    _addOperator(node.operator.lexeme);
    super.visitBinaryExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    _addOperator(node.operator.lexeme);
    super.visitPrefixExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    _addOperator(node.operator.lexeme);
    super.visitPostfixExpression(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    _addOperator(node.operator.lexeme);
    super.visitAssignmentExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _addOperand(node.name);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    _addOperand(node.literal.lexeme);
    super.visitIntegerLiteral(node);
  }

  @override
  void visitDoubleLiteral(DoubleLiteral node) {
    _addOperand(node.literal.lexeme);
    super.visitDoubleLiteral(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    _addOperand(node.value);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitBooleanLiteral(BooleanLiteral node) {
    _addOperand(node.value.toString());
    super.visitBooleanLiteral(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    _addOperator('if');
    super.visitIfStatement(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    _addOperator('for');
    super.visitForStatement(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    _addOperator('while');
    super.visitWhileStatement(node);
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    _addOperator('return');
    super.visitReturnStatement(node);
  }

  @override
  void visitAwaitExpression(AwaitExpression node) {
    _addOperator('await');
    super.visitAwaitExpression(node);
  }

  void _addOperator(String op) {
    uniqueOperators.add(op);
    totalOperators++;
  }

  void _addOperand(String operand) {
    uniqueOperands.add(operand);
    totalOperands++;
  }

  HalsteadMetrics compute() {
    return HalsteadMetrics(
      n1: uniqueOperators.length,
      n2: uniqueOperands.length,
      operatorTotal: totalOperators,
      operandTotal: totalOperands,
    );
  }
}

/// Halstead complexity metrics.
class HalsteadMetrics {
  const HalsteadMetrics({
    required this.n1,
    required this.n2,
    required this.operatorTotal,
    required this.operandTotal,
  });

  /// Unique operators count (n₁).
  final int n1;

  /// Unique operands count (n₂).
  final int n2;

  /// Total operators count (N₁).
  final int operatorTotal;

  /// Total operands count (N₂).
  final int operandTotal;

  /// Program vocabulary: n = n₁ + n₂
  int get vocabulary => n1 + n2;

  /// Program length: N = N₁ + N₂
  int get length => operatorTotal + operandTotal;

  /// Halstead volume: V = N × log₂(n)
  double get volume {
    if (vocabulary <= 0) return 0;
    return length * (math.log(vocabulary) / math.log(2));
  }

  /// Difficulty: D = (n₁/2) × (N₂/n₂)
  double get difficulty {
    if (n2 == 0) return 0;
    return (n1 / 2) * (operandTotal / n2);
  }

  /// Effort: E = D × V
  double get effort => difficulty * volume;

  /// Estimated time to program (seconds): T = E / 18
  double get time => effort / 18;

  /// Estimated bugs: B = V / 3000
  double get bugs => volume / 3000;

  @override
  String toString() => '''
HalsteadMetrics(
  vocabulary: $vocabulary,
  length: $length,
  volume: ${volume.toStringAsFixed(2)},
  difficulty: ${difficulty.toStringAsFixed(2)},
  effort: ${effort.toStringAsFixed(2)}
)''';
}
