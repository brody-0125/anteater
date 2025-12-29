import 'cost_calculator.dart';
import 'debt_item.dart';

/// Report containing technical debt analysis results.
class DebtReport {
  const DebtReport({
    required this.summary,
    required this.items,
    required this.byFile,
  });

  /// Overall summary of debt costs.
  final DebtSummary summary;

  /// All detected debt items.
  final List<DebtItem> items;

  /// Summary breakdown by file.
  final Map<String, FileDebtSummary> byFile;

  /// Get hotspots (files with highest debt cost).
  List<FileDebtSummary> getHotspots(int n) {
    final files = byFile.values.toList();
    files.sort((a, b) => b.totalCost.compareTo(a.totalCost));
    return files.take(n).toList();
  }

  /// Get items filtered by type.
  List<DebtItem> getItemsByType(DebtType type) =>
      items.where((item) => item.type == type).toList();

  /// Get items filtered by severity.
  List<DebtItem> getItemsBySeverity(DebtSeverity severity) =>
      items.where((item) => item.severity == severity).toList();

  /// Generate markdown report.
  String toMarkdown() {
    final buffer = StringBuffer();

    buffer.writeln('# Technical Debt Report');
    buffer.writeln();

    // Summary section
    buffer.writeln('## Summary');
    buffer.writeln();
    buffer.writeln(
        '- **Total Cost**: ${summary.totalCost.toStringAsFixed(1)} ${summary.unit}');
    buffer.writeln('- **Items**: ${summary.itemCount}');
    buffer.writeln(
        '- **Threshold**: ${summary.threshold.toStringAsFixed(1)} ${summary.unit}');
    buffer.writeln(
        '- **Status**: ${summary.exceedsThreshold ? "EXCEEDS THRESHOLD" : "OK"}');
    buffer.writeln();

    // Breakdown by type
    buffer.writeln('## Breakdown by Type');
    buffer.writeln();
    buffer.writeln('| Type | Count | Cost |');
    buffer.writeln('|------|-------|------|');

    for (final typeSummary in summary.typesByHighestCost) {
      if (typeSummary.count > 0) {
        buffer.writeln(
            '| ${typeSummary.type.label} | ${typeSummary.count} | '
            '${typeSummary.cost.toStringAsFixed(1)} ${summary.unit} |');
      }
    }
    buffer.writeln();

    // Breakdown by severity
    buffer.writeln('## Breakdown by Severity');
    buffer.writeln();
    buffer.writeln('| Severity | Cost |');
    buffer.writeln('|----------|------|');

    for (final severity in DebtSeverity.values) {
      final cost = summary.getCostForSeverity(severity);
      if (cost > 0) {
        buffer.writeln(
            '| ${severity.label} | ${cost.toStringAsFixed(1)} ${summary.unit} |');
      }
    }
    buffer.writeln();

    // Hotspots
    final hotspots = getHotspots(10);
    if (hotspots.isNotEmpty) {
      buffer.writeln('## Hotspots (Top 10 Files)');
      buffer.writeln();
      buffer.writeln('| File | Items | Cost |');
      buffer.writeln('|------|-------|------|');

      for (final file in hotspots) {
        buffer.writeln(
            '| ${file.filePath} | ${file.itemCount} | '
            '${file.totalCost.toStringAsFixed(1)} ${summary.unit} |');
      }
      buffer.writeln();
    }

    // Critical items
    final criticalItems = getItemsBySeverity(DebtSeverity.critical);
    if (criticalItems.isNotEmpty) {
      buffer.writeln('## Critical Items');
      buffer.writeln();

      for (final item in criticalItems) {
        buffer.writeln(
            '- **${item.type.label}** at `${item.filePath}:${item.location.start.line}`');
        buffer.writeln('  - ${item.description}');
        if (item.context != null) {
          buffer.writeln('  - Context: `${item.context}`');
        }
      }
      buffer.writeln();
    }

    // High priority items
    final highItems = getItemsBySeverity(DebtSeverity.high);
    if (highItems.isNotEmpty) {
      buffer.writeln('## High Priority Items');
      buffer.writeln();

      for (final item in highItems.take(20)) {
        buffer.writeln(
            '- **${item.type.label}** at `${item.filePath}:${item.location.start.line}`');
        buffer.writeln('  - ${item.description}');
      }

      if (highItems.length > 20) {
        buffer.writeln();
        buffer.writeln('_...and ${highItems.length - 20} more high priority items_');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Generate console-friendly output.
  String toConsole() {
    final buffer = StringBuffer();

    // Status line
    if (summary.exceedsThreshold) {
      buffer.writeln('DEBT THRESHOLD EXCEEDED');
    }

    buffer.writeln(
        'Total: ${summary.totalCost.toStringAsFixed(1)} ${summary.unit} '
        '(threshold: ${summary.threshold.toStringAsFixed(1)} ${summary.unit})');
    buffer.writeln('Items: ${summary.itemCount}');
    buffer.writeln();

    // Top types
    buffer.writeln('By Type:');
    for (final typeSummary in summary.typesByHighestCost.take(5)) {
      if (typeSummary.count > 0) {
        buffer.writeln(
            '  ${typeSummary.type.label}: ${typeSummary.count} items '
            '(${typeSummary.cost.toStringAsFixed(1)} ${summary.unit})');
      }
    }
    buffer.writeln();

    // Hotspots
    final hotspots = getHotspots(5);
    if (hotspots.isNotEmpty) {
      buffer.writeln('Hotspots:');
      for (final file in hotspots) {
        buffer.writeln(
            '  ${file.filePath}: ${file.itemCount} items '
            '(${file.totalCost.toStringAsFixed(1)} ${summary.unit})');
      }
    }

    return buffer.toString();
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() => {
        'summary': summary.toJson(),
        'items': items.map((item) => item.toJson()).toList(),
        'byFile': byFile.map(
          (path, summary) => MapEntry(path, summary.toJson()),
        ),
      };
}

/// Summary of debt for a single file.
class FileDebtSummary {
  const FileDebtSummary({
    required this.filePath,
    required this.itemCount,
    required this.totalCost,
    required this.countByType,
  });

  /// Path to the file.
  final String filePath;

  /// Number of debt items in this file.
  final int itemCount;

  /// Total cost for this file.
  final double totalCost;

  /// Breakdown by type for this file.
  final Map<DebtType, int> countByType;

  /// Convert to JSON map.
  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'itemCount': itemCount,
        'totalCost': totalCost,
        'countByType':
            countByType.map((type, count) => MapEntry(type.name, count)),
      };

  @override
  String toString() => 'FileDebtSummary($filePath: $itemCount items, $totalCost)';
}
