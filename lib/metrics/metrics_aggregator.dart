import 'dart:math' as math;

import 'package:analyzer/dart/ast/ast.dart';

import 'maintainability_index.dart';

/// Aggregates metrics across multiple files for project-level analysis.
///
/// Provides:
/// - Project-wide statistics (averages, distributions)
/// - Hotspot identification (functions with poor metrics)
/// - Threshold-based violation detection
/// - Summary reports
class MetricsAggregator {
  final MaintainabilityIndexCalculator _calculator;

  /// Metrics thresholds for violation detection.
  final MetricsThresholds thresholds;

  /// File results indexed by path.
  final Map<String, FileMaintainabilityResult> _fileResults = {};

  /// Function metrics indexed by qualified name.
  final Map<String, FunctionMetrics> _functionMetrics = {};

  MetricsAggregator({
    MaintainabilityIndexCalculator? calculator,
    MetricsThresholds? thresholds,
  })  : _calculator = calculator ?? MaintainabilityIndexCalculator(),
        thresholds = thresholds ?? const MetricsThresholds();

  /// Adds a file to the aggregation.
  void addFile(String path, CompilationUnit unit) {
    final result = _calculator.calculateForFile(unit);
    _fileResults[path] = result;

    // Index individual functions
    for (final entry in result.functions.entries) {
      final qualifiedName = '$path::${entry.key}';
      _functionMetrics[qualifiedName] = FunctionMetrics(
        filePath: path,
        functionName: entry.key,
        result: entry.value,
      );
    }
  }

  /// Removes a file from the aggregation.
  void removeFile(String path) {
    _fileResults.remove(path);
    _functionMetrics.removeWhere((key, _) => key.startsWith('$path::'));
  }

  /// Clears all aggregated data.
  void clear() {
    _fileResults.clear();
    _functionMetrics.clear();
  }

  /// Returns the number of analyzed files.
  int get fileCount => _fileResults.length;

  /// Returns the number of analyzed functions.
  int get functionCount => _functionMetrics.length;

  /// Calculates project-wide statistics.
  ///
  /// ADR-016 2.1: Use List<num> directly to avoid cast<num>() wrapper lists.
  ProjectMetrics getProjectMetrics() {
    if (_functionMetrics.isEmpty) {
      return ProjectMetrics.empty();
    }

    // ADR-016 2.1: Use List<num> from start to avoid cast<num>()
    final miValues = <num>[];
    final cyclomaticValues = <num>[];
    final cognitiveValues = <num>[];
    final locValues = <num>[];
    var totalVolume = 0.0;
    var totalLoc = 0;

    for (final func in _functionMetrics.values) {
      miValues.add(func.result.maintainabilityIndex);
      cyclomaticValues.add(func.result.cyclomaticComplexity);
      cognitiveValues.add(func.result.cognitiveComplexity);
      locValues.add(func.result.linesOfCode);
      totalVolume += func.result.halsteadMetrics.volume;
      totalLoc += func.result.linesOfCode;
    }

    return ProjectMetrics(
      fileCount: fileCount,
      functionCount: functionCount,
      totalLinesOfCode: totalLoc,
      maintainabilityIndex: _calculateStats(miValues),
      cyclomaticComplexity: _calculateStats(cyclomaticValues),
      cognitiveComplexity: _calculateStats(cognitiveValues),
      linesOfCode: _calculateStats(locValues),
      totalHalsteadVolume: totalVolume,
    );
  }

  /// Returns functions that violate thresholds (hotspots).
  List<FunctionMetrics> getViolations() {
    return _functionMetrics.values.where((func) {
      return func.result.maintainabilityIndex < thresholds.minMaintainability ||
          func.result.cyclomaticComplexity > thresholds.maxCyclomatic ||
          func.result.cognitiveComplexity > thresholds.maxCognitive ||
          func.result.linesOfCode > thresholds.maxLinesOfCode;
    }).toList()
      ..sort((a, b) => a.result.maintainabilityIndex
          .compareTo(b.result.maintainabilityIndex));
  }

  /// Returns the top N functions with worst maintainability.
  List<FunctionMetrics> getWorstFunctions(int n) {
    final sorted = _functionMetrics.values.toList()
      ..sort((a, b) => a.result.maintainabilityIndex
          .compareTo(b.result.maintainabilityIndex));
    return sorted.take(n).toList();
  }

  /// Returns the top N functions with highest cyclomatic complexity.
  List<FunctionMetrics> getMostComplexFunctions(int n) {
    final sorted = _functionMetrics.values.toList()
      ..sort((a, b) => b.result.cyclomaticComplexity
          .compareTo(a.result.cyclomaticComplexity));
    return sorted.take(n).toList();
  }

