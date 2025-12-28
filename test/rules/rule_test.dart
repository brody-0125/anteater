import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';

import 'package:anteater/rules/rule.dart';
import 'package:anteater/rules/rule_registry.dart';
import 'package:anteater/rules/rule_runner.dart';
import 'package:anteater/rules/rule_config.dart';
import 'package:anteater/rules/rules/safety/avoid_dynamic_rule.dart';
import 'package:anteater/rules/rules/safety/avoid_global_state_rule.dart';
import 'package:anteater/rules/rules/safety/avoid_late_keyword_rule.dart';
import 'package:anteater/rules/rules/safety/no_empty_block_rule.dart';
import 'package:anteater/rules/rules/safety/no_equal_then_else_rule.dart';
import 'package:anteater/rules/rules/quality/prefer_first_last_rule.dart';
import 'package:anteater/rules/rules/quality/binary_expression_order_rule.dart';

void main() {
  group('RuleRegistry', () {
    test('withDefaults registers all built-in rules', () {
      final registry = RuleRegistry.withDefaults();

      expect(registry.ruleCount, equals(10));
      expect(registry.contains('avoid-dynamic'), isTrue);
      expect(registry.contains('avoid-global-state'), isTrue);
      expect(registry.contains('avoid-late-keyword'), isTrue);
      expect(registry.contains('no-empty-block'), isTrue);
      expect(registry.contains('no-equal-then-else'), isTrue);
      expect(registry.contains('prefer-async-await'), isTrue);
      expect(registry.contains('prefer-first-last'), isTrue);
      expect(registry.contains('prefer-trailing-comma'), isTrue);
      expect(registry.contains('binary-expression-order'), isTrue);
      expect(registry.contains('avoid-unnecessary-cast'), isTrue);
    });

    test('can enable and disable rules', () {
      final registry = RuleRegistry.withDefaults();

      expect(registry.isEnabled('avoid-dynamic'), isTrue);

      registry.disable('avoid-dynamic');
      expect(registry.isEnabled('avoid-dynamic'), isFalse);

      registry.enable('avoid-dynamic');
      expect(registry.isEnabled('avoid-dynamic'), isTrue);
    });

    test('can set severity override', () {
      final registry = RuleRegistry.withDefaults();

      // Default severity
      expect(registry.getSeverity('avoid-dynamic'), equals(RuleSeverity.warning));

      // Override to error
      registry.setSeverity('avoid-dynamic', RuleSeverity.error);
      expect(registry.getSeverity('avoid-dynamic'), equals(RuleSeverity.error));
    });

    test('getRulesByCategory returns correct rules', () {
      final registry = RuleRegistry.withDefaults();

      final safetyRules = registry.getRulesByCategory(RuleCategory.safety).toList();
      expect(safetyRules.length, equals(5));

      final qualityRules = registry.getRulesByCategory(RuleCategory.quality).toList();
      expect(qualityRules.length, equals(5));
    });

    test('applyConfig enables rules from list', () {
      final registry = RuleRegistry();
      registry.register(AvoidDynamicRule());

      registry.disable('avoid-dynamic');
      expect(registry.isEnabled('avoid-dynamic'), isFalse);

      registry.applyConfig({
        'rules': ['avoid-dynamic'],
      });

      expect(registry.isEnabled('avoid-dynamic'), isTrue);
    });
  });

  group('RuleRunner', () {
    late RuleRegistry registry;
    late RuleRunner runner;

    setUp(() {
      registry = RuleRegistry.withDefaults();
      runner = RuleRunner(registry: registry);
    });

    test('analyze returns violations from enabled rules', () {
      const code = '''
void main() {
  dynamic x = 10;
}
''';
      final result = parseString(content: code);
      final violations = runner.analyze(
        result.unit,
        lineInfo: result.lineInfo,
      );

      expect(violations.any((v) => v.ruleId == 'avoid-dynamic'), isTrue);
    });

    test('analyze respects disabled rules', () {
      const code = '''
void main() {
  dynamic x = 10;
}
''';
      registry.disable('avoid-dynamic');

      final result = parseString(content: code);
      final violations = runner.analyze(
        result.unit,
        lineInfo: result.lineInfo,
      );

      expect(violations.any((v) => v.ruleId == 'avoid-dynamic'), isFalse);
    });

    test('analyzeWithRule only runs specified rule', () {
      const code = '''
void main() {
  dynamic x = 10;
  var list = [1, 2, 3];
  print(list[0]);
}
''';
      final result = parseString(content: code);
      final violations = runner.analyzeWithRule(
        'avoid-dynamic',
        result.unit,
        lineInfo: result.lineInfo,
      );

      expect(violations.every((v) => v.ruleId == 'avoid-dynamic'), isTrue);
    });
  });

  group('Safety Rules', () {
    group('AvoidDynamicRule', () {
      late AvoidDynamicRule rule;

      setUp(() {
        rule = AvoidDynamicRule();
      });

      test('detects dynamic type annotation', () {
        const code = '''
void main() {
  dynamic x = 10;
}
''';
        final result = parseString(content: code);
        final violations = rule.check(result.unit, lineInfo: result.lineInfo);

        expect(violations, hasLength(1));
        expect(violations.first.ruleId, equals('avoid-dynamic'));
      });

      test('detects as dynamic cast', () {
        const code = '''
void main() {
  Object x = 10;
  var y = x as dynamic;
}
''';
        final result = parseString(content: code);
        final violations = rule.check(result.unit, lineInfo: result.lineInfo);

        expect(violations.length, greaterThanOrEqualTo(1));
      });

      test('ignores non-dynamic types', () {
        const code = '''
void main() {
  int x = 10;
  String y = 'hello';
}
''';
        final result = parseString(content: code);
        final violations = rule.check(result.unit, lineInfo: result.lineInfo);

        expect(violations, isEmpty);
      });
    });

    group('AvoidGlobalStateRule', () {
      late AvoidGlobalStateRule rule;

      setUp(() {
        rule = AvoidGlobalStateRule();
      });

      test('detects mutable top-level variable', () {
        const code = '''
var globalCounter = 0;

void main() {
  globalCounter++;
}
''';
        final result = parseString(content: code);
        final violations = rule.check(result.unit, lineInfo: result.lineInfo);

        expect(violations, hasLength(1));
        expect(violations.first.ruleId, equals('avoid-global-state'));
      });

      test('ignores final top-level variable', () {
        const code = '''
final globalValue = 42;
const constantValue = 100;

void main() {
  print(globalValue);
}
''';
        final result = parseString(content: code);
        final violations = rule.check(result.unit, lineInfo: result.lineInfo);

        expect(violations, isEmpty);
      });

      test('detects mutable static field', () {
        const code = '''
class Counter {
  static int count = 0;
}
''';
        final result = parseString(content: code);
        final violations = rule.check(result.unit, lineInfo: result.lineInfo);

        expect(violations, hasLength(1));
      });
    });

    group('AvoidLateKeywordRule', () {
      late AvoidLateKeywordRule rule;

      setUp(() {
        rule = AvoidLateKeywordRule();
      });

      test('detects late variable without initializer', () {
        const code = '''
class Widget {
  late String name;
}
''';
        final result = parseString(content: code);
        final violations = rule.check(result.unit, lineInfo: result.lineInfo);

        expect(violations, hasLength(1));
        expect(violations.first.ruleId, equals('avoid-late-keyword'));
      });

      test('ignores late final with initializer (lazy pattern)', () {
        const code = '''
class Config {
  late final String value = computeValue();

  String computeValue() => 'computed';
}
''';
        final result = parseString(content: code);
        final violations = rule.check(result.unit, lineInfo: result.lineInfo);

        expect(violations, isEmpty);
      });
    });

    group('NoEmptyBlockRule', () {
      late NoEmptyBlockRule rule;

      setUp(() {
        rule = NoEmptyBlockRule();
      });

      test('detects empty if block', () {
        const code = '''
void main() {
  if (true) {}
}
''';
        final result = parseString(content: code);
        final violations = rule.check(result.unit, lineInfo: result.lineInfo);

        expect(violations, hasLength(1));
      });

      test('ignores block with content', () {
        const code = '''
void main() {
  if (true) {
    print('hello');
  }
}
''';
        final result = parseString(content: code);
        final violations = rule.check(result.unit, lineInfo: result.lineInfo);

        expect(violations, isEmpty);
      });
    });

    group('NoEqualThenElseRule', () {
      late NoEqualThenElseRule rule;

      setUp(() {
        rule = NoEqualThenElseRule();
      });

      test('detects identical if/else blocks', () {
        const code = '''
void main() {
  var x = 10;
  if (x > 5) {
    print('hello');
  } else {
    print('hello');
  }
}
''';
        final result = parseString(content: code);
        final violations = rule.check(result.unit, lineInfo: result.lineInfo);

        expect(violations, hasLength(1));
        expect(violations.first.ruleId, equals('no-equal-then-else'));
      });

      test('ignores different if/else blocks', () {
        const code = '''
void main() {
  var x = 10;
  if (x > 5) {
    print('greater');
  } else {
    print('less');
  }
}
''';
        final result = parseString(content: code);
        final violations = rule.check(result.unit, lineInfo: result.lineInfo);

        expect(violations, isEmpty);
      });
    });
  });

  group('Quality Rules', () {
    group('PreferFirstLastRule', () {
      late PreferFirstLastRule rule;

      setUp(() {
        rule = PreferFirstLastRule();
      });

      test('detects list[0] access', () {
        const code = '''
void main() {
  var list = [1, 2, 3];
  print(list[0]);
}
''';
        final result = parseString(content: code);
        final violations = rule.check(result.unit, lineInfo: result.lineInfo);

        expect(violations, hasLength(1));
        expect(violations.first.message, contains('.first'));
      });

      test('detects list[length-1] access', () {
        const code = '''
void main() {
  var list = [1, 2, 3];
  print(list[list.length - 1]);
}
''';
        final result = parseString(content: code);
        final violations = rule.check(result.unit, lineInfo: result.lineInfo);

        expect(violations, hasLength(1));
        expect(violations.first.message, contains('.last'));
      });
    });

    group('BinaryExpressionOrderRule', () {
      late BinaryExpressionOrderRule rule;

      setUp(() {
        rule = BinaryExpressionOrderRule();
      });

      test('detects Yoda condition', () {
        const code = '''
void main() {
  var x = 10;
  if (0 == x) {
    print('zero');
  }
}
''';
        final result = parseString(content: code);
        final violations = rule.check(result.unit, lineInfo: result.lineInfo);

        expect(violations, hasLength(1));
      });

      test('ignores non-Yoda condition', () {
        const code = '''
void main() {
  var x = 10;
  if (x == 0) {
    print('zero');
  }
}
''';
        final result = parseString(content: code);
        final violations = rule.check(result.unit, lineInfo: result.lineInfo);

        expect(violations, isEmpty);
      });
    });
  });

  group('RuleConfig', () {
    test('parses YAML configuration', () {
      const yaml = '''
anteater:
  exclude:
    - test/**
    - '**/*.g.dart'
  rules:
    - avoid-dynamic
    - prefer-async-await:
        severity: error
        exclude:
          - lib/generated/**
  metrics:
    cyclomatic-complexity: 15
    maintainability-index: 60
''';
      final config = RuleConfig.fromYaml(yaml);

      expect(config.excludePatterns, contains('test/**'));
      expect(config.isEnabled('avoid-dynamic'), isTrue);
      expect(config.isEnabled('prefer-async-await'), isTrue);
      expect(config.getSettings('prefer-async-await').severity,
          equals(RuleSeverity.error));
      expect(config.metrics.cyclomaticComplexity, equals(15));
      expect(config.metrics.maintainabilityIndex, equals(60));
    });

    test('RuleConfigBuilder creates valid config', () {
      final config = RuleConfigBuilder()
          .exclude('test/**')
          .enableRule('avoid-dynamic')
          .configureRule('prefer-async-await',
              severity: RuleSeverity.error, exclude: ['generated/**'])
          .withMetrics(MetricsThresholds(cyclomaticComplexity: 15))
          .build();

      expect(config.excludePatterns, contains('test/**'));
      expect(config.isEnabled('avoid-dynamic'), isTrue);
      expect(config.getSettings('prefer-async-await').severity,
          equals(RuleSeverity.error));
      expect(config.metrics.cyclomaticComplexity, equals(15));
    });
  });

  group('Violation', () {
    test('toString includes location and message', () {
      final violation = Violation(
        ruleId: 'test-rule',
        message: 'Test message',
        location: SourceRange(
          start: SourcePosition(line: 1, column: 1),
          end: SourcePosition(line: 1, column: 10),
          offset: 0,
          length: 10,
        ),
        severity: RuleSeverity.warning,
      );

      expect(violation.toString(), contains('test-rule'));
      expect(violation.toString(), contains('1:1'));
    });
  });

  group('AnalysisResult', () {
    test('calculates statistics correctly', () {
      final result = AnalysisResult(
        violationsByFile: {
          'file1.dart': [
            Violation(
              ruleId: 'rule1',
              message: 'msg',
              location: SourceRange.zero,
              severity: RuleSeverity.error,
            ),
            Violation(
              ruleId: 'rule1',
              message: 'msg',
              location: SourceRange.zero,
              severity: RuleSeverity.warning,
            ),
          ],
          'file2.dart': [
            Violation(
              ruleId: 'rule2',
              message: 'msg',
              location: SourceRange.zero,
              severity: RuleSeverity.error,
            ),
          ],
        },
        filesAnalyzed: 5,
      );

      expect(result.totalViolations, equals(3));
      expect(result.hasViolations, isTrue);
      expect(result.hasErrors, isTrue);
      expect(result.countBySeverity[RuleSeverity.error], equals(2));
      expect(result.countBySeverity[RuleSeverity.warning], equals(1));
      expect(result.countByRule['rule1'], equals(2));
      expect(result.countByRule['rule2'], equals(1));
    });
  });
}
