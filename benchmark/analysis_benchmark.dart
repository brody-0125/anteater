import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'package:anteater/ir/cfg/cfg_builder.dart';
import 'package:anteater/ir/ssa/ssa_builder.dart';
import 'package:anteater/reasoner/datalog/fact_extractor.dart';
import 'package:anteater/reasoner/datalog/datalog_engine.dart';
import 'package:anteater/metrics/complexity_calculator.dart';
import 'package:anteater/metrics/maintainability_index.dart';
import 'package:anteater/metrics/metrics_aggregator.dart';

/// Benchmark runner for Anteater analysis pipeline
void main(List<String> args) async {
  print('Anteater Performance Benchmarks');
  print('=' * 50);
  print('');

  final iterations = args.isNotEmpty ? int.tryParse(args[0]) ?? 100 : 100;
  print('Running $iterations iterations per benchmark\n');

  await runBenchmarks(iterations);
}

Future<void> runBenchmarks(int iterations) async {
  // Generate sample code for benchmarking
  final simpleCode = _generateSimpleFunction();
  final complexCode = _generateComplexFunction();
  final largeFile = _generateLargeFile(50);

  print('Benchmark: Parse Simple Function');
  benchmarkParsing(simpleCode, iterations, 'simple');

  print('\nBenchmark: Parse Complex Function');
  benchmarkParsing(complexCode, iterations, 'complex');

  print('\nBenchmark: Parse Large File (50 functions)');
  benchmarkParsing(largeFile, iterations ~/ 10, 'large_file');

  print('\nBenchmark: CFG Building');
  benchmarkCfgBuilding(complexCode, iterations, 'complex');

  print('\nBenchmark: SSA Transformation');
  benchmarkSsaBuilding(complexCode, iterations, 'complex');

  print('\nBenchmark: Datalog Fact Extraction');
  benchmarkFactExtraction(complexCode, iterations, 'complex');

  print('\nBenchmark: Datalog Engine Run');
  benchmarkDatalogEngine(complexCode, iterations, 'complex');

  print('\nBenchmark: Complexity Calculation');
  benchmarkComplexity(complexCode, iterations, 'complex');

  print('\nBenchmark: Maintainability Index');
  benchmarkMaintainability(complexCode, iterations, 'complex');

  print('\nBenchmark: Full Pipeline');
  benchmarkFullPipeline(complexCode, iterations ~/ 10, 'complex');

  print('\nBenchmark: Metrics Aggregation (50 files)');
  await benchmarkAggregation(50, iterations ~/ 10);

  print('\n' + '=' * 50);
  print('Benchmarks completed');
}

void benchmarkParsing(String code, int iterations, String label) {
  final stopwatch = Stopwatch()..start();

  for (var i = 0; i < iterations; i++) {
    parseString(content: code);
  }

  stopwatch.stop();
  _printResult(label, stopwatch.elapsedMicroseconds, iterations);
}

void benchmarkCfgBuilding(String code, int iterations, String label) {
  final unit = parseString(content: code).unit;
  final funcDecl = unit.declarations.first as FunctionDeclaration;
  final cfgBuilder = CfgBuilder();

  final stopwatch = Stopwatch()..start();

  for (var i = 0; i < iterations; i++) {
    cfgBuilder.buildFromFunction(funcDecl);
  }

  stopwatch.stop();
  _printResult(label, stopwatch.elapsedMicroseconds, iterations);
}

void benchmarkSsaBuilding(String code, int iterations, String label) {
  final unit = parseString(content: code).unit;
  final funcDecl = unit.declarations.first as FunctionDeclaration;
  final cfgBuilder = CfgBuilder();
  final cfg = cfgBuilder.buildFromFunction(funcDecl);
  final ssaBuilder = SsaBuilder();

  final stopwatch = Stopwatch()..start();

  for (var i = 0; i < iterations; i++) {
    ssaBuilder.buildSsa(cfg);
  }

  stopwatch.stop();
  _printResult(label, stopwatch.elapsedMicroseconds, iterations);
}

void benchmarkFactExtraction(String code, int iterations, String label) {
  final unit = parseString(content: code).unit;
  final funcDecl = unit.declarations.first as FunctionDeclaration;
  final cfgBuilder = CfgBuilder();
  final cfg = cfgBuilder.buildFromFunction(funcDecl);
  final factExtractor = FactExtractor();

  final stopwatch = Stopwatch()..start();

  for (var i = 0; i < iterations; i++) {
    factExtractor.extractFromCfg(cfg);
  }

  stopwatch.stop();
  _printResult(label, stopwatch.elapsedMicroseconds, iterations);
}

void benchmarkDatalogEngine(String code, int iterations, String label) {
  final unit = parseString(content: code).unit;
  final funcDecl = unit.declarations.first as FunctionDeclaration;
  final cfgBuilder = CfgBuilder();
  final cfg = cfgBuilder.buildFromFunction(funcDecl);
  final factExtractor = FactExtractor();
  final facts = factExtractor.extractFromCfg(cfg);

  final stopwatch = Stopwatch()..start();

  for (var i = 0; i < iterations; i++) {
    final engine = InMemoryDatalogEngine();
    engine.loadFacts(facts);
    engine.run();
  }

  stopwatch.stop();
  _printResult(label, stopwatch.elapsedMicroseconds, iterations);
}

