import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../../rule.dart';

/// Rule that discourages use of the 'late' keyword.
///
/// The 'late' keyword defers initialization checking to runtime,
/// which can lead to LateInitializationError if the variable is
/// accessed before being initialized.
class AvoidLateKeywordRule extends StyleRule {
  @override
  String get id => 'avoid-late-keyword';

  @override
  String get description =>
      'Avoid late keyword. Use nullable types or initialize in constructor.';

  @override
  RuleSeverity get defaultSeverity => RuleSeverity.info;

  @override
  RuleCategory get category => RuleCategory.safety;

  @override
  List<Violation> check(CompilationUnit unit, {LineInfo? lineInfo}) {
    final effectiveLineInfo = lineInfo ?? unit.lineInfo;
    final visitor = _AvoidLateKeywordVisitor(effectiveLineInfo);
    unit.accept(visitor);
    return visitor.violations;
  }
}

class _AvoidLateKeywordVisitor extends RecursiveAstVisitor<void> {
  final LineInfo lineInfo;
  final List<Violation> violations = [];

  _AvoidLateKeywordVisitor(this.lineInfo);

  @override
  void visitVariableDeclarationList(VariableDeclarationList node) {
    if (node.lateKeyword != null) {
      for (final variable in node.variables) {
        // Skip late final with initializer (lazy initialization pattern)
        if (node.isFinal && variable.initializer != null) {
          // This is a valid lazy initialization pattern
          continue;
        }

        violations.add(Violation(
          ruleId: 'avoid-late-keyword',
          message: "Avoid 'late' keyword for '${variable.name.lexeme}'.",
          location: SourceRange.fromNode(variable, lineInfo),
          severity: RuleSeverity.info,
          suggestion: _getSuggestion(node, variable),
          sourceCode: variable.toSource(),
        ));
      }
    }
    super.visitVariableDeclarationList(node);
  }

  String _getSuggestion(VariableDeclarationList node, VariableDeclaration variable) {
    if (node.isFinal) {
      return 'Initialize in the constructor or use a nullable type with null check.';
    }
    return 'Use a nullable type and check for null before use, '
        'or initialize with a default value.';
  }
}