  /// Returns files sorted by average maintainability (worst first).
  List<FileMetricsSummary> getFilesSortedByMaintainability() {
    return _fileResults.entries.map((entry) {
      return FileMetricsSummary(
        path: entry.key,
        result: entry.value,
        functionCount: entry.value.functions.length,
      );
    }).toList()
      ..sort((a, b) => a.result.averageMaintainabilityIndex
          .compareTo(b.result.averageMaintainabilityIndex));
  }

  /// Returns distribution of maintainability ratings.
  RatingDistribution getRatingDistribution() {
    var good = 0;
    var moderate = 0;
    var poor = 0;

    for (final func in _functionMetrics.values) {
      switch (func.result.rating) {
        case MaintainabilityRating.good:
          good++;
        case MaintainabilityRating.moderate:
          moderate++;
        case MaintainabilityRating.poor:
          poor++;
      }
    }

    return RatingDistribution(
      good: good,
      moderate: moderate,
      poor: poor,
      total: functionCount,
    );
  }

  /// Generates a comprehensive report.
  AggregatedReport generateReport() {
    return AggregatedReport(
      projectMetrics: getProjectMetrics(),
      ratingDistribution: getRatingDistribution(),
      violations: getViolations(),
      worstFunctions: getWorstFunctions(10),
      filesSummary: getFilesSortedByMaintainability(),
      thresholds: thresholds,
    );
  }

  /// ADR-016 2.1: Sort in place since we own the list.
  MetricStats _calculateStats(List<num> values) {
    if (values.isEmpty) {
      return MetricStats.empty();
    }

    // Sort in place - we own this list
    values.sort();
    final sum = values.fold<num>(0, (a, b) => a + b);
    final mean = sum / values.length;

    // Calculate standard deviation
    final squaredDiffs =
        values.map((v) => math.pow(v - mean, 2)).fold<num>(0, (a, b) => a + b);
    final stdDev = math.sqrt(squaredDiffs / values.length);

    return MetricStats(
      min: values.first.toDouble(),
      max: values.last.toDouble(),
      mean: mean.toDouble(),
      median: _calculateMedian(values),
      stdDev: stdDev,
      p90: _calculatePercentile(values, 90),
      p95: _calculatePercentile(values, 95),
    );
  }

  double _calculateMedian(List<num> sorted) {
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid].toDouble();
    }
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  double _calculatePercentile(List<num> sorted, int percentile) {
    if (sorted.isEmpty) return 0;
    final index = ((percentile / 100) * (sorted.length - 1)).round();
    return sorted[index].toDouble();
  }
}

/// Metrics thresholds for violation detection.
class MetricsThresholds {
  /// Minimum acceptable maintainability index.
  final double minMaintainability;

  /// Maximum acceptable cyclomatic complexity.
  final int maxCyclomatic;

  /// Maximum acceptable cognitive complexity.
  final int maxCognitive;

  /// Maximum acceptable lines of code per function.
  final int maxLinesOfCode;

  const MetricsThresholds({
    this.minMaintainability = 50.0,
    this.maxCyclomatic = 20,
    this.maxCognitive = 15,
    this.maxLinesOfCode = 100,
  });

  @override
  String toString() => '''
MetricsThresholds(
  minMaintainability: $minMaintainability
  maxCyclomatic: $maxCyclomatic
  maxCognitive: $maxCognitive
  maxLinesOfCode: $maxLinesOfCode
)''';
}

/// Metrics for a single function with file context.
class FunctionMetrics {
  final String filePath;
  final String functionName;
  final MaintainabilityResult result;

  const FunctionMetrics({
    required this.filePath,
    required this.functionName,
    required this.result,
  });

  String get qualifiedName => '$filePath::$functionName';

  @override
  String toString() =>
      'FunctionMetrics($functionName: MI=${result.maintainabilityIndex.toStringAsFixed(1)})';
}

/// Summary of metrics for a file.
class FileMetricsSummary {
  final String path;
  final FileMaintainabilityResult result;
  final int functionCount;

  const FileMetricsSummary({
    required this.path,
    required this.result,
    required this.functionCount,
  });

  @override
  String toString() =>
      'FileMetricsSummary($path: MI=${result.averageMaintainabilityIndex.toStringAsFixed(1)}, functions=$functionCount)';
}

/// Statistical summary for a metric.
class MetricStats {
  final double min;
  final double max;
  final double mean;
  final double median;
  final double stdDev;
  final double p90;
  final double p95;

