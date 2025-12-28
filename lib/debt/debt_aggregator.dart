import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

import '../metrics/maintainability_index.dart';
import 'cost_calculator.dart';
import 'debt_config.dart';
import 'debt_detector.dart';
import 'debt_item.dart';
import 'debt_report.dart';

/// Aggregates technical debt across multiple files.
class DebtAggregator {
  final DebtDetector _detector;
  final DebtCostCalculator _calculator;
  final Map<String, List<DebtItem>> _fileDebt = {};

  DebtAggregator({DebtCostConfig? config})
      : _detector = DebtDetector(config: config),
        _calculator = DebtCostCalculator(config: config);

  /// Add a file to the aggregation.
  void addFile(
    String path,
    CompilationUnit unit, {
    LineInfo? lineInfo,
    FileMaintainabilityResult? metrics,
    String? sourceCode,
  }) {
    final items = _detector.detect(
      unit,
      path,
      lineInfo: lineInfo,
      metrics: metrics,
      sourceCode: sourceCode,
    );
    _fileDebt[path] = items;
  }

  /// Add pre-detected debt items for a file.
  void addItems(String path, List<DebtItem> items) {
    _fileDebt[path] = items;
  }

  /// Get all debt items for a specific file.
  List<DebtItem> getItemsForFile(String path) => _fileDebt[path] ?? [];

  /// Get all files that have been analyzed.
  Set<String> get analyzedFiles => _fileDebt.keys.toSet();

  /// Get total number of debt items across all files.
  int get totalItemCount =>
      _fileDebt.values.fold(0, (sum, items) => sum + items.length);

  /// Generate project-wide debt report.
  DebtReport generateReport() {
    final allItems = _fileDebt.values.expand((items) => items).toList();
    final summary = _calculator.calculateTotal(allItems);

    final byFile = <String, FileDebtSummary>{};

    for (final entry in _fileDebt.entries) {
      final path = entry.key;
      final items = entry.value;

      if (items.isEmpty) continue;

      var totalCost = 0.0;
      final countByType = <DebtType, int>{};

      for (final item in items) {
        totalCost += _calculator.calculateItemCost(item);
        countByType[item.type] = (countByType[item.type] ?? 0) + 1;
      }

      byFile[path] = FileDebtSummary(
        filePath: path,
        itemCount: items.length,
        totalCost: totalCost,
        countByType: countByType,
      );
    }

    return DebtReport(
      summary: summary,
      items: allItems,
      byFile: byFile,
    );
  }

  /// Get hotspot files (highest debt cost).
  List<MapEntry<String, double>> getHotspots(int n) {
    final costs = <String, double>{};

    for (final entry in _fileDebt.entries) {
      var totalCost = 0.0;
      for (final item in entry.value) {
        totalCost += _calculator.calculateItemCost(item);
      }
      costs[entry.key] = totalCost;
    }

    final sorted = costs.entries.toList();
    sorted.sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).toList();
  }

  /// Get debt trend compared to a previous report.
  DebtTrend? getTrend(DebtReport previousReport) {
    final currentReport = generateReport();

    return DebtTrend(
      previousTotal: previousReport.summary.totalCost,
      currentTotal: currentReport.summary.totalCost,
      previousItemCount: previousReport.summary.itemCount,
      currentItemCount: currentReport.summary.itemCount,
      unit: currentReport.summary.unit,
    );
  }

  /// Clear all aggregated data.
  void clear() {
    _fileDebt.clear();
  }
}

/// Represents the trend in technical debt over time.
class DebtTrend {
  /// Previous total cost.
  final double previousTotal;

  /// Current total cost.
  final double currentTotal;

  /// Previous item count.
  final int previousItemCount;

  /// Current item count.
  final int currentItemCount;

  /// Unit of measurement.
  final String unit;

  const DebtTrend({
    required this.previousTotal,
    required this.currentTotal,
    required this.previousItemCount,
    required this.currentItemCount,
    required this.unit,
  });

  /// Change in total cost.
  double get costChange => currentTotal - previousTotal;

  /// Percentage change in cost.
  double get costChangePercent =>
      previousTotal > 0 ? (costChange / previousTotal) * 100 : 0;

  /// Change in item count.
  int get itemCountChange => currentItemCount - previousItemCount;

  /// Whether debt is increasing.
  bool get isIncreasing => costChange > 0;

  /// Whether debt is decreasing.
  bool get isDecreasing => costChange < 0;

  /// Get trend direction as string.
  String get direction {
    if (costChange > 0) return 'increasing';
    if (costChange < 0) return 'decreasing';
    return 'stable';
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() => {
        'previousTotal': previousTotal,
        'currentTotal': currentTotal,
        'costChange': costChange,
        'costChangePercent': costChangePercent,
        'previousItemCount': previousItemCount,
        'currentItemCount': currentItemCount,
        'itemCountChange': itemCountChange,
        'direction': direction,
        'unit': unit,
      };

  @override
  String toString() {
    final sign = costChange >= 0 ? '+' : '';
    return 'DebtTrend($direction: $sign${costChange.toStringAsFixed(1)} $unit, '
        '${costChangePercent.toStringAsFixed(1)}%)';
  }
}
