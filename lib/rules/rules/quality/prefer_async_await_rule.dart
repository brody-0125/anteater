import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../../rule.dart';

/// Rule that prefers async/await over Future.then().
///
/// async/await provides cleaner, more readable code compared to
/// callback-based .then() chains.
class PreferAsyncAwaitRule extends StyleRule {
  @override
  String get id => 'prefer-async-await';

  @override
  String get description =>
      'Prefer async/await over .then() for Future handling.';

  @override
  RuleSeverity get defaultSeverity => RuleSeverity.info;

  @override
  RuleCategory get category => RuleCategory.quality;

  @override
  List<Violation> check(CompilationUnit unit, {LineInfo? lineInfo}) {
    final effectiveLineInfo = lineInfo ?? unit.lineInfo;
    final visitor = _PreferAsyncAwaitVisitor(effectiveLineInfo);
    unit.accept(visitor);
    return visitor.violations;
  }
}

class _PreferAsyncAwaitVisitor extends RecursiveAstVisitor<void> {
  final LineInfo lineInfo;
  final List<Violation> violations = [];

  _PreferAsyncAwaitVisitor(this.lineInfo);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check for .then() calls
    if (node.methodName.name == 'then') {
      // Check if this is followed by more .then() or .catchError() calls
      final parent = node.parent;
      final hasChaining = parent is MethodInvocation &&
          (parent.methodName.name == 'then' ||
              parent.methodName.name == 'catchError' ||
              parent.methodName.name == 'whenComplete');

      // Single .then() might be acceptable, chained .then() is not
      if (hasChaining || _hasNestedThen(node)) {
        violations.add(Violation(
          ruleId: 'prefer-async-await',
          message:
              'Prefer async/await over chained .then() calls.',
          location: SourceRange.fromNode(node.methodName, lineInfo),
          severity: RuleSeverity.info,
          suggestion:
              'Refactor to use async function with await expressions.',
          sourceCode: _truncateSource(node.toSource()),
        ));
      }
    }

    super.visitMethodInvocation(node);
  }

  /// Checks if the .then() callback contains nested .then() calls.
  bool _hasNestedThen(MethodInvocation thenCall) {
    if (thenCall.argumentList.arguments.isEmpty) {
      return false;
    }

    final callback = thenCall.argumentList.arguments.first;
    if (callback is FunctionExpression) {
      final nestedVisitor = _NestedThenVisitor();
      callback.body.accept(nestedVisitor);
      return nestedVisitor.hasThen;
    }

    return false;
  }

  String _truncateSource(String source) {
    const maxLength = 80;
    if (source.length <= maxLength) {
      return source;
    }
    return '${source.substring(0, maxLength)}...';
  }
}

class _NestedThenVisitor extends RecursiveAstVisitor<void> {
  bool hasThen = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'then') {
      hasThen = true;
    }
    super.visitMethodInvocation(node);
  }
}
