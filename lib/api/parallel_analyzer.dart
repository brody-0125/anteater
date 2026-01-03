import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:path/path.dart' as path;

import '../metrics/maintainability_index.dart';
import '../metrics/metrics_aggregator.dart';

/// Progress callback for parallel analysis.
///
/// [completed] is the number of files processed.
/// [total] is the total number of files to process.
/// [currentFile] is the path of the file being processed.
typedef AnalysisProgressCallback = void Function(
  int completed,
  int total,
  String currentFile,
);

/// Configuration for parallel analysis.
class ParallelAnalysisConfig {
  const ParallelAnalysisConfig({
    this.maxConcurrency = 4,
    this.chunkSize = 50,
    this.thresholds = const MetricsThresholds(),
  });

  /// Maximum number of concurrent file analyses.
  ///
  /// Higher values use more memory but complete faster.
  /// Recommended: 2-8 depending on available memory.
  final int maxConcurrency;

  /// Number of files to process before yielding to GC.
  ///
  /// Helps manage memory for large projects.
  final int chunkSize;

  /// Metrics thresholds for violation detection.
  final MetricsThresholds thresholds;
}

/// Result of analyzing a single file.
class FileAnalysisResult {
  const FileAnalysisResult({
    required this.path,
    required this.fileResult,
    required this.functions,
    this.error,
  });

  /// File path.
  final String path;

  /// File-level maintainability result.
  final FileMaintainabilityResult? fileResult;

  /// Function-level metrics.
  final List<FunctionMetrics> functions;

  /// Error message if analysis failed.
  final String? error;

  bool get isSuccess => error == null && fileResult != null;
}

/// Parallel analyzer for large codebases.
///
/// Processes multiple files concurrently using async/await parallelism.
/// Supports progress callbacks and memory-efficient chunked processing.
///
/// Example:
/// ```dart
/// final analyzer = ParallelAnalyzer('lib');
///
/// // With progress tracking
/// final report = await analyzer.analyzeWithProgress(
///   onProgress: (completed, total, file) {
///     print('[$completed/$total] Analyzing $file');
///   },
/// );
///
/// print('Health Score: ${report.healthScore}');
/// await analyzer.dispose();
/// ```
class ParallelAnalyzer {
  ParallelAnalyzer(
    this.projectPath, {
    ParallelAnalysisConfig? config,
  }) : config = config ?? const ParallelAnalysisConfig() {
    _contextCollection = AnalysisContextCollection(
      includedPaths: [path.absolute(projectPath)],
    );
  }

  final String projectPath;
  final ParallelAnalysisConfig config;
  late final AnalysisContextCollection _contextCollection;

  final MaintainabilityIndexCalculator _calculator =
      MaintainabilityIndexCalculator();

  /// Discovers all Dart files in the project.
  List<String> discoverFiles() {
    final absolutePath = path.absolute(projectPath);

    if (FileSystemEntity.isFileSync(absolutePath)) {
      if (absolutePath.endsWith('.dart')) {
        return [absolutePath];
      }
      return [];
    }

    final files = <String>[];
    final dir = Directory(absolutePath);

    if (!dir.existsSync()) {
      return [];
    }

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        if (!entity.path.contains('.g.dart') &&
            !entity.path.contains('.freezed.dart')) {
          files.add(entity.path);
        }
      }
    }

    return files;
  }

  /// Analyzes all files with progress reporting.
  ///
  /// Returns an [AggregatedReport] with project-wide metrics.
  Future<AggregatedReport> analyzeWithProgress({
    AnalysisProgressCallback? onProgress,
  }) async {
    final files = discoverFiles();
    final aggregator = MetricsAggregator(thresholds: config.thresholds);

    if (files.isEmpty) {
      return aggregator.generateReport();
    }

    // Process files in chunks for memory efficiency
    final chunks = _chunkList(files, config.chunkSize);
    var completed = 0;

    for (final chunk in chunks) {
      // Process chunk with limited concurrency
      final results = await _processChunkParallel(
        chunk,
        onProgress: (file) {
          completed++;
          onProgress?.call(completed, files.length, file);
        },
      );

      // Aggregate results
      for (final result in results) {
        if (result.isSuccess && result.fileResult != null) {
          aggregator.addPrecomputedResult(
            result.path,
            result.fileResult!,
            result.functions,
          );
        }
      }

      // Yield to allow GC between chunks
      await Future<void>.delayed(Duration.zero);
    }

    return aggregator.generateReport();
  }

  /// Analyzes files and streams results.
  ///
  /// Memory-efficient for very large projects as results are
  /// yielded immediately after processing.
  Stream<FileAnalysisResult> analyzeStream() async* {
    final files = discoverFiles();

    for (final file in files) {
      yield await _analyzeFile(file);
    }
  }

  /// Analyzes files in parallel and streams results.
  ///
  /// Combines parallel processing with streaming for optimal
  /// throughput and memory efficiency.
  Stream<FileAnalysisResult> analyzeParallelStream() async* {
    final files = discoverFiles();
    final chunks = _chunkList(files, config.chunkSize);

    for (final chunk in chunks) {
      final results = await _processChunkParallel(chunk);
      for (final result in results) {
        yield result;
      }
    }
  }

  /// Analyzes a single file.
  Future<FileAnalysisResult> _analyzeFile(String filePath) async {
    try {
      final absolutePath = path.absolute(filePath);
      final context = _contextCollection.contextFor(absolutePath);
      final result = await context.currentSession.getResolvedUnit(absolutePath);

      if (result is! ResolvedUnitResult) {
        return FileAnalysisResult(
          path: filePath,
          fileResult: null,
          functions: [],
          error: 'Failed to resolve file',
        );
      }

      final fileResult = _calculator.calculateForFile(result.unit);
      final functions = <FunctionMetrics>[];

      for (final entry in fileResult.functions.entries) {
        functions.add(FunctionMetrics(
          filePath: filePath,
          functionName: entry.key,
          result: entry.value,
        ));
      }

      return FileAnalysisResult(
        path: filePath,
        fileResult: fileResult,
        functions: functions,
      );
    } catch (e) {
      return FileAnalysisResult(
        path: filePath,
        fileResult: null,
        functions: [],
        error: e.toString(),
      );
    }
  }

  /// Processes a chunk of files with limited concurrency.
  ///
  /// Uses a semaphore-style approach to limit concurrent file analysis.
  Future<List<FileAnalysisResult>> _processChunkParallel(
    List<String> files, {
    void Function(String)? onProgress,
  }) async {
    final results = <FileAnalysisResult>[];
    var activeCount = 0;
    var nextIndex = 0;
    final completer = Completer<void>();
    final completedCount = <int>[0];

    void processNext() {
      while (activeCount < config.maxConcurrency && nextIndex < files.length) {
        final file = files[nextIndex++];
        activeCount++;

        _analyzeFile(file).then((result) {
          results.add(result);
          onProgress?.call(file);
          activeCount--;
          completedCount[0]++;

          if (completedCount[0] == files.length) {
            completer.complete();
          } else {
            processNext();
          }
        });
      }
    }

    if (files.isEmpty) {
      return results;
    }

    processNext();
    await completer.future;

    return results;
  }

  /// Splits a list into chunks.
  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      final end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }

  /// Releases resources.
  Future<void> dispose() async {
    await _contextCollection.dispose();
  }
}
