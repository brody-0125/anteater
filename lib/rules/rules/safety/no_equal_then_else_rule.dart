import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../../rule.dart';

/// Rule that disallows if/else blocks with identical code.
///
/// When both branches of an if/else contain the same code,
/// the condition is unnecessary and the code can be simplified.
class NoEqualThenElseRule extends StyleRule {
  @override
  String get id => 'no-equal-then-else';

  @override
  String get description =>
      'Avoid if/else with identical code in both branches.';

  @override
  RuleSeverity get defaultSeverity => RuleSeverity.warning;

  @override
  RuleCategory get category => RuleCategory.safety;

  @override
  List<Violation> check(CompilationUnit unit, {LineInfo? lineInfo}) {
    final effectiveLineInfo = lineInfo ?? unit.lineInfo;
    final visitor = _NoEqualThenElseVisitor(effectiveLineInfo);
    unit.accept(visitor);
    return visitor.violations;
  }
}

class _NoEqualThenElseVisitor extends RecursiveAstVisitor<void> {
  _NoEqualThenElseVisitor(this.lineInfo);

  final LineInfo lineInfo;
  final List<Violation> violations = [];

  @override
  void visitIfStatement(IfStatement node) {
    final elseStatement = node.elseStatement;
    if (elseStatement != null) {
      if (_areStatementsEqual(node.thenStatement, elseStatement)) {
        violations.add(Violation(
          ruleId: 'no-equal-then-else',
          message: 'Both branches of if/else have identical code.',
          location: SourceRange.fromNode(node, lineInfo),
          severity: RuleSeverity.warning,
          suggestion:
              'Remove the condition and keep only one copy of the code.',
          sourceCode: _truncateSource(node.toSource()),
        ));
      }
    }
    super.visitIfStatement(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    if (_areExpressionsEqual(node.thenExpression, node.elseExpression)) {
      violations.add(Violation(
        ruleId: 'no-equal-then-else',
        message: 'Both branches of ternary expression are identical.',
        location: SourceRange.fromNode(node, lineInfo),
        severity: RuleSeverity.warning,
        suggestion: 'Replace the ternary with just the result expression.',
        sourceCode: node.toSource(),
      ));
    }
    super.visitConditionalExpression(node);
  }

  /// Checks if two statements are semantically equal.
  bool _areStatementsEqual(Statement a, Statement b) {
    // Normalize source code for comparison
    final sourceA = _normalizeSource(a.toSource());
    final sourceB = _normalizeSource(b.toSource());
    return sourceA == sourceB;
  }

  /// Checks if two expressions are semantically equal.
  bool _areExpressionsEqual(Expression a, Expression b) {
    final sourceA = _normalizeSource(a.toSource());
    final sourceB = _normalizeSource(b.toSource());
    return sourceA == sourceB;
  }

  /// Normalizes source code for comparison by removing whitespace differences.
  String _normalizeSource(String source) {
    // Remove all whitespace and compare
    return source.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Truncates long source code for display.
  String _truncateSource(String source) {
    const maxLength = 100;
    if (source.length <= maxLength) {
      return source;
    }
    return '${source.substring(0, maxLength)}...';
  }
}
