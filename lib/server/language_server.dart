import 'dart:async';

import 'package:analyzer/dart/ast/ast.dart';

import '../frontend/source_loader.dart';
import '../metrics/complexity_calculator.dart';
import '../metrics/maintainability_index.dart';

/// Anteater Language Server for IDE integration.
///
/// Provides static analysis results via LSP (Language Server Protocol).
class AnteaterLanguageServer {
  final String projectPath;
  late final SourceLoader _sourceLoader;
  late final ComplexityCalculator _complexityCalculator;
  late final MaintainabilityIndexCalculator _miCalculator;

  bool _initialized = false;

  AnteaterLanguageServer(this.projectPath);

  /// Initializes the language server.
  Future<void> initialize() async {
    if (_initialized) return;

    _sourceLoader = SourceLoader(projectPath);
    _complexityCalculator = ComplexityCalculator();
    _miCalculator = MaintainabilityIndexCalculator(_complexityCalculator);

    _initialized = true;
  }

  /// Analyzes a file and returns diagnostics.
  Future<List<Diagnostic>> analyzeFile(String filePath) async {
    if (!_initialized) {
      throw StateError('Server not initialized');
    }

    final diagnostics = <Diagnostic>[];
    final result = await _sourceLoader.resolveFile(filePath);

    if (result == null) {
      return diagnostics;
    }

    // Calculate file-level metrics
    final fileResult = _miCalculator.calculateForFile(result.unit);

    // Report functions with poor maintainability (ADR-015 1.3 - actual source positions)
    for (final entry in fileResult.needsAttention) {
      final node = _findFunctionNode(result.unit, entry.key);
      final range = node != null
          ? _nodeToRange(result.unit, node)
          : Range.zero;

      diagnostics.add(Diagnostic(
        message:
            'Function "${entry.key}" has low maintainability index: ${entry.value.maintainabilityIndex.toStringAsFixed(1)}',
        severity: DiagnosticSeverity.warning,
        range: range,
        source: 'anteater',
        code: 'low_maintainability_index',
      ));
    }

    // Check cyclomatic complexity thresholds
    for (final entry in fileResult.functions.entries) {
      final node = _findFunctionNode(result.unit, entry.key);
      final range = node != null
          ? _nodeToRange(result.unit, node)
          : Range.zero;

      if (entry.value.cyclomaticComplexity > 20) {
        diagnostics.add(Diagnostic(
          message:
              'Function "${entry.key}" has high cyclomatic complexity: ${entry.value.cyclomaticComplexity}',
          severity: DiagnosticSeverity.warning,
          range: range,
          source: 'anteater',
          code: 'high_cyclomatic_complexity',
        ));
      }

      if (entry.value.cognitiveComplexity > 15) {
        diagnostics.add(Diagnostic(
          message:
              'Function "${entry.key}" has high cognitive complexity: ${entry.value.cognitiveComplexity}',
          severity: DiagnosticSeverity.hint,
          range: range,
          source: 'anteater',
          code: 'high_cognitive_complexity',
        ));
      }
    }

    return diagnostics;
  }

  /// Finds a function node by name in the compilation unit (ADR-015 1.3).
  AstNode? _findFunctionNode(CompilationUnit unit, String name) {
    // Handle qualified names like "ClassName.methodName"
    final parts = name.split('.');
    final simpleName = parts.last;
    final className = parts.length > 1 ? parts.first : null;

    for (final declaration in unit.declarations) {
      if (declaration is FunctionDeclaration &&
          declaration.name.lexeme == simpleName &&
          className == null) {
        return declaration;
      }
      if (declaration is ClassDeclaration &&
          (className == null || declaration.name.lexeme == className)) {
        for (final member in declaration.members) {
          if (member is MethodDeclaration && member.name.lexeme == simpleName) {
            return member;
          }
        }
      }
    }
    return null;
  }

  /// Converts an AST node to an LSP Range (ADR-015 1.3).
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

  /// Analyzes all files in the project.
  Future<ProjectAnalysisResult> analyzeProject() async {
    if (!_initialized) {
      throw StateError('Server not initialized');
    }

    final files = _sourceLoader.discoverDartFiles();
    final fileResults = <String, List<Diagnostic>>{};

    for (final file in files) {
      fileResults[file] = await analyzeFile(file);
    }

    return ProjectAnalysisResult(
      fileCount: files.length,
      diagnostics: fileResults,
    );
  }

  /// Shuts down the server (ADR-016 3.3 - properly await dispose).
  Future<void> shutdown() async {
    await _sourceLoader.dispose();
    _initialized = false;
  }
}

/// A diagnostic message.
class Diagnostic {
  final String message;
  final DiagnosticSeverity severity;
  final Range range;
  final String source;
  final String? code;

  const Diagnostic({
    required this.message,
    required this.severity,
    required this.range,
    required this.source,
    this.code,
  });

  Map<String, dynamic> toJson() => {
        'message': message,
        'severity': severity.index,
        'range': range.toJson(),
        'source': source,
        if (code != null) 'code': code,
      };

  @override
  String toString() => '[$severity] $message';
}

/// Diagnostic severity levels.
enum DiagnosticSeverity {
  error,
  warning,
  info,
  hint,
}

/// A source range.
class Range {
  final Position start;
  final Position end;

  const Range({required this.start, required this.end});

  static const Range zero = Range(
    start: Position(line: 0, character: 0),
    end: Position(line: 0, character: 0),
  );

  Map<String, dynamic> toJson() => {
        'start': start.toJson(),
        'end': end.toJson(),
      };
}

/// A position in source code.
class Position {
  final int line;
  final int character;

  const Position({required this.line, required this.character});

  Map<String, dynamic> toJson() => {
        'line': line,
        'character': character,
      };
}

/// Result of analyzing an entire project.
class ProjectAnalysisResult {
  final int fileCount;
  final Map<String, List<Diagnostic>> diagnostics;

  const ProjectAnalysisResult({
    required this.fileCount,
    required this.diagnostics,
  });

  int get totalDiagnostics =>
      diagnostics.values.fold(0, (sum, list) => sum + list.length);

  int get errorCount => _countBySeverity(DiagnosticSeverity.error);
  int get warningCount => _countBySeverity(DiagnosticSeverity.warning);
  int get infoCount => _countBySeverity(DiagnosticSeverity.info);

  int _countBySeverity(DiagnosticSeverity severity) {
    return diagnostics.values.fold(
      0,
      (sum, list) => sum + list.where((d) => d.severity == severity).length,
    );
  }

  @override
  String toString() => '''
ProjectAnalysisResult(
  files: $fileCount
  diagnostics: $totalDiagnostics
  errors: $errorCount
  warnings: $warningCount
)''';
}