  const MetricStats({
    required this.min,
    required this.max,
    required this.mean,
    required this.median,
    required this.stdDev,
    required this.p90,
    required this.p95,
  });

  factory MetricStats.empty() => const MetricStats(
        min: 0,
        max: 0,
        mean: 0,
        median: 0,
        stdDev: 0,
        p90: 0,
        p95: 0,
      );

  @override
  String toString() =>
      'MetricStats(min=${min.toStringAsFixed(1)}, max=${max.toStringAsFixed(1)}, mean=${mean.toStringAsFixed(1)}, median=${median.toStringAsFixed(1)})';
}

/// Project-wide metrics summary.
class ProjectMetrics {
  final int fileCount;
  final int functionCount;
  final int totalLinesOfCode;
  final MetricStats maintainabilityIndex;
  final MetricStats cyclomaticComplexity;
  final MetricStats cognitiveComplexity;
  final MetricStats linesOfCode;
  final double totalHalsteadVolume;

  const ProjectMetrics({
    required this.fileCount,
    required this.functionCount,
    required this.totalLinesOfCode,
    required this.maintainabilityIndex,
    required this.cyclomaticComplexity,
    required this.cognitiveComplexity,
    required this.linesOfCode,
    required this.totalHalsteadVolume,
  });

  factory ProjectMetrics.empty() => ProjectMetrics(
        fileCount: 0,
        functionCount: 0,
        totalLinesOfCode: 0,
        maintainabilityIndex: MetricStats.empty(),
        cyclomaticComplexity: MetricStats.empty(),
        cognitiveComplexity: MetricStats.empty(),
        linesOfCode: MetricStats.empty(),
        totalHalsteadVolume: 0,
      );

  @override
  String toString() => '''
ProjectMetrics(
  Files: $fileCount
  Functions: $functionCount
  Total LOC: $totalLinesOfCode
  MI: ${maintainabilityIndex.mean.toStringAsFixed(1)} (avg)
  Cyclomatic: ${cyclomaticComplexity.mean.toStringAsFixed(1)} (avg)
  Cognitive: ${cognitiveComplexity.mean.toStringAsFixed(1)} (avg)
)''';
}

/// Distribution of maintainability ratings.
class RatingDistribution {
  final int good;
  final int moderate;
  final int poor;
  final int total;

  const RatingDistribution({
    required this.good,
    required this.moderate,
    required this.poor,
    required this.total,
  });

  double get goodPercent => total > 0 ? (good / total) * 100 : 0;
  double get moderatePercent => total > 0 ? (moderate / total) * 100 : 0;
  double get poorPercent => total > 0 ? (poor / total) * 100 : 0;

  @override
  String toString() => '''
RatingDistribution(
  Good: $good (${goodPercent.toStringAsFixed(1)}%)
  Moderate: $moderate (${moderatePercent.toStringAsFixed(1)}%)
  Poor: $poor (${poorPercent.toStringAsFixed(1)}%)
)''';
}

/// Comprehensive aggregated report.
class AggregatedReport {
  final ProjectMetrics projectMetrics;
  final RatingDistribution ratingDistribution;
  final List<FunctionMetrics> violations;
  final List<FunctionMetrics> worstFunctions;
  final List<FileMetricsSummary> filesSummary;
  final MetricsThresholds thresholds;

  const AggregatedReport({
    required this.projectMetrics,
    required this.ratingDistribution,
    required this.violations,
    required this.worstFunctions,
    required this.filesSummary,
    required this.thresholds,
  });

  /// Whether the project has any threshold violations.
  bool get hasViolations => violations.isNotEmpty;

  /// Overall project health score (0-100).
  double get healthScore {
    if (projectMetrics.functionCount == 0) return 100;

    // Weight: 40% rating distribution, 30% average MI, 30% violation ratio
    final ratingScore = ratingDistribution.goodPercent * 0.4 +
        ratingDistribution.moderatePercent * 0.2;
    final miScore = (projectMetrics.maintainabilityIndex.mean / 100) * 30;
    final violationRatio =
        1 - (violations.length / projectMetrics.functionCount);
    final violationScore = violationRatio * 30;

    return (ratingScore + miScore + violationScore).clamp(0, 100);
  }

  @override
  String toString() => '''
=== Project Metrics Report ===

$projectMetrics

$ratingDistribution

Health Score: ${healthScore.toStringAsFixed(1)}/100

Violations: ${violations.length}
${violations.take(5).map((v) => '  - ${v.functionName}: MI=${v.result.maintainabilityIndex.toStringAsFixed(1)}').join('\n')}
${violations.length > 5 ? '  ... and ${violations.length - 5} more' : ''}

Thresholds: $thresholds
''';
}
