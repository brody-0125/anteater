import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../../rule.dart';

/// Rule that discourages global mutable state.
///
/// Global mutable state makes code harder to test, reason about,
/// and can lead to subtle concurrency bugs.
class AvoidGlobalStateRule extends StyleRule {
  @override
  String get id => 'avoid-global-state';

  @override
  String get description =>
      'Avoid global mutable state. Use dependency injection or local state.';

  @override
  RuleSeverity get defaultSeverity => RuleSeverity.warning;

  @override
  RuleCategory get category => RuleCategory.safety;

  @override
  List<Violation> check(CompilationUnit unit, {LineInfo? lineInfo}) {
    final effectiveLineInfo = lineInfo ?? unit.lineInfo;
    final visitor = _AvoidGlobalStateVisitor(effectiveLineInfo);
    unit.accept(visitor);
    return visitor.violations;
  }
}

class _AvoidGlobalStateVisitor extends RecursiveAstVisitor<void> {
  _AvoidGlobalStateVisitor(this.lineInfo);

  final LineInfo lineInfo;
  final List<Violation> violations = [];

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    // Check for mutable top-level variables
    for (final variable in node.variables.variables) {
      if (!node.variables.isFinal && !node.variables.isConst) {
        violations.add(Violation(
          ruleId: 'avoid-global-state',
          message:
              "Avoid mutable top-level variable '${variable.name.lexeme}'.",
          location: SourceRange.fromNode(variable, lineInfo),
          severity: RuleSeverity.warning,
          suggestion:
              'Make it final/const, move it into a class, or use dependency injection.',
          sourceCode: variable.toSource(),
        ));
      }
    }
    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    // Check for mutable static fields
    if (node.isStatic) {
      for (final variable in node.fields.variables) {
        if (!node.fields.isFinal && !node.fields.isConst) {
          violations.add(Violation(
            ruleId: 'avoid-global-state',
            message:
                "Avoid mutable static field '${variable.name.lexeme}'.",
            location: SourceRange.fromNode(variable, lineInfo),
            severity: RuleSeverity.warning,
            suggestion:
                'Make it final/const, use instance fields, or use dependency injection.',
            sourceCode: variable.toSource(),
          ));
        }
      }
    }
    super.visitFieldDeclaration(node);
  }
}
