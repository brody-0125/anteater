import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../frontend/source_loader.dart';
import '../metrics/complexity_calculator.dart';
import '../metrics/maintainability_index.dart';
import 'language_server.dart';

/// Provides hover information for code elements.
///
/// Displays metrics and analysis information when hovering over
/// functions, methods, and classes in the IDE.
class HoverProvider {
  HoverProvider({required SourceLoader sourceLoader})
      : _sourceLoader = sourceLoader,
        _miCalculator = MaintainabilityIndexCalculator(ComplexityCalculator());

  final SourceLoader _sourceLoader;
  final MaintainabilityIndexCalculator _miCalculator;

  /// Returns hover information for the given position.
  Future<Hover?> getHover({
    required String filePath,
    required Position position,
  }) async {
    final result = await _sourceLoader.resolveFile(filePath);
    if (result == null) return null;

    final unit = result.unit;
    final offset = _positionToOffset(unit, position);
    if (offset == null) return null;

    // Find the node at the position
    final node = _findNodeAtOffset(unit, offset);
    if (node == null) return null;

    // Find containing function or method
    final function = _findContainingFunction(node);
    if (function != null) {
      return _createFunctionHover(unit, function);
    }

    // Find containing class
    final classDecl = _findContainingClass(node);
    if (classDecl != null) {
      return _createClassHover(unit, classDecl);
    }

    return null;
  }

  /// Creates hover info for a function or method.
  Hover _createFunctionHover(CompilationUnit unit, AstNode function) {
    final name = _getFunctionName(function);
    final metrics = _calculateFunctionMetrics(function);

    final markdown = StringBuffer();
    markdown.writeln('**Metrics for `$name`**');
    markdown.writeln();
    markdown.writeln('| Metric | Value | Status |');
    markdown.writeln('|--------|-------|--------|');
    markdown.writeln(
        '| Cyclomatic Complexity | ${metrics.cyclomatic} | ${_statusIcon(metrics.cyclomatic, 20)} |');
    markdown.writeln(
        '| Cognitive Complexity | ${metrics.cognitive} | ${_statusIcon(metrics.cognitive, 15)} |');
    markdown.writeln(
        '| Maintainability Index | ${metrics.mi.toStringAsFixed(1)} | ${_miStatusIcon(metrics.mi)} |');
    markdown.writeln('| Lines of Code | ${metrics.loc} | - |');

    if (metrics.halstead != null) {
      markdown.writeln();
      markdown.writeln('**Halstead Metrics**');
      markdown.writeln();
      markdown.writeln(
          '- Volume: ${metrics.halstead!.volume.toStringAsFixed(1)}');
      markdown.writeln(
          '- Difficulty: ${metrics.halstead!.difficulty.toStringAsFixed(2)}');
      markdown.writeln(
          '- Effort: ${metrics.halstead!.effort.toStringAsFixed(1)}');
    }

    return Hover(
      contents: HoverContents(
        kind: MarkupKind.markdown,
        value: markdown.toString(),
      ),
      range: _nodeToRange(unit, function),
    );
  }

  /// Creates hover info for a class.
  Hover _createClassHover(CompilationUnit unit, ClassDeclaration classDecl) {
    final name = classDecl.name.lexeme;
    final methodCount =
        classDecl.members.whereType<MethodDeclaration>().length;
    final fieldCount = classDecl.members.whereType<FieldDeclaration>().length;

    // Calculate aggregate metrics for all methods
    var totalCyclomatic = 0;
    var totalCognitive = 0;
    var methodsAnalyzed = 0;

    for (final member in classDecl.members) {
      if (member is MethodDeclaration) {
        final metrics = _calculateFunctionMetrics(member);
        totalCyclomatic += metrics.cyclomatic;
        totalCognitive += metrics.cognitive;
        methodsAnalyzed++;
      }
    }

    final avgCyclomatic =
        methodsAnalyzed > 0 ? totalCyclomatic / methodsAnalyzed : 0.0;
    final avgCognitive =
        methodsAnalyzed > 0 ? totalCognitive / methodsAnalyzed : 0.0;

    final markdown = StringBuffer();
    markdown.writeln('**Class `$name`**');
    markdown.writeln();
    markdown.writeln('| Property | Value |');
    markdown.writeln('|----------|-------|');
    markdown.writeln('| Methods | $methodCount |');
    markdown.writeln('| Fields | $fieldCount |');
    markdown.writeln(
        '| Avg Cyclomatic Complexity | ${avgCyclomatic.toStringAsFixed(1)} |');
    markdown.writeln(
        '| Avg Cognitive Complexity | ${avgCognitive.toStringAsFixed(1)} |');

    // Check for potential issues
    final issues = <String>[];
    if (methodCount > 20) {
      issues.add('Too many methods (consider splitting)');
    }
    if (fieldCount > 10) {
      issues.add('Too many fields (consider data class extraction)');
    }
    if (avgCyclomatic > 10) {
      issues.add('High average complexity');
    }

    if (issues.isNotEmpty) {
      markdown.writeln();
      markdown.writeln('**Potential Issues**');
      for (final issue in issues) {
        markdown.writeln('- ⚠️ $issue');
      }
    }

    return Hover(
      contents: HoverContents(
        kind: MarkupKind.markdown,
        value: markdown.toString(),
      ),
      range: _nodeToRange(unit, classDecl),
    );
  }

