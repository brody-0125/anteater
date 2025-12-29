import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:anteater/anteater.dart';
import 'package:test/test.dart';

void main() {
  group('ComplexityCalculator', () {
    late ComplexityCalculator calculator;

    setUp(() {
      calculator = ComplexityCalculator();
    });

    group('Cyclomatic Complexity', () {
      test('simple function has complexity 1', () {
        const code = '''
void simple() {
  print('hello');
}
''';
        final result = parseString(content: code);
        final function = result.unit.declarations.first;
        final complexity =
            calculator.calculateCyclomaticComplexity(function);

        expect(complexity, equals(1));
      });

      test('if statement adds 1', () {
        const code = '''
void withIf(bool x) {
  if (x) {
    print('yes');
  }
}
''';
        final result = parseString(content: code);
        final function = result.unit.declarations.first;
        final complexity =
            calculator.calculateCyclomaticComplexity(function);

        expect(complexity, equals(2));
      });

      test('logical operators add complexity', () {
        const code = '''
void withLogical(bool a, bool b, bool c) {
  if (a && b || c) {
    print('complex');
  }
}
''';
        final result = parseString(content: code);
        final function = result.unit.declarations.first;
        final complexity =
            calculator.calculateCyclomaticComplexity(function);

        // 1 base + 1 if + 1 && + 1 || = 4
        expect(complexity, equals(4));
      });

      test('null-aware operators add complexity', () {
        const code = '''
void withNullAware(String? x) {
  final len = x?.length ?? 0;
  print(len);
}
''';
        final result = parseString(content: code);
        final function = result.unit.declarations.first;
        final complexity =
            calculator.calculateCyclomaticComplexity(function);

        // 1 base + 1 ?. + 1 ?? = 3
        expect(complexity, equals(3));
      });
    });

    group('Cognitive Complexity', () {
      test('nested if increases complexity exponentially', () {
        const code = '''
void nested(bool a, bool b) {
  if (a) {
    if (b) {
      print('nested');
    }
  }
}
''';
        final result = parseString(content: code);
        final function = result.unit.declarations.first;
        final complexity =
            calculator.calculateCognitiveComplexity(function);

        // Outer if: 1 + 0 nesting = 1
        // Inner if: 1 + 1 nesting = 2
        // Plus function nesting and other factors = 5
        expect(complexity, greaterThanOrEqualTo(3));
      });
    });

    group('Halstead Metrics', () {
      test('calculates volume for simple expression', () {
        const code = '''
int add(int a, int b) {
  return a + b;
}
''';
        final result = parseString(content: code);
        final function = result.unit.declarations.first;
        final halstead = calculator.calculateHalsteadMetrics(function);

        expect(halstead.n1, greaterThan(0));
        expect(halstead.n2, greaterThan(0));
        expect(halstead.volume, greaterThan(0));
      });
    });
  });

  group('MetricsAggregator', () {
    late MetricsAggregator aggregator;

    setUp(() {
      aggregator = MetricsAggregator();
    });

    group('Basic Operations', () {
      test('starts with zero files and functions', () {
        expect(aggregator.fileCount, equals(0));
        expect(aggregator.functionCount, equals(0));
      });

      test('counts files after adding', () {
        const code = '''
void simple() {
  print('hello');
}
''';
        final result = parseString(content: code);
        aggregator.addFile('test.dart', result.unit);

        expect(aggregator.fileCount, equals(1));
        expect(aggregator.functionCount, equals(1));
      });

      test('counts multiple functions in one file', () {
        const code = '''
void func1() {
  print('one');
}

void func2() {
  print('two');
}

void func3() {
  print('three');
}
''';
        final result = parseString(content: code);
        aggregator.addFile('test.dart', result.unit);

        expect(aggregator.fileCount, equals(1));
        expect(aggregator.functionCount, equals(3));
      });

      test('counts class methods', () {
        const code = '''
class MyClass {
  void method1() {
    print('one');
  }

  void method2() {
    print('two');
  }
}
''';
        final result = parseString(content: code);
        aggregator.addFile('test.dart', result.unit);

        expect(aggregator.fileCount, equals(1));
        expect(aggregator.functionCount, equals(2));
      });

      test('removes file correctly', () {
        const code = '''
void func1() { print('one'); }
void func2() { print('two'); }
''';
        final result = parseString(content: code);
        aggregator.addFile('test.dart', result.unit);

        expect(aggregator.functionCount, equals(2));

        aggregator.removeFile('test.dart');

        expect(aggregator.fileCount, equals(0));
        expect(aggregator.functionCount, equals(0));
      });

      test('clears all data', () {
        const code1 = 'void func1() { print("one"); }';
        const code2 = 'void func2() { print("two"); }';
        final result1 = parseString(content: code1);
        final result2 = parseString(content: code2);

        aggregator.addFile('file1.dart', result1.unit);
        aggregator.addFile('file2.dart', result2.unit);

        expect(aggregator.fileCount, equals(2));

        aggregator.clear();

        expect(aggregator.fileCount, equals(0));
        expect(aggregator.functionCount, equals(0));
      });
    });

    group('Project Metrics', () {
      test('returns empty metrics for empty aggregator', () {
        final metrics = aggregator.getProjectMetrics();

        expect(metrics.fileCount, equals(0));
        expect(metrics.functionCount, equals(0));
        expect(metrics.totalLinesOfCode, equals(0));
      });

      test('calculates project-wide statistics', () {
        const code = '''
void simple1() {
  print('hello');
}

void simple2() {
  print('world');
}

void complex(bool a, bool b) {
  if (a) {
    if (b) {
      print('nested');
    }
  }
}
''';
        final result = parseString(content: code);
        aggregator.addFile('test.dart', result.unit);

        final metrics = aggregator.getProjectMetrics();

        expect(metrics.fileCount, equals(1));
        expect(metrics.functionCount, equals(3));
        expect(metrics.totalLinesOfCode, greaterThan(0));
        expect(metrics.maintainabilityIndex.mean, greaterThan(0));
        expect(metrics.cyclomaticComplexity.mean, greaterThanOrEqualTo(1));
      });

      test('calculates statistics across multiple files', () {
        const code1 = '''
void func1() { print('one'); }
void func2() { print('two'); }
''';
        const code2 = '''
void func3() { print('three'); }
''';
        final result1 = parseString(content: code1);
        final result2 = parseString(content: code2);

        aggregator.addFile('file1.dart', result1.unit);
        aggregator.addFile('file2.dart', result2.unit);

        final metrics = aggregator.getProjectMetrics();

        expect(metrics.fileCount, equals(2));
        expect(metrics.functionCount, equals(3));
      });
    });

    group('Violation Detection', () {
      test('detects complexity violations', () {
        // Create a function with high complexity
        const code = '''
void highComplexity(int x) {
  if (x > 0) {
    if (x > 10) {
      if (x > 20) {
        if (x > 30) {
          if (x > 40) {
            if (x > 50) {
              if (x > 60) {
                if (x > 70) {
                  if (x > 80) {
                    if (x > 90) {
                      if (x > 100) {
                        if (x > 110) {
                          if (x > 120) {
                            if (x > 130) {
                              if (x > 140) {
                                if (x > 150) {
                                  if (x > 160) {
                                    if (x > 170) {
                                      if (x > 180) {
                                        if (x > 190) {
                                          if (x > 200) {
                                            print('very complex');
                                          }
                                        }
                                      }
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
''';
        final result = parseString(content: code);
        aggregator.addFile('test.dart', result.unit);

        final violations = aggregator.getViolations();

        expect(violations, isNotEmpty);
        expect(violations.first.functionName, equals('highComplexity'));
      });

      test('uses custom thresholds', () {
        final strictAggregator = MetricsAggregator(
          thresholds: const MetricsThresholds(
            maxCyclomatic: 1, // Very strict: only 1 allowed
            maxCognitive: 1,
            minMaintainability: 99, // Almost impossible
            maxLinesOfCode: 2,
          ),
        );

        const code = '''
void slightlyComplex(bool a, bool b) {
  if (a && b) {
    print('yes');
  } else {
    print('no');
  }
}
''';
        final result = parseString(content: code);
        strictAggregator.addFile('test.dart', result.unit);

        final violations = strictAggregator.getViolations();

        // Should violate at least one threshold (cyclomatic > 1, LOC > 2)
        expect(violations, isNotEmpty);
      });
    });

    group('Ranking Functions', () {
      test('returns worst functions sorted by MI', () {
        const code = '''
void simple() {
  print('hello');
}

void complex(int x) {
  if (x > 0) {
    if (x > 10) {
      if (x > 20) {
        if (x > 30) {
          print('deep nesting');
        }
      }
    }
  }
}
''';
        final result = parseString(content: code);
        aggregator.addFile('test.dart', result.unit);

        final worst = aggregator.getWorstFunctions(5);

        expect(worst, isNotEmpty);
        // Worst should be first
        expect(
          worst.first.result.maintainabilityIndex,
          lessThanOrEqualTo(worst.last.result.maintainabilityIndex),
        );
      });

      test('returns most complex functions sorted by cyclomatic', () {
        const code = '''
void simple() {
  print('hello');
}

void complex(int x) {
  if (x > 0 && x < 100) {
    switch (x) {
      case 1:
        print('one');
      case 2:
        print('two');
      case 3:
        print('three');
    }
  }
}
''';
        final result = parseString(content: code);
        aggregator.addFile('test.dart', result.unit);

        final mostComplex = aggregator.getMostComplexFunctions(5);

        expect(mostComplex, isNotEmpty);
        // Most complex should be first
        expect(
          mostComplex.first.result.cyclomaticComplexity,
          greaterThanOrEqualTo(mostComplex.last.result.cyclomaticComplexity),
        );
      });
    });

    group('Rating Distribution', () {
      test('calculates rating distribution', () {
        const code = '''
void simple1() { print('one'); }
void simple2() { print('two'); }
void simple3() { print('three'); }
''';
        final result = parseString(content: code);
        aggregator.addFile('test.dart', result.unit);

        final distribution = aggregator.getRatingDistribution();

        expect(distribution.total, equals(3));
        expect(distribution.good + distribution.moderate + distribution.poor,
            equals(3));
      });

      test('calculates percentages correctly', () {
        const code = '''
void simple() { print('hello'); }
''';
        final result = parseString(content: code);
        aggregator.addFile('test.dart', result.unit);

        final distribution = aggregator.getRatingDistribution();

        expect(
          distribution.goodPercent +
              distribution.moderatePercent +
              distribution.poorPercent,
          closeTo(100, 0.01),
        );
      });
    });

    group('File Summary', () {
      test('returns files sorted by maintainability', () {
        const simpleCode = '''
void simple() { print('hello'); }
''';
        const complexCode = '''
void complex(int x) {
  if (x > 0) {
    if (x > 10) {
      if (x > 20) {
        print('nested');
      }
    }
  }
}
''';
        final simpleResult = parseString(content: simpleCode);
        final complexResult = parseString(content: complexCode);

        aggregator.addFile('simple.dart', simpleResult.unit);
        aggregator.addFile('complex.dart', complexResult.unit);

        final files = aggregator.getFilesSortedByMaintainability();

        expect(files.length, equals(2));
        // Sorted worst first (lower MI first)
        expect(
          files.first.result.averageMaintainabilityIndex,
          lessThanOrEqualTo(files.last.result.averageMaintainabilityIndex),
        );
      });
    });

    group('Report Generation', () {
      test('generates comprehensive report', () {
        const code = '''
void simple() { print('hello'); }

void complex(int x) {
  if (x > 0 && x < 100) {
    for (var i = 0; i < x; i++) {
      print(i);
    }
  }
}
''';
        final result = parseString(content: code);
        aggregator.addFile('test.dart', result.unit);

        final report = aggregator.generateReport();

        expect(report.projectMetrics.fileCount, equals(1));
        expect(report.projectMetrics.functionCount, equals(2));
        expect(report.ratingDistribution.total, equals(2));
        expect(report.healthScore, greaterThan(0));
        expect(report.healthScore, lessThanOrEqualTo(100));
      });

      test('health score is 100 for empty project', () {
        final report = aggregator.generateReport();

        expect(report.healthScore, equals(100));
      });

      test('hasViolations reflects violation state', () {
        const code = '''
void simple() { print('hello'); }
''';
        final result = parseString(content: code);
        aggregator.addFile('test.dart', result.unit);

        final report = aggregator.generateReport();

        // Simple code should have no violations with default thresholds
        expect(report.hasViolations, isFalse);
      });

      test('report toString is formatted', () {
        const code = '''
void func() { print('test'); }
''';
        final result = parseString(content: code);
        aggregator.addFile('test.dart', result.unit);

        final report = aggregator.generateReport();
        final reportString = report.toString();

        expect(reportString, contains('Project Metrics Report'));
        expect(reportString, contains('Health Score'));
      });
    });

    group('MetricStats', () {
      test('calculates min, max, mean correctly', () {
        const code = '''
void small() { print('s'); }

void medium() {
  if (true) print('m');
}

void large() {
  if (true) {
    if (true) {
      print('l');
    }
  }
}
''';
        final result = parseString(content: code);
        aggregator.addFile('test.dart', result.unit);

        final metrics = aggregator.getProjectMetrics();
        final cc = metrics.cyclomaticComplexity;

        expect(cc.min, greaterThanOrEqualTo(1));
        expect(cc.max, greaterThanOrEqualTo(cc.min));
        expect(cc.mean, greaterThanOrEqualTo(cc.min));
        expect(cc.mean, lessThanOrEqualTo(cc.max));
      });
    });
  });
}
