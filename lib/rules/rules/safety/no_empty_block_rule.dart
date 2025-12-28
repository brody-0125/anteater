import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../../rule.dart';

/// Rule that disallows empty blocks.
///
/// Empty blocks often indicate incomplete code or forgotten logic.
/// If intentionally empty, add a comment explaining why.
class NoEmptyBlockRule extends StyleRule {
  @override
  String get id => 'no-empty-block';

  @override
  String get description =>
      'Avoid empty blocks. Add logic or a comment explaining why empty.';

  @override
  RuleSeverity get defaultSeverity => RuleSeverity.warning;

  @override
  RuleCategory get category => RuleCategory.safety;

  @override
  List<Violation> check(CompilationUnit unit, {LineInfo? lineInfo}) {
    final effectiveLineInfo = lineInfo ?? unit.lineInfo;
    final visitor = _NoEmptyBlockVisitor(effectiveLineInfo);
    unit.accept(visitor);
    return visitor.violations;
  }
}

class _NoEmptyBlockVisitor extends RecursiveAstVisitor<void> {
  final LineInfo lineInfo;
  final List<Violation> violations = [];

  _NoEmptyBlockVisitor(this.lineInfo);

  @override
  void visitBlock(Block node) {
    if (_isEmptyBlock(node)) {
      // Check if parent is a catch clause (empty catch is common pattern)
      final parent = node.parent;
      if (parent is CatchClause) {
        // Empty catch blocks are handled separately
        violations.add(Violation(
          ruleId: 'no-empty-block',
          message: 'Empty catch block. Handle the exception or add a comment.',
          location: SourceRange.fromNode(node, lineInfo),
          severity: RuleSeverity.warning,
          suggestion:
              'Log the error, rethrow, or add // ignore comment if intentional.',
          sourceCode: node.toSource(),
        ));
      } else if (parent is FunctionExpression || parent is MethodDeclaration) {
        // Empty function/method bodies might be intentional (abstract-like)
        violations.add(Violation(
          ruleId: 'no-empty-block',
          message: 'Empty function body. Add implementation or a comment.',
          location: SourceRange.fromNode(node, lineInfo),
          severity: RuleSeverity.info,
          suggestion: 'Add implementation, throw UnimplementedError(), '
              'or add a comment explaining why empty.',
          sourceCode: node.toSource(),
        ));
      } else {
        violations.add(Violation(
          ruleId: 'no-empty-block',
          message: 'Empty block found.',
          location: SourceRange.fromNode(node, lineInfo),
          severity: RuleSeverity.warning,
          suggestion: 'Add logic or a comment explaining why empty.',
          sourceCode: node.toSource(),
        ));
      }
    }
    super.visitBlock(node);
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    // Check for empty switch statement
    if (node.members.isEmpty) {
      violations.add(Violation(
        ruleId: 'no-empty-block',
        message: 'Empty switch statement.',
        location: SourceRange.fromNode(node, lineInfo),
        severity: RuleSeverity.warning,
        suggestion: 'Add case clauses or remove the switch statement.',
        sourceCode: 'switch (...) {}',
      ));
    }
    super.visitSwitchStatement(node);
  }

  bool _isEmptyBlock(Block block) {
    // A block is considered empty if it has no statements
    // and no meaningful comments
    if (block.statements.isNotEmpty) {
      return false;
    }

    // Check for comments inside the block
    // This is a simplified check; a full implementation would
    // parse comments from the token stream
    final source = block.toSource();
    if (source.contains('//') || source.contains('/*')) {
      return false;
    }

    return true;
  }
}
