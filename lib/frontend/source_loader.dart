import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as path;

/// Loads and resolves Dart source files for analysis.
///
/// Uses the Dart Analyzer package to parse and resolve source files,
/// providing access to both syntax (AST) and semantics (resolved types).
///
/// Example:
/// ```dart
/// final loader = SourceLoader('lib');
///
/// // Discover all Dart files
/// for (final file in loader.discoverDartFiles()) {
///   // Get fully resolved AST with type information
///   final result = await loader.resolveFile(file);
///   if (result != null) {
///     print('${file}: ${result.unit.declarations.length} declarations');
///   }
/// }
///
/// // Always dispose when done
/// loader.dispose();
/// ```
///
/// Note: Always call [dispose] when finished to release analyzer resources.
/// For automatic cleanup, use [Anteater.analyzeMetrics] or [Anteater.analyze].
class SourceLoader {
  final String projectPath;
  late final AnalysisContextCollection _contextCollection;

  SourceLoader(this.projectPath) {
    _contextCollection = AnalysisContextCollection(
      includedPaths: [path.absolute(projectPath)],
    );
  }

  /// Returns all Dart files in the project.
  ///
  /// If [projectPath] is a single file, returns a list containing just that file.
  /// If [projectPath] is a directory, returns all Dart files in the directory
  /// (excluding generated files like .g.dart and .freezed.dart).
  List<String> discoverDartFiles() {
    // Handle single file path
    if (FileSystemEntity.isFileSync(projectPath)) {
      if (projectPath.endsWith('.dart')) {
        return [path.absolute(projectPath)];
      }
      return [];
    }

    // Handle directory path
    final files = <String>[];
    final dir = Directory(projectPath);

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        // Exclude generated files
        if (!entity.path.contains('.g.dart') &&
            !entity.path.contains('.freezed.dart')) {
          files.add(entity.path);
        }
      }
    }

    return files;
  }

  /// Parses a file and returns the resolved AST.
  Future<ResolvedUnitResult?> resolveFile(String filePath) async {
    final absolutePath = path.absolute(filePath);
    final context = _contextCollection.contextFor(absolutePath);
    final result = await context.currentSession.getResolvedUnit(absolutePath);

    if (result is ResolvedUnitResult) {
      return result;
    }
    return null;
  }

  /// Parses a file without resolution (faster, syntax only).
  Future<CompilationUnit?> parseFile(String filePath) async {
    final absolutePath = path.absolute(filePath);
    final context = _contextCollection.contextFor(absolutePath);
    final result = context.currentSession.getParsedUnit(absolutePath);

    if (result is ParsedUnitResult) {
      return result.unit;
    }
    return null;
  }

  /// Disposes resources.
  ///
  /// This method must be called when the loader is no longer needed
  /// to release analyzer resources and prevent memory leaks.
  /// In long-running server mode, failing to call this can cause
  /// memory growth and file handle exhaustion.
  Future<void> dispose() async {
    await _contextCollection.dispose();
  }
}
