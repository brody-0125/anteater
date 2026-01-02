// ignore_for_file: unused_local_variable

/// Example: Technical Debt API Usage
///
/// This file demonstrates programmatic usage of anteater's debt analysis API.
///
/// ## API Components
///
/// | Class | Purpose |
/// |-------|---------|
/// | `DebtDetector` | Detect debt items in source code |
/// | `DebtCostCalculator` | Calculate costs for debt items |
/// | `DebtAggregator` | Aggregate debt across files |
/// | `DebtCostConfig` | Configure costs and thresholds |
///
/// ## Usage Patterns
///
/// 1. **Single File Analysis**: Use `DebtDetector.detect()`
/// 2. **Cost Calculation**: Use `DebtCostCalculator.calculateTotal()`
/// 3. **Project Analysis**: Use `DebtAggregator` to collect and report
///
/// Run with:
/// ```bash
/// dart run example/debt/debt_api_example.dart
/// ```
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:anteater/debt/cost_calculator.dart';
import 'package:anteater/debt/debt_aggregator.dart';
import 'package:anteater/debt/debt_config.dart';
import 'package:anteater/debt/debt_detector.dart';
import 'package:anteater/debt/debt_item.dart';

void main() async {
  print('=== Anteater Debt API Demo ===\n');

  await demonstrateDebtDetector();
  await demonstrateDebtCostCalculator();
  await demonstrateDebtAggregator();
  await demonstrateCustomConfig();
  await demonstrateDebtTypes();

  print('\n=== Demo Complete ===');
}

// ============================================================================
// 1. DebtDetector Usage
// ============================================================================

Future<void> demonstrateDebtDetector() async {
  print('1. DebtDetector\n');
  print('   Detects technical debt items in source code.\n');

  final detector = DebtDetector();

  // Code with various debt types
  const code = '''
// TODO: Implement caching
// FIXME: Memory leak here
// ignore: avoid_print
print('debug');

void process(Object data) {
  var result = data as dynamic;  // as dynamic cast
}

@deprecated
void oldFunction() {}
''';

  final result = parseString(content: code);
  final items = detector.detect(
    result.unit,
    'example.dart',
    sourceCode: code, // Important: pass source for comment detection
  );

  print('   Detected ${items.length} debt items:');
  for (final item in items) {
    print('   - ${item.type.label}: ${item.description}');
  }
  print('');
}

// ============================================================================
// 2. DebtCostCalculator Usage
// ============================================================================

Future<void> demonstrateDebtCostCalculator() async {
  print('2. DebtCostCalculator\n');
  print('   Calculates costs and generates summaries.\n');

  final calculator = DebtCostCalculator();
  final detector = DebtDetector();

  const code = '''
// TODO: Add error handling
// FIXME: Race condition bug
void process(Object x) {
  var y = x as dynamic;
}
''';

  final result = parseString(content: code);
  final items = detector.detect(result.unit, 'test.dart', sourceCode: code);

  // Calculate individual costs
  print('   Individual Costs:');
  for (final item in items) {
    final cost = calculator.calculateItemCost(item);
    print('   - ${item.type.label}: ${cost.toStringAsFixed(1)} hours');
  }

  // Calculate total summary
  final summary = calculator.calculateTotal(items);
  print('\n   Summary:');
  print('   - Total Cost: ${summary.totalCost.toStringAsFixed(1)} ${summary.unit}');
  print('   - Item Count: ${summary.itemCount}');
  print('   - Exceeds Threshold: ${summary.exceedsThreshold}');

  // Cost by type
  print('\n   By Type:');
  for (final typeSummary in summary.typesByHighestCost) {
    print('   - ${typeSummary.type.label}: ${typeSummary.count} items, '
        '${typeSummary.cost.toStringAsFixed(1)} hours');
  }
  print('');
}

// ============================================================================
// 3. DebtAggregator Usage
// ============================================================================

Future<void> demonstrateDebtAggregator() async {
  print('3. DebtAggregator\n');
  print('   Aggregates debt across multiple files.\n');

  final aggregator = DebtAggregator();

  // Simulate multiple files
  final files = {
    'service.dart': '''
// TODO: Add retry logic
// FIXME: Handle timeout
void fetchData() {}
''',
    'utils.dart': '''
// TODO: Optimize performance
void process(Object x) {
  var y = x as dynamic;
}
''',
    'legacy.dart': '''
@deprecated
void oldApi() {}

@Deprecated('Use newApi instead')
void legacyApi() {}
''',
  };

  for (final entry in files.entries) {
    final result = parseString(content: entry.value);
    aggregator.addFile(
      entry.key,
      result.unit,
      sourceCode: entry.value,
    );
  }

  print('   Files analyzed: ${aggregator.analyzedFiles.length}');
  print('   Total items: ${aggregator.totalItemCount}\n');

  // Generate report
  final report = aggregator.generateReport();
  print('   Report Summary:');
  print('   - Total Cost: ${report.summary.totalCost.toStringAsFixed(1)} hours');
  print('   - Threshold: ${report.summary.threshold} hours');
  print('   - Status: ${report.summary.exceedsThreshold ? "EXCEEDS" : "OK"}\n');

  // Get hotspots
  final hotspots = aggregator.getHotspots(3);
  print('   Hotspots (highest debt):');
  for (final hotspot in hotspots) {
    print('   - ${hotspot.key}: ${hotspot.value.toStringAsFixed(1)} hours');
  }
  print('');
}

// ============================================================================
// 4. Custom Configuration
// ============================================================================