void benchmarkComplexity(String code, int iterations, String label) {
  final unit = parseString(content: code).unit;
  final funcDecl = unit.declarations.first as FunctionDeclaration;
  final body = funcDecl.functionExpression.body;
  final calculator = ComplexityCalculator();

  final stopwatch = Stopwatch()..start();

  for (var i = 0; i < iterations; i++) {
    calculator.calculateCyclomaticComplexity(body);
    calculator.calculateCognitiveComplexity(body);
    calculator.calculateHalsteadMetrics(body);
  }

  stopwatch.stop();
  _printResult(label, stopwatch.elapsedMicroseconds, iterations);
}

void benchmarkMaintainability(String code, int iterations, String label) {
  final unit = parseString(content: code).unit;
  final funcDecl = unit.declarations.first as FunctionDeclaration;
  final body = funcDecl.functionExpression.body;
  final calculator = MaintainabilityIndexCalculator();

  final stopwatch = Stopwatch()..start();

  for (var i = 0; i < iterations; i++) {
    calculator.calculate(body);
  }

  stopwatch.stop();
  _printResult(label, stopwatch.elapsedMicroseconds, iterations);
}

void benchmarkFullPipeline(String code, int iterations, String label) {
  final stopwatch = Stopwatch()..start();

  for (var i = 0; i < iterations; i++) {
    // Parse
    final unit = parseString(content: code).unit;
    final funcDecl = unit.declarations.first as FunctionDeclaration;

    // Build CFG
    final cfgBuilder = CfgBuilder();
    final cfg = cfgBuilder.buildFromFunction(funcDecl);

    // Build SSA
    final ssaBuilder = SsaBuilder();
    ssaBuilder.buildSsa(cfg);

    // Extract facts
    final factExtractor = FactExtractor();
    final facts = factExtractor.extractFromCfg(cfg);

    // Run Datalog
    final engine = InMemoryDatalogEngine();
    engine.loadFacts(facts);
    engine.run();

    // Calculate metrics
    final body = funcDecl.functionExpression.body;
    final complexity = ComplexityCalculator();
    complexity.calculateCyclomaticComplexity(body);
    complexity.calculateCognitiveComplexity(body);

    final mi = MaintainabilityIndexCalculator();
    mi.calculate(body);
  }

  stopwatch.stop();
  _printResult(label, stopwatch.elapsedMicroseconds, iterations);
}

Future<void> benchmarkAggregation(int fileCount, int iterations) async {
  final files = List.generate(fileCount, (i) => _generateSimpleFunction());
  final units = files.map((f) => parseString(content: f).unit).toList();

  final stopwatch = Stopwatch()..start();

  for (var i = 0; i < iterations; i++) {
    final aggregator = MetricsAggregator();
    for (var j = 0; j < units.length; j++) {
      aggregator.addFile('/test/file$j.dart', units[j]);
    }
    aggregator.getProjectMetrics();
    aggregator.generateReport();
  }

  stopwatch.stop();
  _printResult('$fileCount files', stopwatch.elapsedMicroseconds, iterations);
}

void _printResult(String label, int microseconds, int iterations) {
  final avgMicros = microseconds / iterations;
  final avgMillis = avgMicros / 1000;
  final opsPerSec = 1000000 / avgMicros;

  print('  [$label] avg: ${avgMillis.toStringAsFixed(3)}ms '
      '(${opsPerSec.toStringAsFixed(1)} ops/sec)');
}

String _generateSimpleFunction() {
  return '''
void simpleFunction() {
  var x = 1;
  var y = 2;
  var z = x + y;
  print(z);
}
''';
}

String _generateComplexFunction() {
  return '''
int complexFunction(int n, int m) {
  var result = 0;
  for (var i = 0; i < n; i++) {
    if (i % 2 == 0) {
      result += i;
      for (var j = 0; j < m; j++) {
        if (j > i) {
          result += j * 2;
        } else {
          result -= j;
        }
      }
    } else if (i % 3 == 0) {
      result *= 2;
      while (result > 100) {
        result ~/= 2;
      }
    } else {
      switch (i % 5) {
        case 0:
          result += 10;
          break;
        case 1:
          result -= 5;
          break;
        default:
          result++;
      }
    }
  }
  return result;
}
''';
}

String _generateLargeFile(int functionCount) {
  final buffer = StringBuffer();
  for (var i = 0; i < functionCount; i++) {
    buffer.writeln('''
int function$i(int x) {
  var result = x;
  for (var j = 0; j < x; j++) {
    if (j % 2 == 0) {
      result += j;
    } else {
      result -= j;
    }
  }
  return result;
}
''');
  }
  return buffer.toString();
}
