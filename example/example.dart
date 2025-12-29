// ignore_for_file: avoid_print

/// Example usage of the Anteater static analyzer.
///
/// Run with: dart run example/example.dart
library;

import 'package:anteater/anteater.dart';

Future<void> main() async {
  // Example 1: Analyze code metrics for a directory
  print('=== Analyzing Code Metrics ===\n');

  try {
    final report = await Anteater.analyzeMetrics('lib');
    final metrics = report.projectMetrics;
    print('Files analyzed: ${metrics.fileCount}');
    print('Total functions: ${metrics.functionCount}');
    print('Average cyclomatic complexity: '
        '${metrics.cyclomaticComplexity.mean.toStringAsFixed(2)}');
    print('Average maintainability index: '
        '${metrics.maintainabilityIndex.mean.toStringAsFixed(2)}');
    print('');
  } on ArgumentError catch (e) {
    print('Path not found: $e');
    print('Run this example from the project root directory.\n');
  }

  // Example 2: Analyze a single file for diagnostics
  print('=== Single File Analysis ===\n');

  const sampleCode = '''
void complexFunction(int x) {
  if (x > 0) {
    if (x > 10) {
      if (x > 100) {
        print('Very large');
      } else {
        print('Large');
      }
    } else {
      print('Medium');
    }
  } else {
    print('Small or negative');
  }
}
''';

  print('Sample code with nested conditionals:');
  print(sampleCode);

  // Example 3: Using thresholds
  print('=== Custom Thresholds ===\n');
  print('You can configure analysis thresholds in analysis_options.yaml:');
  print('''
anteater:
  metrics:
    cyclomatic_complexity: 10
    cognitive_complexity: 8
    maintainability_index: 60
    lines_of_code: 50
''');

  print('\nFor more information, run: dart run bin/anteater.dart --help');
}