Future<void> demonstrateCustomConfig() async {
  print('4. Custom Configuration\n');
  print('   Configure costs, multipliers, and thresholds.\n');

  // Default configuration
  final defaults = DebtCostConfig.defaults();
  print('   Default Costs:');
  print('   - TODO: ${defaults.getCost(DebtType.todo)} hours');
  print('   - FIXME: ${defaults.getCost(DebtType.fixme)} hours');
  print('   - as dynamic: ${defaults.getCost(DebtType.asDynamic)} hours');

  print('\n   Default Multipliers:');
  print('   - Critical: ${defaults.getMultiplier(DebtSeverity.critical)}x');
  print('   - High: ${defaults.getMultiplier(DebtSeverity.high)}x');
  print('   - Medium: ${defaults.getMultiplier(DebtSeverity.medium)}x');
  print('   - Low: ${defaults.getMultiplier(DebtSeverity.low)}x');

  // Custom configuration via YAML
  final customConfig = DebtCostConfig.fromYaml({
    'costs': {
      'todo': 2.0, // Reduce TODO cost
      'fixme': 16.0, // Increase FIXME cost
      'as-dynamic': 24.0, // Higher penalty for dynamic
    },
    'multipliers': {
      'critical': 5.0, // Stricter critical multiplier
    },
    'threshold': 20.0, // Lower threshold for alerts
    'unit': 'hours',
    'metrics': {
      'maintainability-index': 60.0, // Stricter MI threshold
      'cyclomatic-complexity': 15, // Stricter CC threshold
      'lines-of-code': 80, // Shorter method limit
    },
  });

  print('\n   Custom Configuration:');
  print('   - TODO: ${customConfig.getCost(DebtType.todo)} hours');
  print('   - FIXME: ${customConfig.getCost(DebtType.fixme)} hours');
  print('   - Threshold: ${customConfig.threshold} hours');
  print('   - MI Threshold: ${customConfig.metricsThresholds.maintainabilityIndex}');

  // Use custom config with detector
  final customDetector = DebtDetector(config: customConfig);
  final customCalculator = DebtCostCalculator(config: customConfig);

  print('\n   Usage: DebtDetector(config: customConfig)');
  print('');
}

// ============================================================================
// 5. Debt Types Reference
// ============================================================================

Future<void> demonstrateDebtTypes() async {
  print('5. Debt Types Reference\n');

  print('   | Type | Label | Default Severity |');
  print('   |------|-------|------------------|');

  for (final type in DebtType.values) {
    final label = type.label.padRight(20);
    final severity = type.defaultSeverity.label.padRight(10);
    print('   | ${type.name.padRight(20)} | $label | $severity |');
  }

  print('\n   Severity Multipliers:');
  for (final severity in DebtSeverity.values) {
    print('   - ${severity.label}: ${severity.multiplier}x');
  }
  print('');
}

// ============================================================================
// Example: Real File Analysis
// ============================================================================

/// Analyze a real Dart file for technical debt.
Future<void> analyzeRealFile(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    print('File not found: $path');
    return;
  }

  final content = await file.readAsString();
  final result = parseString(content: content);

  final detector = DebtDetector();
  final calculator = DebtCostCalculator();

  final items = detector.detect(
    result.unit,
    path,
    sourceCode: content,
  );

  print('File: $path');
  print('Debt items: ${items.length}');

  if (items.isNotEmpty) {
    final summary = calculator.calculateTotal(items);
    print('Total cost: ${summary.totalCost.toStringAsFixed(1)} hours');

    print('\nItems:');
    for (final item in items) {
      final cost = calculator.calculateItemCost(item);
      print('  - [${item.type.label}] ${item.description}');
      print('    Cost: ${cost.toStringAsFixed(1)} hours');
    }
  }
}

// ============================================================================
// Example: CI/CD Integration
// ============================================================================

/// Check if debt is within acceptable limits for CI/CD.
Future<bool> checkDebtThreshold(
  DebtAggregator aggregator, {
  double maxTotalCost = 40.0,
  int maxCriticalItems = 0,
}) async {
  final report = aggregator.generateReport();

  // Check total cost
  if (report.summary.totalCost > maxTotalCost) {
    print('❌ Total debt ${report.summary.totalCost.toStringAsFixed(1)} '
        'exceeds threshold of $maxTotalCost hours');
    return false;
  }

  // Check critical items
  final criticalCount = report.items
      .where((item) => item.severity == DebtSeverity.critical)
      .length;

  if (criticalCount > maxCriticalItems) {
    print('❌ Found $criticalCount critical debt items '
        '(max allowed: $maxCriticalItems)');
    return false;
  }

  print('✅ Debt check passed');
  print('   Total cost: ${report.summary.totalCost.toStringAsFixed(1)} hours');
  print('   Critical items: $criticalCount');
  return true;
}

// ============================================================================
// Example: Trend Analysis
// ============================================================================

/// Compare current debt to a previous snapshot.
void analyzeTrend(DebtAggregator current, DebtAggregator previous) {
  final currentReport = current.generateReport();
  final previousReport = previous.generateReport();

  final trend = current.getTrend(previousReport);

  if (trend != null) {
    print('Debt Trend: ${trend.direction}');
    print('  Cost change: ${trend.costChange >= 0 ? "+" : ""}${trend.costChange.toStringAsFixed(1)} hours');
    print('  Percentage: ${trend.costChangePercent.toStringAsFixed(1)}%');
    print('  Items: ${trend.previousItemCount} → ${trend.currentItemCount}');

    if (trend.isIncreasing) {
      print('  ⚠️ Warning: Technical debt is increasing!');
    } else if (trend.isDecreasing) {
      print('  ✅ Good: Technical debt is decreasing.');
    }
  }
}
