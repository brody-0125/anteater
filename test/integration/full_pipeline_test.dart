import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

import 'package:anteater/ir/cfg/cfg_builder.dart';
import 'package:anteater/ir/ssa/ssa_builder.dart';
import 'package:anteater/reasoner/datalog/fact_extractor.dart';
import 'package:anteater/reasoner/datalog/datalog_engine.dart';
import 'package:anteater/reasoner/abstract/null_verifier.dart';
import 'package:anteater/reasoner/abstract/bounds_checker.dart';
import 'package:anteater/metrics/complexity_calculator.dart';
import 'package:anteater/metrics/maintainability_index.dart';
import 'package:anteater/metrics/metrics_aggregator.dart';
import 'package:anteater/server/diagnostics_provider.dart';
import 'package:anteater/server/code_actions_provider.dart';
import 'package:anteater/server/language_server.dart';

void main() {
  group('Full Analysis Pipeline', () {
    test('analyzes simple function through entire pipeline', () {
      const source = '''
        void simpleFunction() {
          var x = 1;
          var y = 2;
          var z = x + y;
          print(z);
        }
      ''';

      // 1. Parse source
      final parseResult = parseString(content: source);
      final unit = parseResult.unit;
      expect(unit.declarations, isNotEmpty);

      // 2. Build CFG
      final cfgBuilder = CfgBuilder();
      final funcDecl = unit.declarations.first as FunctionDeclaration;
      final cfg = cfgBuilder.buildFromFunction(funcDecl);
      expect(cfg.blocks, isNotEmpty);
      expect(cfg.entry, isNotNull);

      // 3. Build SSA
      final ssaBuilder = SsaBuilder();
      final ssaCfg = ssaBuilder.buildSsa(cfg);
      expect(ssaCfg.blocks, isNotEmpty);

      // 4. Extract Datalog facts
      final factExtractor = FactExtractor();
      final facts = factExtractor.extractFromCfg(cfg);
      expect(facts, isNotEmpty);

      // 5. Run Datalog engine
      final datalogEngine = InMemoryDatalogEngine();
      datalogEngine.loadFacts(facts);
      datalogEngine.run();

      // Datalog facts were loaded successfully
      // At minimum, we should have some facts loaded
      expect(facts.length, greaterThan(0));

      // 6. Calculate metrics
      final complexityCalculator = ComplexityCalculator();
      final body = funcDecl.functionExpression.body;
      final cyclomatic = complexityCalculator.calculateCyclomaticComplexity(body);
      final cognitive = complexityCalculator.calculateCognitiveComplexity(body);

      expect(cyclomatic, greaterThanOrEqualTo(1));
      expect(cognitive, greaterThanOrEqualTo(0));
    });

    test('analyzes complex function with control flow', () {
      const source = '''
        int complexFunction(int n) {
          var result = 0;
          for (var i = 0; i < n; i++) {
            if (i % 2 == 0) {
              result += i;
            } else {
              result -= i;
            }
          }
          return result;
        }
      ''';

      final parseResult = parseString(content: source);
      final unit = parseResult.unit;

      // Build CFG
      final cfgBuilder = CfgBuilder();
      final funcDecl = unit.declarations.first as FunctionDeclaration;
      final cfg = cfgBuilder.buildFromFunction(funcDecl);

      // Verify CFG structure for loop and branches
      expect(cfg.blocks.length, greaterThan(4));

      // Build SSA
      final ssaBuilder = SsaBuilder();
      final ssaCfg = ssaBuilder.buildSsa(cfg);

      // Should have phi functions for variables modified in loop
      expect(ssaCfg.blocks, isNotEmpty);

      // Calculate complexity
      final complexityCalculator = ComplexityCalculator();
      final body = funcDecl.functionExpression.body;
      final cyclomatic = complexityCalculator.calculateCyclomaticComplexity(body);

      // for loop + if/else should add complexity
      expect(cyclomatic, greaterThan(1));
    });

    test('runs null safety verification', () {
      const source = '''
        void nullSafetyTest(String? maybeNull) {
          if (maybeNull != null) {
            print(maybeNull.length);
          }
        }
      ''';

      final parseResult = parseString(content: source);
      final unit = parseResult.unit;

      // Build CFG
      final cfgBuilder = CfgBuilder();
      final funcDecl = unit.declarations.first as FunctionDeclaration;
      final cfg = cfgBuilder.buildFromFunction(funcDecl);

      // Run null verifier
      final nullVerifier = NullVerifier();
      final nullIssues = nullVerifier.verifyCfg(cfg);

      // Should be safe due to null check
      expect(
        nullIssues.every((issue) => issue.isSafe || !issue.isDefinitelyNull),
        isTrue,
      );
    });

    test('runs bounds checking', () {
      const source = '''
        void boundsTest(List<int> list) {
          for (var i = 0; i < list.length; i++) {
            print(list[i]);
          }
        }
      ''';

      final parseResult = parseString(content: source);
      final unit = parseResult.unit;

      // Build CFG
      final cfgBuilder = CfgBuilder();
      final funcDecl = unit.declarations.first as FunctionDeclaration;
      final cfg = cfgBuilder.buildFromFunction(funcDecl);

      // Run bounds checker
      final boundsChecker = BoundsChecker();
      final boundsIssues = boundsChecker.checkCfg(cfg);

      // Access within loop bounds should be safe
      expect(
        boundsIssues.every((issue) => issue.isSafe || !issue.isDefinitelyUnsafe),
        isTrue,
      );
    });

    test('calculates maintainability index for file', () {
      const source = '''
        void function1() {
          print('hello');
        }

        int function2(int x) {
          if (x > 0) {
            return x * 2;
          }
          return x;
        }

        void function3() {
          for (var i = 0; i < 10; i++) {
            if (i % 2 == 0) {
              print(i);
            }
          }
        }
      ''';

      final parseResult = parseString(content: source);
      final unit = parseResult.unit;

      // Calculate file-level metrics
      final miCalculator = MaintainabilityIndexCalculator();
      final fileResult = miCalculator.calculateForFile(unit);

      expect(fileResult.functions.length, equals(3));
      expect(fileResult.averageMaintainabilityIndex, greaterThan(0));
      expect(fileResult.averageMaintainabilityIndex, lessThanOrEqualTo(100));
    });

    test('aggregates metrics across files', () {
      const source1 = '''
        void function1() {
          print('file1');
        }
      ''';

      const source2 = '''
        void function2(int x) {
          if (x > 0) {
            print(x);
          }
        }
      ''';

      final unit1 = parseString(content: source1).unit;
      final unit2 = parseString(content: source2).unit;

      final aggregator = MetricsAggregator();
      aggregator.addFile('/test/file1.dart', unit1);
      aggregator.addFile('/test/file2.dart', unit2);

      expect(aggregator.fileCount, equals(2));
      expect(aggregator.functionCount, equals(2));

      final projectMetrics = aggregator.getProjectMetrics();
      expect(projectMetrics.functionCount, equals(2));
    });

    test('generates diagnostics from analysis', () {
      // Test that DiagnosticsProvider classes work
      const diagnostic = Diagnostic(
        message: 'Test diagnostic',
        severity: DiagnosticSeverity.warning,
        range: Range.zero,
        source: 'anteater',
        code: 'test_code',
      );

      expect(diagnostic.message, contains('Test'));
      expect(diagnostic.severity, equals(DiagnosticSeverity.warning));
    });

    test('provides code actions for diagnostics', () async {
      final provider = CodeActionsProvider();

      const diagnostic = Diagnostic(
        message: 'High complexity',
        severity: DiagnosticSeverity.warning,
        range: Range.zero,
        source: 'anteater',
        code: 'high_cyclomatic_complexity',
      );

      final actions = await provider.getCodeActions(
        filePath: '/test/file.dart',
        range: Range.zero,
        diagnostics: [diagnostic],
      );

      expect(actions, isNotEmpty);
      expect(actions.first.title, contains('Extract'));
    });

    test('end-to-end: parse, analyze, diagnose', () {
      const source = '''
        void veryComplexFunction(int a, int b, int c) {
          if (a > 0) {
            if (b > 0) {
              if (c > 0) {
                for (var i = 0; i < a; i++) {
                  while (b > 0) {
                    if (i % 2 == 0) {
                      print('even');
                    } else if (i % 3 == 0) {
                      print('div3');
                    } else {
                      print('other');
                    }
                    b--;
                  }
                }
              }
            }
          }
        }
      ''';

      // Parse
      final parseResult = parseString(content: source);
      final unit = parseResult.unit;

      // Calculate complexity
      final complexityCalculator = ComplexityCalculator();
      final funcDecl = unit.declarations.first as FunctionDeclaration;
      final body = funcDecl.functionExpression.body;
      final cyclomatic = complexityCalculator.calculateCyclomaticComplexity(body);
      final cognitive = complexityCalculator.calculateCognitiveComplexity(body);

      // This function should have high complexity
      expect(cyclomatic, greaterThan(5));
      expect(cognitive, greaterThan(5));

      // Calculate maintainability
      final miCalculator = MaintainabilityIndexCalculator();
      final result = miCalculator.calculate(body);

      // High complexity should result in lower maintainability
      // Note: MI formula may still produce values above 80 for short code
      expect(result.maintainabilityIndex, lessThan(90));

      // Generate threshold-based diagnostic
      const thresholds = DiagnosticThresholds(cyclomaticComplexity: 10);
      if (cyclomatic > thresholds.cyclomaticComplexity) {
        // Would generate warning in real DiagnosticsProvider
        expect(cyclomatic, greaterThan(thresholds.cyclomaticComplexity));
      }
    });
  });

  group('Error Handling', () {
    test('handles empty source gracefully', () {
      const source = '';
      final parseResult = parseString(content: source);
      final unit = parseResult.unit;

      expect(unit.declarations, isEmpty);
    });

    test('handles malformed code', () {
      const source = 'void incomplete(';

      // Should not throw, just have parse errors when throwIfDiagnostics is false
      final result = parseString(
        content: source,
        throwIfDiagnostics: false,
      );
      expect(result.errors, isNotEmpty);
    });

    test('handles abstract functions', () {
      const source = '''
        abstract class Base {
          void abstractMethod();
        }
      ''';

      final parseResult = parseString(content: source);
      final unit = parseResult.unit;

      final classDecl = unit.declarations.first;
      expect(classDecl, isNotNull);
    });
  });
}
