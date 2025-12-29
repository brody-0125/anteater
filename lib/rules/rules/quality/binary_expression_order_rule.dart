import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../../rule.dart';

/// Rule that enforces putting literal/constant values on the right side
/// of binary expressions (Yoda conditions discouraged).
///
/// `if (x == 0)` is preferred over `if (0 == x)`.
class BinaryExpressionOrderRule extends StyleRule {
  @override
  String get id => 'binary-expression-order';

  @override
  String get description =>
      'Put literal values on the right side of binary expressions.';

  @override
  RuleSeverity get defaultSeverity => RuleSeverity.info;

  @override
  RuleCategory get category => RuleCategory.quality;

  @override
  List<Violation> check(CompilationUnit unit, {LineInfo? lineInfo}) {
    final effectiveLineInfo = lineInfo ?? unit.lineInfo;
    final visitor = _BinaryExpressionOrderVisitor(effectiveLineInfo);
    unit.accept(visitor);
    return visitor.violations;
  }
}

class _BinaryExpressionOrderVisitor extends RecursiveAstVisitor<void> {
  _BinaryExpressionOrderVisitor(this.lineInfo);

  final LineInfo lineInfo;
  final List<Violation> violations = [];

  /// Operators where order matters for readability.
  static const _comparisonOperators = {'==', '!=', '<', '>', '<=', '>='};

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final op = node.operator.lexeme;

    // Only check comparison operators
    if (!_comparisonOperators.contains(op)) {
      super.visitBinaryExpression(node);
      return;
    }

    // Check for Yoda condition: literal on left, non-literal on right
    if (_isLiteral(node.leftOperand) && !_isLiteral(node.rightOperand)) {
      // Suggest flipping the comparison
      final suggestedOp = _flipOperator(op);
      violations.add(Violation(
        ruleId: 'binary-expression-order',
        message: 'Put literal values on the right side of comparisons.',
        location: SourceRange.fromNode(node, lineInfo),
        severity: RuleSeverity.info,
        suggestion:
            'Change to: ${node.rightOperand.toSource()} $suggestedOp ${node.leftOperand.toSource()}',
        sourceCode: node.toSource(),
      ));
    }

    super.visitBinaryExpression(node);
  }

  /// Checks if an expression is a literal.
  ///
  /// Only detects explicit literals, not identifiers.
  /// Without resolved types, reliable constant detection is not possible.
  /// Removed SCREAMING_CAPS heuristic as Dart style uses lowerCamelCase for constants.
  bool _isLiteral(Expression expr) {
    if (expr is Literal) return true;
    if (expr is PrefixExpression && expr.operand is Literal) return true;
    return false;
  }

  /// Map for flipping comparison operators.
  /// Const map is canonicalized at compile time, more efficient than switch.
  static const _flipMap = {
    '<': '>',
    '>': '<',
    '<=': '>=',
    '>=': '<=',
  };

  /// Flips a comparison operator for the suggestion.
  String _flipOperator(String op) => _flipMap[op] ?? op;
}
