import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';

import 'package:anteater/debt/debt_item.dart';
import 'package:anteater/debt/debt_config.dart';
import 'package:anteater/debt/debt_detector.dart';
import 'package:anteater/debt/cost_calculator.dart';
import 'package:anteater/debt/debt_aggregator.dart';
import 'package:anteater/rules/rule.dart' show SourceRange;

void main() {
  group('DebtType', () {
    test('has correct default severities', () {
      expect(DebtType.todo.defaultSeverity, equals(DebtSeverity.medium));
      expect(DebtType.fixme.defaultSeverity, equals(DebtSeverity.high));
      expect(DebtType.ignoreComment.defaultSeverity, equals(DebtSeverity.high));
      expect(DebtType.ignoreForFile.defaultSeverity, equals(DebtSeverity.critical));
      expect(DebtType.asDynamic.defaultSeverity, equals(DebtSeverity.high));
    });

    test('has human-readable labels', () {
      expect(DebtType.todo.label, equals('TODO'));
      expect(DebtType.fixme.label, equals('FIXME'));
      expect(DebtType.asDynamic.label, equals('as dynamic'));
    });
  });

  group('DebtSeverity', () {
    test('has correct multipliers', () {
      expect(DebtSeverity.critical.multiplier, equals(4.0));
      expect(DebtSeverity.high.multiplier, equals(2.0));
      expect(DebtSeverity.medium.multiplier, equals(1.0));
      expect(DebtSeverity.low.multiplier, equals(0.5));
    });
  });

  group('DebtCostConfig', () {
    test('defaults provides all debt types', () {
      final config = DebtCostConfig.defaults();

      expect(config.costs.length, equals(10));
      expect(config.getCost(DebtType.todo), equals(4.0));
      expect(config.getCost(DebtType.fixme), equals(8.0));
      expect(config.getCost(DebtType.asDynamic), equals(16.0));
      expect(config.unit, equals('hours'));
      expect(config.threshold, equals(40.0));
    });

    test('fromYaml parses custom costs', () {
      final config = DebtCostConfig.fromYaml({
        'costs': {
          'todo': 2.0,
          'fixme': 4.0,
        },
        'threshold': 100.0,
        'unit': 'story_points',
      });

      expect(config.getCost(DebtType.todo), equals(2.0));
      expect(config.getCost(DebtType.fixme), equals(4.0));
      expect(config.threshold, equals(100.0));
      expect(config.unit, equals('story_points'));
    });

    test('fromYaml handles aliases', () {
      final config = DebtCostConfig.fromYaml({
        'costs': {
          'ignore': 10.0,
          'ignore-for-file': 20.0,
          'as-dynamic': 30.0,
        },
      });

      expect(config.getCost(DebtType.ignoreComment), equals(10.0));
      expect(config.getCost(DebtType.ignoreForFile), equals(20.0));
      expect(config.getCost(DebtType.asDynamic), equals(30.0));
    });
  });

  group('DebtDetector', () {
    late DebtDetector detector;

    setUp(() {
      detector = DebtDetector();
    });

    test('detects TODO comments', () {
      const source = '''
void main() {
  // TODO: implement this later
  print('hello');
}
''';
      final unit = parseString(content: source).unit;

      final items = detector.detect(unit, 'test.dart', sourceCode: source);

      expect(items.length, equals(1));
      expect(items.first.type, equals(DebtType.todo));
      expect(items.first.description, contains('implement this later'));
    });

    test('detects FIXME comments', () {
      const source = '''
void main() {
  // FIXME: this is broken
  print('hello');
}
''';
      final unit = parseString(content: source).unit;

      final items = detector.detect(unit, 'test.dart', sourceCode: source);

      expect(items.length, equals(1));
      expect(items.first.type, equals(DebtType.fixme));
      expect(items.first.description, contains('this is broken'));
    });

    test('detects ignore comments', () {
      const source = '''
void main() {
  // ignore: avoid_print
  print('hello');
}
''';
      final unit = parseString(content: source).unit;

      final items = detector.detect(unit, 'test.dart', sourceCode: source);

      expect(items.length, equals(1));
      expect(items.first.type, equals(DebtType.ignoreComment));
    });

    test('detects ignore_for_file comments', () {
      const source = '''
// ignore_for_file: avoid_print

void main() {
  print('hello');
}
''';
      final unit = parseString(content: source).unit;

      final items = detector.detect(unit, 'test.dart', sourceCode: source);

      expect(items.length, equals(1));
      expect(items.first.type, equals(DebtType.ignoreForFile));
    });

    test('detects as dynamic casts', () {
      final unit = parseString(content: '''
void main() {
  Object obj = 'hello';
  var str = obj as dynamic;
}
''').unit;

      final items = detector.detect(unit, 'test.dart');

      expect(items.length, equals(1));
      expect(items.first.type, equals(DebtType.asDynamic));
    });

    test('detects @deprecated annotations', () {
      final unit = parseString(content: '''
@deprecated
void oldFunction() {}
''').unit;

      final items = detector.detect(unit, 'test.dart');

      expect(items.length, equals(1));
      expect(items.first.type, equals(DebtType.deprecated));
    });

    test('detects multiple debt items', () {
      const source = '''
// TODO: fix this
// FIXME: broken
void main() {
  var x = null as dynamic;
  // ignore: unused_variable
  var y = 1;
}
''';
      final unit = parseString(content: source).unit;

      final items = detector.detect(unit, 'test.dart', sourceCode: source);

      expect(items.length, equals(4));
      expect(items.map((i) => i.type).toSet(), containsAll([
        DebtType.todo,
        DebtType.fixme,
        DebtType.asDynamic,
        DebtType.ignoreComment,
      ]));
    });
  });

  group('DebtCostCalculator', () {
    late DebtCostCalculator calculator;

    setUp(() {
      calculator = DebtCostCalculator();
    });

    test('calculates item cost with severity multiplier', () {
      final todoItem = DebtItem(
        type: DebtType.todo,
        description: 'test',
        location: SourceRange.zero,
        filePath: 'test.dart',
      );

      // TODO: 4 hours * medium (1.0) = 4 hours
      expect(calculator.calculateItemCost(todoItem), equals(4.0));

      final criticalItem = DebtItem(
        type: DebtType.ignoreForFile,
        description: 'test',
        location: SourceRange.zero,
        filePath: 'test.dart',
      );

      // ignoreForFile: 16 hours * critical (4.0) = 64 hours
      expect(calculator.calculateItemCost(criticalItem), equals(64.0));
    });

    test('calculateTotal aggregates costs', () {
      final items = [
        DebtItem(
          type: DebtType.todo,
          description: 'test1',
          location: SourceRange.zero,
          filePath: 'test.dart',
        ),
        DebtItem(
          type: DebtType.todo,
          description: 'test2',
          location: SourceRange.zero,
          filePath: 'test.dart',
        ),
        DebtItem(
          type: DebtType.fixme,
          description: 'test3',
          location: SourceRange.zero,
          filePath: 'test.dart',
        ),
      ];

      final summary = calculator.calculateTotal(items);

      // 2 TODOs: 2 * 4 * 1.0 = 8
      // 1 FIXME: 1 * 8 * 2.0 = 16
      // Total: 24
      expect(summary.itemCount, equals(3));
      expect(summary.totalCost, equals(24.0));
      expect(summary.getCountForType(DebtType.todo), equals(2));
      expect(summary.getCountForType(DebtType.fixme), equals(1));
    });

    test('summary detects threshold exceeded', () {
      final items = List.generate(
        20,
        (i) => DebtItem(
          type: DebtType.fixme,
          description: 'test$i',
          location: SourceRange.zero,
          filePath: 'test.dart',
        ),
      );

      final summary = calculator.calculateTotal(items);

      // 20 FIXMEs: 20 * 8 * 2.0 = 320 hours (> 40 threshold)
      expect(summary.exceedsThreshold, isTrue);
    });
  });

  group('DebtAggregator', () {
    test('aggregates debt across multiple files', () {
      final aggregator = DebtAggregator();

      const source1 = '''
// TODO: implement
void main() {}
''';
      final unit1 = parseString(content: source1).unit;

      const source2 = '''
// FIXME: broken
void helper() {}
''';
      final unit2 = parseString(content: source2).unit;

      aggregator.addFile('file1.dart', unit1, sourceCode: source1);
      aggregator.addFile('file2.dart', unit2, sourceCode: source2);

      expect(aggregator.totalItemCount, equals(2));
      expect(aggregator.analyzedFiles.length, equals(2));
    });

    test('generateReport creates comprehensive report', () {
      final aggregator = DebtAggregator();

      const source = '''
// TODO: item 1
// TODO: item 2
// FIXME: item 3
void main() {}
''';
      final unit = parseString(content: source).unit;

      aggregator.addFile('test.dart', unit, sourceCode: source);

      final report = aggregator.generateReport();

      expect(report.items.length, equals(3));
      expect(report.byFile.containsKey('test.dart'), isTrue);
      expect(report.summary.itemCount, equals(3));
    });

    test('getHotspots returns files sorted by debt cost', () {
      final aggregator = DebtAggregator();

      const lowSource = '''
// TODO: small issue
void main() {}
''';
      final lowDebtUnit = parseString(content: lowSource).unit;

      const highSource = '''
// FIXME: big issue 1
// FIXME: big issue 2
// FIXME: big issue 3
void helper() {}
''';
      final highDebtUnit = parseString(content: highSource).unit;

      aggregator.addFile('low.dart', lowDebtUnit, sourceCode: lowSource);
      aggregator.addFile('high.dart', highDebtUnit, sourceCode: highSource);

      final hotspots = aggregator.getHotspots(2);

      expect(hotspots.first.key, equals('high.dart'));
      expect(hotspots.first.value, greaterThan(hotspots.last.value));
    });
  });

  group('DebtReport', () {
    test('toMarkdown generates valid markdown', () {
      final aggregator = DebtAggregator();

      const source = '''
// TODO: implement feature
// FIXME: critical bug
void main() {}
''';
      final unit = parseString(content: source).unit;

      aggregator.addFile('test.dart', unit, sourceCode: source);
      final report = aggregator.generateReport();

      final markdown = report.toMarkdown();

      expect(markdown, contains('# Technical Debt Report'));
      expect(markdown, contains('## Summary'));
      expect(markdown, contains('## Breakdown by Type'));
      expect(markdown, contains('TODO'));
      expect(markdown, contains('FIXME'));
    });

    test('toConsole generates console output', () {
      final aggregator = DebtAggregator();

      const source = '''
// TODO: test
void main() {}
''';
      final unit = parseString(content: source).unit;

      aggregator.addFile('test.dart', unit, sourceCode: source);
      final report = aggregator.generateReport();

      final console = report.toConsole();

      expect(console, contains('Total:'));
      expect(console, contains('Items:'));
    });

    test('toJson generates valid JSON structure', () {
      final aggregator = DebtAggregator();

      const source = '''
// TODO: test
void main() {}
''';
      final unit = parseString(content: source).unit;

      aggregator.addFile('test.dart', unit, sourceCode: source);
      final report = aggregator.generateReport();

      final json = report.toJson();

      expect(json, containsPair('summary', isA<Map<String, dynamic>>()));
      expect(json, containsPair('items', isA<List<Map<String, dynamic>>>()));
      expect(json, containsPair('byFile', isA<Map<String, dynamic>>()));
    });

    test('getHotspots returns top N files', () {
      final aggregator = DebtAggregator();

      for (var i = 0; i < 15; i++) {
        final source = '''
// TODO: item $i
void main() {}
''';
        final unit = parseString(content: source).unit;
        aggregator.addFile('file$i.dart', unit, sourceCode: source);
      }

      final report = aggregator.generateReport();
      final hotspots = report.getHotspots(5);

      expect(hotspots.length, equals(5));
    });
  });

  group('DebtTrend', () {
    test('calculates cost change', () {
      const trend = DebtTrend(
        previousTotal: 100.0,
        currentTotal: 120.0,
        previousItemCount: 10,
        currentItemCount: 12,
        unit: 'hours',
      );

      expect(trend.costChange, equals(20.0));
      expect(trend.costChangePercent, equals(20.0));
      expect(trend.itemCountChange, equals(2));
      expect(trend.isIncreasing, isTrue);
      expect(trend.direction, equals('increasing'));
    });

    test('detects decreasing trend', () {
      const trend = DebtTrend(
        previousTotal: 100.0,
        currentTotal: 80.0,
        previousItemCount: 10,
        currentItemCount: 8,
        unit: 'hours',
      );

      expect(trend.costChange, equals(-20.0));
      expect(trend.isDecreasing, isTrue);
      expect(trend.direction, equals('decreasing'));
    });

    test('detects stable trend', () {
      const trend = DebtTrend(
        previousTotal: 100.0,
        currentTotal: 100.0,
        previousItemCount: 10,
        currentItemCount: 10,
        unit: 'hours',
      );

      expect(trend.costChange, equals(0.0));
      expect(trend.direction, equals('stable'));
    });
  });
}
