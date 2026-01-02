// ignore_for_file: unused_local_variable

/// Example: Metrics API Usage
///
/// This file demonstrates programmatic usage of anteater's metrics API.
///
/// ## API Components
///
/// | Class | Purpose |
/// |-------|---------|
/// | `ComplexityCalculator` | Calculate CC, Cognitive, Halstead |
/// | `MaintainabilityIndexCalculator` | Calculate MI with all sub-metrics |
/// | `MetricsAggregator` | Aggregate metrics across files |
/// | `MetricsThresholds` | Define violation thresholds |
///
/// ## Usage Patterns
///
/// 1. **Single Function Analysis**: Use `ComplexityCalculator` directly
/// 2. **File Analysis**: Use `MaintainabilityIndexCalculator.calculateForFile`
/// 3. **Project Analysis**: Use `MetricsAggregator` to collect and analyze
///
/// Run with:
/// ```bash
/// dart run example/metrics/metrics_api_example.dart
/// ```
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:anteater/metrics/complexity_calculator.dart';
import 'package:anteater/metrics/maintainability_index.dart';
import 'package:anteater/metrics/metrics_aggregator.dart';

void main() async {
  print('=== Anteater Metrics API Demo ===\n');

  await demonstrateComplexityCalculator();
  await demonstrateMaintainabilityCalculator();
  await demonstrateMetricsAggregator();
  await demonstrateThresholds();
  await demonstrateReporting();

  print('\n=== Demo Complete ===');
}

// ============================================================================
// 1. ComplexityCalculator Usage
// ============================================================================

Future<void> demonstrateComplexityCalculator() async {
  print('1. ComplexityCalculator\n');
  print('   Calculates individual complexity metrics.\n');

  final calculator = ComplexityCalculator();

  // Parse a simple function
  const code = '''
int factorial(int n) {
  if (n <= 1) return 1;
  var result = 1;
  for (var i = 2; i <= n; i++) {
    result *= i;
  }
  return result;
}
''';

  final result = parseString(content: code);
  final unit = result.unit;

  // Get the function body
  for (final declaration in unit.declarations) {
    if (declaration is! dynamic) continue;

    print('   Function: factorial');

    // Calculate metrics
    final cc = calculator.calculateCyclomaticComplexity(declaration);
    final cognitive = calculator.calculateCognitiveComplexity(declaration);
    final halstead = calculator.calculateHalsteadMetrics(declaration);

    print('   Cyclomatic Complexity: $cc');
    print('   Cognitive Complexity: $cognitive');
    print('   Halstead Volume: ${halstead.volume.toStringAsFixed(2)}');
    print('   Halstead Difficulty: ${halstead.difficulty.toStringAsFixed(2)}');
    print('   Estimated Bugs: ${halstead.bugs.toStringAsFixed(4)}\n');
  }
}

// ============================================================================
// 2. MaintainabilityIndexCalculator Usage
// ============================================================================

Future<void> demonstrateMaintainabilityCalculator() async {
  print('2. MaintainabilityIndexCalculator\n');
  print('   Calculates composite MI score for functions.\n');

  final calculator = MaintainabilityIndexCalculator();

  const code = '''
class StringUtils {
  String reverse(String input) {
    if (input.isEmpty) return input;
    return input.split('').reversed.join();
  }

  int countWords(String text) {
    if (text.isEmpty) return 0;
    return text.trim().split(RegExp(r'\\s+')).length;
  }
}
''';

  final result = parseString(content: code);
  final fileResult = calculator.calculateForFile(result.unit);

  print('   File Average MI: ${fileResult.averageMaintainabilityIndex.toStringAsFixed(2)}');
  print('   Rating: ${fileResult.rating.emoji} ${fileResult.rating.label}\n');

  print('   Function Details:');
  for (final entry in fileResult.functions.entries) {
    final name = entry.key;
    final metrics = entry.value;
    print('   - $name:');
    print('     MI: ${metrics.maintainabilityIndex.toStringAsFixed(2)} (${metrics.rating.label})');
    print('     CC: ${metrics.cyclomaticComplexity}, Cognitive: ${metrics.cognitiveComplexity}');
    print('     LOC: ${metrics.linesOfCode}');
  }
  print('');
}

// ============================================================================
// 3. MetricsAggregator Usage
// ============================================================================

Future<void> demonstrateMetricsAggregator() async {
  print('3. MetricsAggregator\n');
  print('   Aggregates metrics across multiple files.\n');

  final aggregator = MetricsAggregator();

  // Simulate adding multiple files
  const files = {
    'utils.dart': '''
int add(int a, int b) => a + b;
int multiply(int a, int b) => a * b;
''',
    'validator.dart': '''
bool isValid(String? input) {
  if (input == null) return false;
  if (input.isEmpty) return false;
  return input.length >= 3;
}
''',
  };

  for (final entry in files.entries) {
    final result = parseString(content: entry.value);
    aggregator.addFile(entry.key, result.unit);
  }

  print('   Files analyzed: ${aggregator.fileCount}');
  print('   Functions analyzed: ${aggregator.functionCount}\n');

  final projectMetrics = aggregator.getProjectMetrics();
  print('   Project Metrics:');
  print('   - Average MI: ${projectMetrics.maintainabilityIndex.mean.toStringAsFixed(2)}');
  print('   - Average CC: ${projectMetrics.cyclomaticComplexity.mean.toStringAsFixed(2)}');
  print('   - Total LOC: ${projectMetrics.totalLinesOfCode}');

  final distribution = aggregator.getRatingDistribution();
  print('\n   Rating Distribution:');
  print('   - Good: ${distribution.good} (${distribution.goodPercent.toStringAsFixed(1)}%)');
  print('   - Moderate: ${distribution.moderate} (${distribution.moderatePercent.toStringAsFixed(1)}%)');
  print('   - Poor: ${distribution.poor} (${distribution.poorPercent.toStringAsFixed(1)}%)\n');
}

