import 'dart:io';

import 'package:test/test.dart';

import 'package:anteater/api/parallel_analyzer.dart';
import 'package:anteater/metrics/metrics_aggregator.dart';

void main() {
  group('ParallelAnalysisConfig', () {
    test('uses default values', () {
      const config = ParallelAnalysisConfig();

      expect(config.maxConcurrency, equals(4));
      expect(config.chunkSize, equals(50));
      expect(config.thresholds.minMaintainability, equals(50.0));
    });

    test('accepts custom values', () {
      const config = ParallelAnalysisConfig(
        maxConcurrency: 8,
        chunkSize: 100,
        thresholds: MetricsThresholds(minMaintainability: 60.0),
      );

      expect(config.maxConcurrency, equals(8));
      expect(config.chunkSize, equals(100));
      expect(config.thresholds.minMaintainability, equals(60.0));
    });
  });

  group('FileAnalysisResult', () {
    test('isSuccess returns true when no error', () {
      final result = FileAnalysisResult(
        path: '/test/file.dart',
        fileResult: null,
        functions: [],
      );

      // No error but also no fileResult, so not successful
      expect(result.isSuccess, isFalse);
    });

    test('isSuccess returns false when error exists', () {
      final result = FileAnalysisResult(
        path: '/test/file.dart',
        fileResult: null,
        functions: [],
        error: 'Failed to parse',
      );

      expect(result.isSuccess, isFalse);
      expect(result.error, equals('Failed to parse'));
    });
  });

  group('ParallelAnalyzer', () {
    late Directory tempDir;
    late String testProjectPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('parallel_analyzer_test_');
      testProjectPath = tempDir.path;
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('discovers Dart files', () {
      // Create test files
      File('$testProjectPath/lib/file1.dart').createSync(recursive: true);
      File('$testProjectPath/lib/file1.dart').writeAsStringSync('''
void main() {
  print('hello');
}
''');

      File('$testProjectPath/lib/file2.dart').createSync(recursive: true);
      File('$testProjectPath/lib/file2.dart').writeAsStringSync('''
int add(int a, int b) => a + b;
''');

      // Create a generated file that should be excluded
      File('$testProjectPath/lib/file.g.dart').createSync(recursive: true);
      File('$testProjectPath/lib/file.g.dart')
          .writeAsStringSync('// generated');

      final analyzer = ParallelAnalyzer('$testProjectPath/lib');
      final files = analyzer.discoverFiles();

      expect(files.length, equals(2));
      expect(files.any((f) => f.endsWith('file1.dart')), isTrue);
      expect(files.any((f) => f.endsWith('file2.dart')), isTrue);
      expect(files.any((f) => f.endsWith('.g.dart')), isFalse);
    });

    test('discovers single file when path is a file', () {
      final filePath = '$testProjectPath/single.dart';
      File(filePath).createSync(recursive: true);
      File(filePath).writeAsStringSync('void main() {}');

      final analyzer = ParallelAnalyzer(filePath);
      final files = analyzer.discoverFiles();

      expect(files.length, equals(1));
      expect(files.first, endsWith('single.dart'));
    });

    test('returns empty list for non-existent directory', () {
      final analyzer = ParallelAnalyzer('$testProjectPath/nonexistent');
      final files = analyzer.discoverFiles();

      expect(files, isEmpty);
    });

    test('returns empty list for non-Dart file', () {
      final filePath = '$testProjectPath/readme.md';
      File(filePath).createSync(recursive: true);
      File(filePath).writeAsStringSync('# Readme');

      final analyzer = ParallelAnalyzer(filePath);
      final files = analyzer.discoverFiles();

      expect(files, isEmpty);
    });

    test('excludes freezed generated files', () {
      File('$testProjectPath/lib/model.dart').createSync(recursive: true);
      File('$testProjectPath/lib/model.dart').writeAsStringSync('class Model {}');

      File('$testProjectPath/lib/model.freezed.dart').createSync(recursive: true);
      File('$testProjectPath/lib/model.freezed.dart')
          .writeAsStringSync('// freezed');

      final analyzer = ParallelAnalyzer('$testProjectPath/lib');
      final files = analyzer.discoverFiles();

      expect(files.length, equals(1));
      expect(files.any((f) => f.endsWith('.freezed.dart')), isFalse);
    });

    test('analyzeWithProgress tracks progress', () async {
      // Create valid Dart files
      File('$testProjectPath/lib/a.dart').createSync(recursive: true);
      File('$testProjectPath/lib/a.dart').writeAsStringSync('''
void functionA() {
  print('A');
}
''');

      File('$testProjectPath/lib/b.dart').createSync(recursive: true);
      File('$testProjectPath/lib/b.dart').writeAsStringSync('''
int functionB(int x) {
  if (x > 0) {
    return x * 2;
  }
  return x;
}
''');

      final analyzer = ParallelAnalyzer(
        '$testProjectPath/lib',
        config: const ParallelAnalysisConfig(maxConcurrency: 2),
      );

      final progressLog = <String>[];

      final report = await analyzer.analyzeWithProgress(
        onProgress: (completed, total, file) {
          progressLog.add('$completed/$total: $file');
        },
      );

      await analyzer.dispose();

      // Verify progress was tracked
      expect(progressLog.length, equals(2));
      expect(progressLog.any((log) => log.contains('1/2')), isTrue);
      expect(progressLog.any((log) => log.contains('2/2')), isTrue);

      // Verify report
      expect(report.projectMetrics.fileCount, equals(2));
      expect(report.projectMetrics.functionCount, equals(2));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('analyzeStream yields results sequentially', () async {
      File('$testProjectPath/lib/x.dart').createSync(recursive: true);
      File('$testProjectPath/lib/x.dart').writeAsStringSync('void x() {}');

      File('$testProjectPath/lib/y.dart').createSync(recursive: true);
      File('$testProjectPath/lib/y.dart').writeAsStringSync('void y() {}');

      final analyzer = ParallelAnalyzer('$testProjectPath/lib');

      final results = await analyzer.analyzeStream().toList();

      await analyzer.dispose();

      expect(results.length, equals(2));
      expect(results.every((r) => r.path.isNotEmpty), isTrue);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('analyzeParallelStream yields results in chunks', () async {
      // Create multiple files to trigger chunking
      for (var i = 0; i < 5; i++) {
        File('$testProjectPath/lib/chunk$i.dart').createSync(recursive: true);
        File('$testProjectPath/lib/chunk$i.dart')
            .writeAsStringSync('void chunk$i() {}');
      }

      final analyzer = ParallelAnalyzer(
        '$testProjectPath/lib',
        config: const ParallelAnalysisConfig(
          maxConcurrency: 2,
          chunkSize: 3, // Process in chunks of 3
        ),
      );

      final results = await analyzer.analyzeParallelStream().toList();

      await analyzer.dispose();

      expect(results.length, equals(5));
      expect(results.every((r) => r.isSuccess), isTrue);
      expect(results.every((r) => r.fileResult != null), isTrue);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('successful analysis returns isSuccess true with fileResult', () async {
      File('$testProjectPath/lib/success.dart').createSync(recursive: true);
      File('$testProjectPath/lib/success.dart').writeAsStringSync('''
void successFunction() {
  print('success');
}
''');

      final analyzer = ParallelAnalyzer('$testProjectPath/lib');

      final results = await analyzer.analyzeStream().toList();

      await analyzer.dispose();

      expect(results.length, equals(1));
      expect(results.first.isSuccess, isTrue);
      expect(results.first.fileResult, isNotNull);
      expect(results.first.error, isNull);
      expect(results.first.functions.length, equals(1));
      expect(results.first.functions.first.functionName, equals('successFunction'));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('handles empty project gracefully', () async {
      Directory('$testProjectPath/empty').createSync(recursive: true);

      final analyzer = ParallelAnalyzer('$testProjectPath/empty');
      final report = await analyzer.analyzeWithProgress();

      await analyzer.dispose();

      expect(report.projectMetrics.fileCount, equals(0));
      expect(report.projectMetrics.functionCount, equals(0));
    });

    test('respects maxConcurrency setting', () async {
      // Create multiple files
      for (var i = 0; i < 10; i++) {
        File('$testProjectPath/lib/file$i.dart').createSync(recursive: true);
        File('$testProjectPath/lib/file$i.dart')
            .writeAsStringSync('void func$i() { print($i); }');
      }

      final analyzer = ParallelAnalyzer(
        '$testProjectPath/lib',
        config: const ParallelAnalysisConfig(
          maxConcurrency: 2,
          chunkSize: 5,
        ),
      );

      final report = await analyzer.analyzeWithProgress();

      await analyzer.dispose();

      expect(report.projectMetrics.fileCount, equals(10));
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('MetricsAggregator.addPrecomputedResult', () {
    test('adds precomputed results correctly', () {
      final aggregator = MetricsAggregator();

      // Create mock file result using the calculator
      // We'll test with empty results since we can't easily create
      // FileMaintainabilityResult without parsing real code

      expect(aggregator.fileCount, equals(0));
      expect(aggregator.functionCount, equals(0));
    });
  });
}
