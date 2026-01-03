import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../../rule.dart';

/// Rule that enforces trailing commas in multiline collections and arguments.
///
/// Trailing commas improve diff readability and make it easier to add/remove
/// items without modifying other lines.
class PreferTrailingCommaRule extends StyleRule {
  @override
  String get id => 'prefer-trailing-comma';

  @override
  String get description =>
      'Use trailing commas in multiline argument lists and collections.';

  @override
  RuleSeverity get defaultSeverity => RuleSeverity.info;

  @override
  RuleCategory get category => RuleCategory.quality;

  @override
  List<Violation> check(CompilationUnit unit, {LineInfo? lineInfo}) {
    final effectiveLineInfo = lineInfo ?? unit.lineInfo;
    final visitor = _PreferTrailingCommaVisitor(effectiveLineInfo);
    unit.accept(visitor);
    return visitor.violations;
  }
}

class _PreferTrailingCommaVisitor extends RecursiveAstVisitor<void> {
  _PreferTrailingCommaVisitor(this.lineInfo);

  final LineInfo lineInfo;
  final List<Violation> violations = [];

  @override
  void visitArgumentList(ArgumentList node) {
    _checkTrailingComma(
      node,
      node.arguments,
      node.leftParenthesis.offset,
      node.rightParenthesis.offset,
      'argument list',
    );
    super.visitArgumentList(node);
  }

  @override
  void visitFormalParameterList(FormalParameterList node) {
    _checkTrailingComma(
      node,
      node.parameters,
      node.leftParenthesis.offset,
      node.rightParenthesis.offset,
      'parameter list',
    );
    super.visitFormalParameterList(node);
  }

  @override
  void visitListLiteral(ListLiteral node) {
    _checkTrailingComma(
      node,
      node.elements,
      node.leftBracket.offset,
      node.rightBracket.offset,
      'list literal',
    );
    super.visitListLiteral(node);
  }

  @override
  void visitSetOrMapLiteral(SetOrMapLiteral node) {
    _checkTrailingComma(
      node,
      node.elements,
      node.leftBracket.offset,
      node.rightBracket.offset,
      node.isSet ? 'set literal' : 'map literal',
    );
    super.visitSetOrMapLiteral(node);
  }

  void _checkTrailingComma(
    AstNode node,
    List<AstNode> elements,
    int leftOffset,
    int rightOffset,
    String context,
  ) {
    // Skip empty lists
    if (elements.isEmpty) {
      return;
    }

    // Check if multiline
    final startLine = lineInfo.getLocation(leftOffset).lineNumber;
    final endLine = lineInfo.getLocation(rightOffset).lineNumber;

    if (startLine == endLine) {
      // Single line - no trailing comma needed
      return;
    }

    // Check if last element has a trailing comma using token-based detection
    final lastElement = elements.last;
    final lastToken = lastElement.endToken;

    // The next token after the last element should be either:
    // - A comma (trailing comma present)
    // - The closing bracket (no trailing comma)
    final nextToken = lastToken.next;
    if (nextToken != null && nextToken.lexeme != ',') {
      violations.add(Violation(
        ruleId: 'prefer-trailing-comma',
        message: 'Add trailing comma to multiline $context.',
        location: SourceRange.fromNode(lastElement, lineInfo),
        severity: RuleSeverity.info,
        suggestion: 'Add a comma after the last element.',
        sourceCode: lastElement.toSource(),
      ));
    }
  }
}