// ============================================================================
// 4. Custom Thresholds
// ============================================================================

Future<void> demonstrateThresholds() async {
  print('4. Custom Thresholds\n');
  print('   Configure violation thresholds for your project.\n');

  // Default thresholds
  const defaultThresholds = MetricsThresholds();
  print('   Default Thresholds:');
  print('   - Min Maintainability: ${defaultThresholds.minMaintainability}');
  print('   - Max Cyclomatic: ${defaultThresholds.maxCyclomatic}');
  print('   - Max Cognitive: ${defaultThresholds.maxCognitive}');
  print('   - Max LOC: ${defaultThresholds.maxLinesOfCode}\n');

  // Stricter thresholds for high-quality codebase
  const strictThresholds = MetricsThresholds(
    minMaintainability: 70.0, // Higher minimum
    maxCyclomatic: 10, // Lower max complexity
    maxCognitive: 10, // Lower cognitive threshold
    maxLinesOfCode: 50, // Shorter functions
  );

  print('   Strict Thresholds (for high-quality code):');
  print('   - Min Maintainability: ${strictThresholds.minMaintainability}');
  print('   - Max Cyclomatic: ${strictThresholds.maxCyclomatic}');
  print('   - Max Cognitive: ${strictThresholds.maxCognitive}');
  print('   - Max LOC: ${strictThresholds.maxLinesOfCode}\n');

  // Use with aggregator
  final strictAggregator = MetricsAggregator(thresholds: strictThresholds);
  print('   Usage: MetricsAggregator(thresholds: strictThresholds)\n');
}

// ============================================================================
// 5. Report Generation
// ============================================================================

Future<void> demonstrateReporting() async {
  print('5. Report Generation\n');
  print('   Generate comprehensive reports.\n');

  final aggregator = MetricsAggregator(
    thresholds: const MetricsThresholds(
      minMaintainability: 60.0,
      maxCyclomatic: 15,
    ),
  );

  // Add some code with varying quality
  const goodCode = '''
int square(int n) => n * n;
int cube(int n) => n * n * n;
''';

  const moderateCode = '''
String format(String text, int maxLen, bool uppercase) {
  if (text.isEmpty) return text;
  var result = text;
  if (result.length > maxLen) {
    result = result.substring(0, maxLen);
  }
  if (uppercase) {
    result = result.toUpperCase();
  }
  return result;
}
''';

  aggregator.addFile('good.dart', parseString(content: goodCode).unit);
  aggregator.addFile('moderate.dart', parseString(content: moderateCode).unit);

  // Generate report
  final report = aggregator.generateReport();

  print('   Report Summary:');
  print('   - Health Score: ${report.healthScore.toStringAsFixed(1)}/100');
  print('   - Has Violations: ${report.hasViolations}');
  print('   - Violation Count: ${report.violations.length}\n');

  // Get worst functions
  final worst = aggregator.getWorstFunctions(3);
  if (worst.isNotEmpty) {
    print('   Worst Functions by MI:');
    for (final func in worst) {
      print('   - ${func.functionName}: MI=${func.result.maintainabilityIndex.toStringAsFixed(1)}');
    }
    print('');
  }

  // Get most complex
  final complex = aggregator.getMostComplexFunctions(3);
  if (complex.isNotEmpty) {
    print('   Most Complex Functions by CC:');
    for (final func in complex) {
      print('   - ${func.functionName}: CC=${func.result.cyclomaticComplexity}');
    }
    print('');
  }
}

// ============================================================================
// Example: Real File Analysis
// ============================================================================

/// Analyze a real Dart file
Future<void> analyzeRealFile(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    print('File not found: $path');
    return;
  }

  final content = await file.readAsString();
  final result = parseString(content: content);
  final calculator = MaintainabilityIndexCalculator();
  final fileResult = calculator.calculateForFile(result.unit);

  print('File: $path');
  print('Average MI: ${fileResult.averageMaintainabilityIndex.toStringAsFixed(2)}');
  print('Rating: ${fileResult.rating.emoji} ${fileResult.rating.label}');
  print('Functions: ${fileResult.functions.length}');

  // Show functions needing attention
  for (final entry in fileResult.needsAttention) {
    print('  ⚠️ ${entry.key}: MI=${entry.value.maintainabilityIndex.toStringAsFixed(1)}');
  }
}

// ============================================================================
// Example: CI/CD Integration
// ============================================================================

/// Check if code meets quality gates
Future<bool> checkQualityGate(
  MetricsAggregator aggregator, {
  double minHealthScore = 70.0,
  int maxViolations = 0,
}) async {
  final report = aggregator.generateReport();

  if (report.healthScore < minHealthScore) {
    print('❌ Health score ${report.healthScore.toStringAsFixed(1)} < $minHealthScore');
    return false;
  }

  if (report.violations.length > maxViolations) {
    print('❌ Violations ${report.violations.length} > $maxViolations');
    return false;
  }

  print('✅ Quality gate passed');
  return true;
}
