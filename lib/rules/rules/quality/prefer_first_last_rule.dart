import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../../rule.dart';

/// Rule that prefers .first/.last over index access.
///
/// Using .first and .last is more expressive and idiomatic Dart
/// compared to accessing [0] or [length - 1].
///
/// ## Known Limitations
///
/// This rule operates on syntactic patterns without resolved type information.
/// As a result, it may produce **false positives** in the following cases:
///
/// - **String indexing**: `String` supports `[0]` but does not have `.first`
///   or `.last` properties. The rule cannot distinguish `String` from `List`.
///   ```dart
///   String s = "hello";
///   print(s[0]);  // Will trigger, but s.first doesn't exist
///   ```
///
/// - **Custom indexable types**: Any type with `operator[]` but without
///   `.first`/`.last` getters will trigger false positives.
///
/// ### Recommended Mitigation
///
/// Exclude files with heavy string manipulation:
/// ```yaml
/// anteater:
///   rules:
///     - prefer-first-last:
///         exclude:
///           - '**/string_utils.dart'
///           - '**/text_*.dart'
/// ```
class PreferFirstLastRule extends StyleRule {
  @override
  String get id => 'prefer-first-last';

  @override
  String get description =>
      'Prefer .first/.last over list[0] and list[length-1].';

  @override
  RuleSeverity get defaultSeverity => RuleSeverity.info;

  @override
  RuleCategory get category => RuleCategory.quality;

  @override
  List<Violation> check(CompilationUnit unit, {LineInfo? lineInfo}) {
    final effectiveLineInfo = lineInfo ?? unit.lineInfo;
    final visitor = _PreferFirstLastVisitor(effectiveLineInfo);
    unit.accept(visitor);
    return visitor.violations;
  }
}

class _PreferFirstLastVisitor extends RecursiveAstVisitor<void> {
  _PreferFirstLastVisitor(this.lineInfo);

  final LineInfo lineInfo;
  final List<Violation> violations = [];

  @override
  void visitIndexExpression(IndexExpression node) {
    final index = node.index;
    final target = node.target;
    if (target == null) {
      super.visitIndexExpression(node);
      return;
    }

    // Check for list[0] pattern
    if (index is IntegerLiteral && index.value == 0) {
      violations.add(Violation(
        ruleId: 'prefer-first-last',
        message: 'Prefer .first over [0] for accessing the first element.',
        location: SourceRange.fromNode(node, lineInfo),
        severity: RuleSeverity.info,
        suggestion: 'Replace ${node.toSource()} with ${target.toSource()}.first',
        sourceCode: node.toSource(),
      ));
    }

    // Check for list[length - 1] pattern
    if (index is BinaryExpression && index.operator.lexeme == '-') {
      final right = index.rightOperand;
      if (right is IntegerLiteral && right.value == 1) {
        final left = index.leftOperand;
        if (_isLengthAccess(left, target)) {
          violations.add(Violation(
            ruleId: 'prefer-first-last',
            message:
                'Prefer .last over [length-1] for accessing the last element.',
            location: SourceRange.fromNode(node, lineInfo),
            severity: RuleSeverity.info,
            suggestion: 'Replace ${node.toSource()} with ${target.toSource()}.last',
            sourceCode: node.toSource(),
          ));
        }
      }
    }

    super.visitIndexExpression(node);
  }

  /// Checks if the expression is accessing .length of the target.
  bool _isLengthAccess(Expression expr, Expression? target) {
    if (expr is PrefixedIdentifier) {
      if (expr.identifier.name == 'length') {
        return _expressionsMatch(expr.prefix, target);
      }
    }
    if (expr is PropertyAccess) {
      if (expr.propertyName.name == 'length') {
        return _expressionsMatch(expr.target, target);
      }
    }
    return false;
  }

  /// Checks if two expressions represent the same target.
  bool _expressionsMatch(Expression? a, Expression? b) {
    if (a == null || b == null) return false;
    // Simple source comparison - a more robust implementation would
    // use resolved elements
    return a.toSource() == b.toSource();
  }
}
