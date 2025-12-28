import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../metrics/maintainability_index.dart';
import '../rules/rule.dart';
import 'debt_config.dart';
import 'debt_item.dart';

/// Detects technical debt items in Dart source code.
class DebtDetector {
  final DebtCostConfig config;

  DebtDetector({DebtCostConfig? config})
      : config = config ?? DebtCostConfig.defaults();

  /// Detect all debt items in a compilation unit.
  ///
  /// If [sourceCode] is provided, it will be used for comment detection.
  /// Otherwise, the source is reconstructed from the compilation unit,
  /// which may not include comments.
  List<DebtItem> detect(
    CompilationUnit unit,
    String filePath, {
    LineInfo? lineInfo,
    FileMaintainabilityResult? metrics,
    String? sourceCode,
  }) {
    final info = lineInfo ?? unit.lineInfo;

    final items = <DebtItem>[];

    // Detect comment-based debt (TODO, FIXME, ignore)
    // Use provided source code for accurate comment detection
    final source = sourceCode ?? _extractSourceWithComments(unit);
    items.addAll(_detectCommentDebt(source, filePath, info));

    // Detect cast-based debt (as dynamic)
    items.addAll(_detectCastDebt(unit, filePath, info));

    // Detect annotation-based debt (@deprecated)
    items.addAll(_detectAnnotationDebt(unit, filePath, info));

    // Detect metrics-based debt
    if (metrics != null) {
      items.addAll(_detectMetricsDebt(metrics, filePath, info));
    }

    return items;
  }

  /// Extract source with comments from token stream.
  String _extractSourceWithComments(CompilationUnit unit) {
    final buffer = StringBuffer();
    var token = unit.beginToken;

    while (token.type != TokenType.EOF) {
      // Add preceding comments
      var comment = token.precedingComments;
      while (comment != null) {
        buffer.write(comment.lexeme);
        buffer.write('\n');
        comment = comment.next as CommentToken?;
      }
      buffer.write(token.lexeme);
      buffer.write(' ');
      token = token.next!;
    }

    return buffer.toString();
  }

  /// Detect TODO, FIXME, and ignore comments.
  List<DebtItem> _detectCommentDebt(
    String source,
    String filePath,
    LineInfo lineInfo,
  ) {
    final items = <DebtItem>[];

    // Patterns for detecting debt comments
    final todoPattern = RegExp(r'//\s*TODO[:\s](.*)$', multiLine: true);
    final fixmePattern = RegExp(r'//\s*FIXME[:\s](.*)$', multiLine: true);
    final ignorePattern =
        RegExp(r'//\s*ignore:\s*([a-z_,\s]+)', multiLine: true);
    final ignoreForFilePattern =
        RegExp(r'//\s*ignore_for_file:\s*([a-z_,\s]+)', multiLine: true);

    // Find TODO comments
    for (final match in todoPattern.allMatches(source)) {
      items.add(_createCommentDebtItem(
        type: DebtType.todo,
        match: match,
        filePath: filePath,
        lineInfo: lineInfo,
        description: 'TODO: ${match.group(1)?.trim() ?? ""}',
      ));
    }

    // Find FIXME comments
    for (final match in fixmePattern.allMatches(source)) {
      items.add(_createCommentDebtItem(
        type: DebtType.fixme,
        match: match,
        filePath: filePath,
        lineInfo: lineInfo,
        description: 'FIXME: ${match.group(1)?.trim() ?? ""}',
      ));
    }

    // Find ignore comments
    for (final match in ignorePattern.allMatches(source)) {
      final rules = match.group(1)?.trim() ?? '';
      items.add(_createCommentDebtItem(
        type: DebtType.ignoreComment,
        match: match,
        filePath: filePath,
        lineInfo: lineInfo,
        description: 'Suppressed warnings: $rules',
      ));
    }

    // Find ignore_for_file comments
    for (final match in ignoreForFilePattern.allMatches(source)) {
      final rules = match.group(1)?.trim() ?? '';
      items.add(_createCommentDebtItem(
        type: DebtType.ignoreForFile,
        match: match,
        filePath: filePath,
        lineInfo: lineInfo,
        description: 'File-level suppression: $rules',
      ));
    }

    return items;
  }

  DebtItem _createCommentDebtItem({
    required DebtType type,
    required RegExpMatch match,
    required String filePath,
    required LineInfo lineInfo,
    required String description,
  }) {
    final location = SourceRange.fromOffset(match.start, match.end - match.start, lineInfo);
    return DebtItem(
      type: type,
      description: description,
      location: location,
      filePath: filePath,
      sourceCode: match.group(0),
    );
  }