  /// Calculates metrics for a function or method.
  _FunctionMetrics _calculateFunctionMetrics(AstNode function) {
    FunctionBody? body;

    if (function is FunctionDeclaration) {
      body = function.functionExpression.body;
    } else if (function is MethodDeclaration) {
      body = function.body;
    }

    if (body == null) {
      return _FunctionMetrics(
        cyclomatic: 1,
        cognitive: 0,
        mi: 100.0,
        loc: 0,
      );
    }

    final result = _miCalculator.calculate(body);
    return _FunctionMetrics(
      cyclomatic: result.cyclomaticComplexity,
      cognitive: result.cognitiveComplexity,
      mi: result.maintainabilityIndex,
      loc: result.linesOfCode,
      halstead: result.halsteadMetrics.volume > 0
          ? _HalsteadMetrics(
              volume: result.halsteadMetrics.volume,
              difficulty: result.halsteadMetrics.difficulty,
              effort: result.halsteadMetrics.effort,
            )
          : null,
    );
  }

  /// Finds the AST node at the given offset.
  AstNode? _findNodeAtOffset(CompilationUnit unit, int offset) {
    final finder = _NodeFinder(offset);
    unit.accept(finder);
    return finder.foundNode;
  }

  /// Finds the containing function declaration.
  AstNode? _findContainingFunction(AstNode node) {
    AstNode? current = node;
    while (current != null) {
      if (current is FunctionDeclaration || current is MethodDeclaration) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }

  /// Finds the containing class declaration.
  ClassDeclaration? _findContainingClass(AstNode node) {
    AstNode? current = node;
    while (current != null) {
      if (current is ClassDeclaration) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }

  /// Gets the name of a function or method.
  String _getFunctionName(AstNode node) {
    if (node is FunctionDeclaration) {
      return node.name.lexeme;
    } else if (node is MethodDeclaration) {
      return node.name.lexeme;
    }
    return '<anonymous>';
  }

  /// Converts a Position to an offset in the document.
  int? _positionToOffset(CompilationUnit unit, Position position) {
    try {
      final lineInfo = unit.lineInfo;
      return lineInfo.getOffsetOfLine(position.line) + position.character;
    } catch (e) {
      return null;
    }
  }

  /// Converts an AST node to a Range.
  Range _nodeToRange(CompilationUnit unit, AstNode node) {
    final lineInfo = unit.lineInfo;
    final startLocation = lineInfo.getLocation(node.offset);
    final endLocation = lineInfo.getLocation(node.end);

    return Range(
      start: Position(
        line: startLocation.lineNumber - 1,
        character: startLocation.columnNumber - 1,
      ),
      end: Position(
        line: endLocation.lineNumber - 1,
        character: endLocation.columnNumber - 1,
      ),
    );
  }

  /// Returns a status icon based on the value and threshold.
  String _statusIcon(int value, int threshold) {
    if (value <= threshold ~/ 2) return '✅';
    if (value <= threshold) return '🟡';
    return '⚠️';
  }

  /// Returns a status icon for maintainability index.
  String _miStatusIcon(double mi) {
    if (mi >= 80) return '🟢';
    if (mi >= 50) return '🟡';
    return '🔴';
  }
}

/// Internal class for function metrics.
class _FunctionMetrics {
  _FunctionMetrics({
    required this.cyclomatic,
    required this.cognitive,
    required this.mi,
    required this.loc,
    this.halstead,
  });

  final int cyclomatic;
  final int cognitive;
  final double mi;
  final int loc;
  final _HalsteadMetrics? halstead;
}

/// Internal class for Halstead metrics.
class _HalsteadMetrics {
  _HalsteadMetrics({
    required this.volume,
    required this.difficulty,
    required this.effort,
  });

  final double volume;
  final double difficulty;
  final double effort;
}

/// AST visitor to find the node at a specific offset.
class _NodeFinder extends GeneralizingAstVisitor<void> {
  _NodeFinder(this.targetOffset);

  final int targetOffset;
  AstNode? foundNode;

  @override
  void visitNode(AstNode node) {
    if (node.offset <= targetOffset && targetOffset <= node.end) {
      foundNode = node;
      super.visitNode(node);
    }
  }
}

/// Hover information to display in the IDE.
class Hover {
  const Hover({required this.contents, this.range});

  final HoverContents contents;
  final Range? range;

  Map<String, dynamic> toJson() => {
        'contents': contents.toJson(),
        if (range != null) 'range': range!.toJson(),
      };
}

/// Contents of a hover message.
class HoverContents {
  const HoverContents({required this.kind, required this.value});

  final MarkupKind kind;
  final String value;

  Map<String, dynamic> toJson() => {
        'kind': kind.value,
        'value': value,
      };
}

/// Markup kinds for hover content.
class MarkupKind {
  const MarkupKind._(this.value);

  final String value;

  static const plaintext = MarkupKind._('plaintext');
  static const markdown = MarkupKind._('markdown');

  @override
  String toString() => value;
}
