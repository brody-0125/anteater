import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../../rule.dart';

/// Rule that detects unnecessary type casts.
///
/// Unnecessary casts add noise to code without providing any value.
/// They can also hide actual type issues.
class AvoidUnnecessaryCastRule extends StyleRule {
  @override
  String get id => 'avoid-unnecessary-cast';

  @override
  String get description =>
      'Avoid unnecessary type casts that can be inferred.';

  @override
  RuleSeverity get defaultSeverity => RuleSeverity.info;

  @override
  RuleCategory get category => RuleCategory.quality;

  @override
  List<Violation> check(CompilationUnit unit, {LineInfo? lineInfo}) {
    final effectiveLineInfo = lineInfo ?? unit.lineInfo;
    final visitor = _AvoidUnnecessaryCastVisitor(effectiveLineInfo);
    unit.accept(visitor);
    return visitor.violations;
  }
}

class _AvoidUnnecessaryCastVisitor extends RecursiveAstVisitor<void> {
  final LineInfo lineInfo;
  final List<Violation> violations = [];

  _AvoidUnnecessaryCastVisitor(this.lineInfo);

  @override
  void visitAsExpression(AsExpression node) {
    // Pattern: (expr as Type) where expr already has that type
    // This requires resolved types, which we may not have
    // For now, detect obvious patterns

    final expr = node.expression;
    final targetType = node.type;

    // Detect: (x as X) right after (x is X) check
    // This is a common pattern that could use type promotion
    if (_isAfterTypeCheck(node)) {
      violations.add(Violation(
        ruleId: 'avoid-unnecessary-cast',
        message: 'Unnecessary cast after type check. Use type promotion.',
        location: SourceRange.fromNode(node, lineInfo),
        severity: RuleSeverity.info,
        suggestion:
            'Use a local variable with type promotion instead of casting.',
        sourceCode: node.toSource(),
      ));
    }

    // Detect: literal as Type (e.g., 1 as int)
    if (expr is Literal) {
      final literalType = _getLiteralTypeName(expr);
      if (literalType != null && _typeMatches(targetType, literalType)) {
        violations.add(Violation(
          ruleId: 'avoid-unnecessary-cast',
          message: 'Unnecessary cast. Literal already has type $literalType.',
          location: SourceRange.fromNode(node, lineInfo),
          severity: RuleSeverity.info,
          suggestion: 'Remove the cast: ${expr.toSource()}',
          sourceCode: node.toSource(),
        ));
      }
    }

    // Detect: (x as Type) as Type (double cast)
    if (expr is AsExpression) {
      final innerType = expr.type;
      if (_typesAreEqual(innerType, targetType)) {
        violations.add(Violation(
          ruleId: 'avoid-unnecessary-cast',
          message: 'Redundant double cast to the same type.',
          location: SourceRange.fromNode(node, lineInfo),
          severity: RuleSeverity.info,
          suggestion: 'Remove one of the casts.',
          sourceCode: node.toSource(),
        ));
      }
    }

    super.visitAsExpression(node);
  }

  @override
  void visitIsExpression(IsExpression node) {
    // Detect: x is Object (always true for non-null)
    final targetType = node.type;
    if (_typeMatches(targetType, 'Object') && node.notOperator == null) {
      violations.add(Violation(
        ruleId: 'avoid-unnecessary-cast',
        message: "'is Object' check is always true for non-null values.",
        location: SourceRange.fromNode(node, lineInfo),
        severity: RuleSeverity.info,
        suggestion: 'Remove the type check or use a more specific type.',
        sourceCode: node.toSource(),
      ));
    }

    super.visitIsExpression(node);
  }

  /// Checks if this cast is immediately after a type check.
  bool _isAfterTypeCheck(AsExpression node) {
    // Look for pattern: if (x is Type) { ... (x as Type) ... }
    // This is a simplified check
    final parent = node.parent;
    if (parent is ExpressionStatement) {
      final grandparent = parent.parent;
      if (grandparent is Block) {
        final greatGrandparent = grandparent.parent;
        if (greatGrandparent is IfStatement) {
          final condition = greatGrandparent.expression;
          if (condition is IsExpression) {
            // Check if same variable and type
            return _expressionsMatch(condition.expression, node.expression) &&
                _typesAreEqual(condition.type, node.type);
          }
        }
      }
    }
    return false;
  }

  String? _getLiteralTypeName(Literal literal) {
    if (literal is IntegerLiteral) return 'int';
    if (literal is DoubleLiteral) return 'double';
    if (literal is BooleanLiteral) return 'bool';
    if (literal is SimpleStringLiteral) return 'String';
    if (literal is NullLiteral) return 'Null';
    return null;
  }

  bool _typeMatches(TypeAnnotation type, String name) {
    if (type is NamedType) {
      return type.name.lexeme == name;
    }
    return false;
  }

  bool _typesAreEqual(TypeAnnotation? a, TypeAnnotation? b) {
    if (a == null || b == null) return false;
    return a.toSource() == b.toSource();
  }

  bool _expressionsMatch(Expression a, Expression b) {
    return a.toSource() == b.toSource();
  }
}