  /// Detect `as dynamic` casts.
  List<DebtItem> _detectCastDebt(
    CompilationUnit unit,
    String filePath,
    LineInfo lineInfo,
  ) {
    final visitor = _CastDebtVisitor(filePath, lineInfo);
    unit.accept(visitor);
    return visitor.items;
  }

  /// Detect @deprecated usage.
  List<DebtItem> _detectAnnotationDebt(
    CompilationUnit unit,
    String filePath,
    LineInfo lineInfo,
  ) {
    final visitor = _AnnotationDebtVisitor(filePath, lineInfo);
    unit.accept(visitor);
    return visitor.items;
  }

  /// Detect metrics-based debt (low MI, high complexity, long methods).
  List<DebtItem> _detectMetricsDebt(
    FileMaintainabilityResult metrics,
    String filePath,
    LineInfo lineInfo,
  ) {
    final items = <DebtItem>[];
    final thresholds = config.metricsThresholds;

    for (final entry in metrics.functions.entries) {
      final name = entry.key;
      final result = entry.value;

      // Low maintainability index
      if (result.maintainabilityIndex < thresholds.maintainabilityIndex) {
        items.add(DebtItem(
          type: DebtType.lowMaintainability,
          description:
              'Maintainability Index ${result.maintainabilityIndex.toStringAsFixed(1)} '
              '< ${thresholds.maintainabilityIndex}',
          location: SourceRange.zero,
          filePath: filePath,
          context: name,
        ));
      }

      // High cyclomatic complexity
      if (result.cyclomaticComplexity > thresholds.cyclomaticComplexity) {
        items.add(DebtItem(
          type: DebtType.highComplexity,
          description:
              'Cyclomatic complexity ${result.cyclomaticComplexity} '
              '> ${thresholds.cyclomaticComplexity}',
          location: SourceRange.zero,
          filePath: filePath,
          context: name,
        ));
      }

      // Long method
      if (result.linesOfCode > thresholds.linesOfCode) {
        items.add(DebtItem(
          type: DebtType.longMethod,
          description:
              'Lines of code ${result.linesOfCode} > ${thresholds.linesOfCode}',
          location: SourceRange.zero,
          filePath: filePath,
          context: name,
        ));
      }
    }

    return items;
  }
}

/// Visitor to detect `as dynamic` casts.
class _CastDebtVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final LineInfo lineInfo;
  final List<DebtItem> items = [];

  _CastDebtVisitor(this.filePath, this.lineInfo);

  @override
  void visitAsExpression(AsExpression node) {
    final targetType = node.type;
    if (targetType is NamedType && targetType.name.lexeme == 'dynamic') {
      items.add(DebtItem(
        type: DebtType.asDynamic,
        description: 'Cast to dynamic type',
        location: SourceRange.fromNode(node, lineInfo),
        filePath: filePath,
        sourceCode: node.toSource(),
        context: _getEnclosingContext(node),
      ));
    }
    super.visitAsExpression(node);
  }

  String? _getEnclosingContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionDeclaration) {
        return current.name.lexeme;
      }
      if (current is MethodDeclaration) {
        final parent = current.parent;
        if (parent is ClassDeclaration) {
          return '${parent.name.lexeme}.${current.name.lexeme}';
        }
        return current.name.lexeme;
      }
      current = current.parent;
    }
    return null;
  }
}

/// Visitor to detect @deprecated usage.
class _AnnotationDebtVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final LineInfo lineInfo;
  final List<DebtItem> items = [];

  _AnnotationDebtVisitor(this.filePath, this.lineInfo);

  @override
  void visitAnnotation(Annotation node) {
    final name = node.name.name;
    if (name == 'deprecated' || name == 'Deprecated') {
      final parent = node.parent;
      String? context;
      String description = 'Usage of @deprecated';

      if (parent is Declaration) {
        context = _getDeclarationName(parent);
        if (context != null) {
          description = '@deprecated on $context';
        }
      }

      items.add(DebtItem(
        type: DebtType.deprecated,
        description: description,
        location: SourceRange.fromNode(node, lineInfo),
        filePath: filePath,
        context: context,
      ));
    }
    super.visitAnnotation(node);
  }

  String? _getDeclarationName(Declaration declaration) {
    if (declaration is FunctionDeclaration) {
      return declaration.name.lexeme;
    }
    if (declaration is MethodDeclaration) {
      final parent = declaration.parent;
      if (parent is ClassDeclaration) {
        return '${parent.name.lexeme}.${declaration.name.lexeme}';
      }
      return declaration.name.lexeme;
    }
    if (declaration is ClassDeclaration) {
      return declaration.name.lexeme;
    }
    if (declaration is FieldDeclaration) {
      return declaration.fields.variables.first.name.lexeme;
    }
    if (declaration is TopLevelVariableDeclaration) {
      return declaration.variables.variables.first.name.lexeme;
    }
    return null;
  }
}
