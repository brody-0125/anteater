import '../frontend/source_loader.dart';
import '../metrics/metrics_aggregator.dart';
import '../server/language_server.dart';

/// High-level API for Anteater static analysis.
///
/// Provides simple, one-liner methods for common analysis operations.
/// Handles resource management automatically.
///
/// Example:
/// ```dart
/// // Analyze metrics with default thresholds
/// final report = await Anteater.analyzeMetrics('lib');
/// print(report);
///
/// // Analyze with custom thresholds
/// final report = await Anteater.analyzeMetrics(
///   'lib',
///   thresholds: MetricsThresholds(maxCyclomatic: 15),
/// );
///
/// // Run full project analysis
/// final result = await Anteater.analyze('lib');
/// print('Found ${result.errorCount} errors');
/// ```
class Anteater {
  /// Private constructor to prevent instantiation.
  Anteater._();

  /// Analyzes code metrics for a directory or file.
  ///
  /// Automatically handles resource cleanup. Returns an [AggregatedReport]
  /// containing project-wide metrics, violations, and health score.
  ///
  /// [path] is the directory or file to analyze.
  /// [thresholds] configures violation detection limits.
  ///
  /// Example:
  /// ```dart
  /// final report = await Anteater.analyzeMetrics('lib');
  /// if (report.hasViolations) {
  ///   for (final violation in report.violations) {
  ///     print('${violation.functionName}: MI=${violation.result.maintainabilityIndex}');
  ///   }
  /// }
  /// ```
  static Future<AggregatedReport> analyzeMetrics(
    String path, {
    MetricsThresholds thresholds = const MetricsThresholds(),
  }) async {
    final loader = SourceLoader(path);
    try {
      final aggregator = MetricsAggregator(thresholds: thresholds);

      for (final file in loader.discoverDartFiles()) {
        final result = await loader.resolveFile(file);
        if (result != null) {
          aggregator.addFile(file, result.unit);
        }
      }

      return aggregator.generateReport();
    } finally {
      await loader.dispose();
    }
  }

  /// Analyzes a project for diagnostics (errors, warnings, info).
  ///
  /// Automatically handles resource cleanup. Returns a [ProjectAnalysisResult]
  /// containing all diagnostics organized by file.
  ///
  /// [path] is the project directory to analyze.
  ///
  /// Example:
  /// ```dart
  /// final result = await Anteater.analyze('lib');
  /// print('Files: ${result.fileCount}');
  /// print('Errors: ${result.errorCount}');
  /// print('Warnings: ${result.warningCount}');
  ///
  /// for (final entry in result.diagnostics.entries) {
  ///   print('${entry.key}: ${entry.value.length} issues');
  /// }
  /// ```
  static Future<ProjectAnalysisResult> analyze(String path) async {
    final server = AnteaterLanguageServer(path);
    await server.initialize();
    try {
      return await server.analyzeProject();
    } finally {
      await server.shutdown();
    }
  }

  /// Analyzes a single file for metrics.
  ///
  /// Returns [FunctionMetrics] for each function in the file,
  /// or an empty list if the file cannot be parsed.
  ///
  /// [filePath] is the path to the Dart file.
  /// [thresholds] configures violation detection limits.
  ///
  /// Example:
  /// ```dart
  /// final functions = await Anteater.analyzeFile('lib/main.dart');
  /// for (final func in functions) {
  ///   print('${func.functionName}: CC=${func.result.cyclomaticComplexity}');
  /// }
  /// ```
  static Future<List<FunctionMetrics>> analyzeFile(
    String filePath, {
    MetricsThresholds thresholds = const MetricsThresholds(),
  }) async {
    final loader = SourceLoader(filePath);
    try {
      final result = await loader.resolveFile(filePath);
      if (result == null) return [];

      final aggregator = MetricsAggregator(thresholds: thresholds);
      aggregator.addFile(filePath, result.unit);

      final report = aggregator.generateReport();
      return report.worstFunctions;
    } finally {
      await loader.dispose();
    }
  }
}
