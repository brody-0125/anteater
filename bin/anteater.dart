import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:args/args.dart';
import 'package:anteater/debt/debt_aggregator.dart';
import 'package:anteater/debt/debt_config.dart';
import 'package:anteater/debt/debt_item.dart';
import 'package:anteater/frontend/source_loader.dart';
import 'package:anteater/metrics/maintainability_index.dart';
import 'package:anteater/metrics/metrics_aggregator.dart';
import 'package:anteater/neural/inference/onnx_ffi.dart';
import 'package:anteater/neural/inference/onnx_runtime.dart';
import 'package:anteater/server/language_server.dart';
import 'package:anteater/version.dart';
import 'package:dart_bert_tokenizer/dart_bert_tokenizer.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Anteater CLI - Deep Semantic Analysis Engine for Dart
void main(List<String> arguments) async {
  final analyzeParser = ArgParser()
    ..addOption('path', abbr: 'p', defaultsTo: '.', help: 'Path to analyze')
    ..addOption(
      'format',
      abbr: 'f',
      defaultsTo: 'text',
      allowed: ['text', 'json', 'html'],
      help: 'Output format',
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Output file path',
    )
    ..addFlag(
      'watch',
      abbr: 'w',
      help: 'Watch for file changes and re-analyze',
    )
    ..addFlag(
      'quiet',
      abbr: 'q',
      help: 'Suppress progress output',
    )
    ..addFlag(
      'no-fatal-infos',
      help: 'Do not treat info level issues as fatal',
    )
    ..addFlag(
      'no-fatal-warnings',
      help: 'Do not treat warning level issues as fatal',
    );

  final metricsParser = ArgParser()
    ..addOption('path', abbr: 'p', defaultsTo: '.', help: 'Path to analyze')
    ..addOption(
      'threshold-cc',
      help: 'Cyclomatic complexity threshold (overrides analysis_options.yaml)',
    )
    ..addOption(
      'threshold-mi',
      help: 'Maintainability index threshold (overrides analysis_options.yaml)',
    )
    ..addOption(
      'threshold-cognitive',
      help: 'Cognitive complexity threshold (overrides analysis_options.yaml)',
    )
    ..addOption(
      'threshold-loc',
      help: 'Lines of code threshold (overrides analysis_options.yaml)',
    )
    ..addFlag(
      'watch',
      abbr: 'w',
      help: 'Watch for file changes and re-analyze',
    )
    ..addFlag(
      'quiet',
      abbr: 'q',
      help: 'Suppress progress output',
    )
    ..addFlag(
      'no-fatal-infos',
      help: 'Do not treat info level issues as fatal',
    )
    ..addFlag(
      'no-fatal-warnings',
      help: 'Do not treat warning level issues as fatal',
    );

  final debtParser = ArgParser()
    ..addOption('path', abbr: 'p', defaultsTo: '.', help: 'Path to analyze')
    ..addOption(
      'format',
      abbr: 'f',
      defaultsTo: 'text',
      allowed: ['text', 'json', 'markdown'],
      help: 'Output format',
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Output file path',
    )
    ..addOption(
      'threshold',
      help: 'Cost threshold (overrides analysis_options.yaml)',
    )
    ..addFlag(
      'quiet',
      abbr: 'q',
      help: 'Suppress progress output',
    )
    ..addFlag(
      'fail-on-threshold',
      defaultsTo: true,
      help: 'Exit with code 1 if threshold exceeded',
    );

  final clonesParser = ArgParser()
    ..addOption('path', abbr: 'p', defaultsTo: '.', help: 'Path to analyze')
    ..addOption(
      'format',
      abbr: 'f',
      defaultsTo: 'text',
      allowed: ['text', 'json'],
      help: 'Output format',
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Output file path',
    )
    ..addOption(
      'threshold',
      abbr: 't',
      defaultsTo: '0.85',
      help: 'Similarity threshold (0.0-1.0)',
    )
    ..addOption(
      'model',
      abbr: 'm',
      defaultsTo: 'model/model.onnx',
      help: 'Path to ONNX model file',
    )
    ..addOption(
      'vocab',
      abbr: 'V',
      defaultsTo: 'model/vocab.txt',
      help: 'Path to vocabulary file',
    )
    ..addFlag(
      'quiet',
      abbr: 'q',
      help: 'Suppress progress output',
    );

  // Main parser with subcommands attached
  final parser = ArgParser()
    ..addCommand('analyze', analyzeParser)
    ..addCommand('metrics', metricsParser)
    ..addCommand('debt', debtParser)
    ..addCommand('clones', clonesParser)
    ..addCommand('server')
    ..addFlag('help', abbr: 'h', help: 'Show this help message')
    ..addFlag('version', abbr: 'v', help: 'Show version');

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool) {
      _printUsage(parser);
      return;
    }

    if (results['version'] as bool) {
      print('Anteater v$version');
      return;
    }

    if (results.command == null) {
      _printUsage(parser);
      exit(1);
    }

    switch (results.command!.name) {
      case 'analyze':
        await _runAnalyze(results.command!);
        break;
      case 'metrics':
        await _runMetrics(results.command!);
        break;
      case 'debt':
        await _runDebt(results.command!);
        break;
      case 'clones':
        await _runClones(results.command!);
        break;
      case 'server':
        await _runServer();
        break;
      default:
        _printUsage(parser);
        exit(1);
    }
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    _printUsage(parser);
    exit(64); // EX_USAGE - command line usage error
  }
}

void _printUsage(ArgParser parser) {
  print('''
Anteater - Deep Semantic Analysis Engine for Dart

Usage: anteater <command> [options]

Commands:
  analyze   Analyze Dart code for issues
            Options: -p/--path, -f/--format (text|json|html), -o/--output,
                     -w/--watch, --no-fatal-infos, --no-fatal-warnings

  metrics   Calculate code metrics
            Options: -p/--path, --threshold-cc, --threshold-mi,
                     --threshold-cognitive, --threshold-loc,
                     -w/--watch, --no-fatal-warnings

  debt      Analyze technical debt and calculate cost
            Options: -p/--path, -f/--format (text|json|markdown), -o/--output,
                     --threshold, --fail-on-threshold

  clones    Detect semantic code clones using neural analysis
            Options: -p/--path, -f/--format (text|json), -o/--output,
                     -t/--threshold (0.0-1.0), -m/--model, -V/--vocab
            Requires: ONNX Runtime (brew install onnxruntime)
                      Model files in model/ directory

  server    Start the language server (LSP mode)

Global Options:
${parser.usage}

Exit Codes:
  0   Success (no issues above threshold)
  1   Issues found above threshold
  64  Command line usage error
  66  Path not found
''');
}

Future<void> _runAnalyze(ArgResults args) async {
  final path = args['path'] as String;
  final format = args['format'] as String;
  final output = args['output'] as String?;
  final watch = args['watch'] as bool;
  final quiet = args['quiet'] as bool;
  final noFatalInfos = args['no-fatal-infos'] as bool;
  final noFatalWarnings = args['no-fatal-warnings'] as bool;

  // Validate path exists
  if (!Directory(path).existsSync() && !File(path).existsSync()) {
    stderr.writeln('Error: Path not found: $path');
    exit(66); // EX_NOINPUT
  }

  Future<int> runOnce() async {
    if (!quiet) print('Analyzing $path...\n');

    final server = AnteaterLanguageServer(path);
    await server.initialize();

    final result = await server.analyzeProject();

    final report = _formatResult(result, format);

    if (output != null) {
      await File(output).writeAsString(report);
      print('Report written to $output');
    } else {
      print(report);
    }

    await server.shutdown();

    // Determine exit code based on fatal flags
    if (result.errorCount > 0) {
      return 1;
    }
    if (!noFatalWarnings && result.warningCount > 0) {
      return 1;
    }
    if (!noFatalInfos && result.infoCount > 0) {
      return 1;
    }
    return 0;
  }

  if (watch) {
    await _runWithWatch(path, runOnce);
  } else {
    final exitCode = await runOnce();
    if (exitCode != 0) {
      exit(exitCode);
    }
  }
}

String _formatResult(ProjectAnalysisResult result, String format) {
  switch (format) {
    case 'json':
      return _formatJson(result);
    case 'html':
      return _formatHtml(result);
    default:
      return _formatText(result);
  }
}

String _formatText(ProjectAnalysisResult result) {
  final buffer = StringBuffer();

  buffer.writeln('Analysis Results');
  buffer.writeln('=' * 50);
  buffer.writeln('Files analyzed: ${result.fileCount}');
  buffer.writeln('Total issues: ${result.totalDiagnostics}');
  buffer.writeln('  Errors: ${result.errorCount}');
  buffer.writeln('  Warnings: ${result.warningCount}');
  buffer.writeln('  Info: ${result.infoCount}');
  buffer.writeln();

  for (final entry in result.diagnostics.entries) {
    if (entry.value.isEmpty) continue;

    buffer.writeln('${entry.key}:');
    for (final diag in entry.value) {
      buffer.writeln('  $diag');
    }
    buffer.writeln();
  }

  return buffer.toString();
}

String _formatJson(ProjectAnalysisResult result) {
  final data = {
    'fileCount': result.fileCount,
    'totalDiagnostics': result.totalDiagnostics,
    'errorCount': result.errorCount,
    'warningCount': result.warningCount,
    'infoCount': result.infoCount,
    'files': Map.fromEntries(
      result.diagnostics.entries.map(
        (entry) => MapEntry(
          entry.key,
          entry.value.map((d) => d.toJson()).toList(),
        ),
      ),
    ),
  };
  return const JsonEncoder.withIndent('  ').convert(data);
}

String _formatHtml(ProjectAnalysisResult result) {
  return '''
<!DOCTYPE html>
<html>
<head>
  <title>Anteater Analysis Report</title>
  <style>
    body { font-family: sans-serif; margin: 20px; }
    .summary { background: #f0f0f0; padding: 10px; margin-bottom: 20px; }
    .error { color: red; }
    .warning { color: orange; }
    .file { margin-bottom: 15px; }
    .file-name { font-weight: bold; }
  </style>
</head>
<body>
  <h1>Anteater Analysis Report</h1>
  <div class="summary">
    <p>Files: ${result.fileCount}</p>
    <p>Issues: ${result.totalDiagnostics}</p>
    <p class="error">Errors: ${result.errorCount}</p>
    <p class="warning">Warnings: ${result.warningCount}</p>
  </div>
  ${result.diagnostics.entries.where((e) => e.value.isNotEmpty).map((e) => '''
  <div class="file">
    <div class="file-name">${e.key}</div>
    <ul>
      ${e.value.map((d) => '<li class="${d.severity.name}">${d.message}</li>').join('\n')}
    </ul>
  </div>
  ''').join('\n')}
</body>
</html>
''';
}

Future<void> _runMetrics(ArgResults args) async {
  final path = args['path'] as String;
  final watch = args['watch'] as bool;
  final quiet = args['quiet'] as bool;
  final noFatalWarnings = args['no-fatal-warnings'] as bool;

  // Validate path exists
  if (!Directory(path).existsSync() && !File(path).existsSync()) {
    stderr.writeln('Error: Path not found: $path');
    exit(66); // EX_NOINPUT
  }

  // Load thresholds from analysis_options.yaml, then override with CLI args
  final options = _loadAnalysisOptions(path);
  final ccThreshold = args['threshold-cc'] != null
      ? int.parse(args['threshold-cc'] as String)
      : options.maxCyclomatic;
  final miThreshold = args['threshold-mi'] != null
      ? double.parse(args['threshold-mi'] as String)
      : options.minMaintainability;
  final cognitiveThreshold = args['threshold-cognitive'] != null
      ? int.parse(args['threshold-cognitive'] as String)
      : options.maxCognitive;
  final locThreshold = args['threshold-loc'] != null
      ? int.parse(args['threshold-loc'] as String)
      : options.maxLinesOfCode;

  Future<int> runOnce() async {
    if (!quiet) {
      print('Calculating metrics for $path...\n');
      print('Thresholds: CC > $ccThreshold, MI < $miThreshold, '
          'Cognitive > $cognitiveThreshold, LOC > $locThreshold\n');
    }

    final sourceLoader = SourceLoader(path);
    final aggregator = MetricsAggregator(
      thresholds: MetricsThresholds(
        maxCyclomatic: ccThreshold,
        minMaintainability: miThreshold,
        maxCognitive: cognitiveThreshold,
        maxLinesOfCode: locThreshold,
      ),
    );

    final files = sourceLoader.discoverDartFiles();
    var processed = 0;

    for (final file in files) {
      final result = await sourceLoader.resolveFile(file);
      if (result == null) continue;

      aggregator.addFile(file, result.unit);
      processed++;

      // Progress indicator
      if (!quiet) stdout.write('\rProcessing: $processed/${files.length}');
    }
    if (!quiet) print('\n');

    final report = aggregator.generateReport();
    print(report);

    await sourceLoader.dispose();

    // Determine exit code based on fatal flags and violations
    if (report.hasViolations) {
      // For now, treat all violations as warnings unless we have severity info
      if (!noFatalWarnings) {
        return 1;
      }
    }
    return 0;
  }

  if (watch) {
    await _runWithWatch(path, runOnce);
  } else {
    final exitCode = await runOnce();
    if (exitCode != 0) {
      exit(exitCode);
    }
  }
}

Future<void> _runDebt(ArgResults args) async {
  final path = args['path'] as String;
  final format = args['format'] as String;
  final output = args['output'] as String?;
  final quiet = args['quiet'] as bool;
  final failOnThreshold = args['fail-on-threshold'] as bool;

  // Validate path exists
  if (!Directory(path).existsSync() && !File(path).existsSync()) {
    stderr.writeln('Error: Path not found: $path');
    exit(66); // EX_NOINPUT
  }

  // Load configuration
  final debtOptions = _loadDebtOptions(path);
  final threshold = args['threshold'] != null
      ? double.parse(args['threshold'] as String)
      : debtOptions.threshold;

  final config = DebtCostConfig(
    costs: debtOptions.costs,
    multipliers: debtOptions.multipliers,
    unit: debtOptions.unit,
    threshold: threshold,
    metricsThresholds: debtOptions.metricsThresholds,
    exclude: debtOptions.exclude,
  );

  if (!quiet) {
    print('Analyzing technical debt in $path...\n');
    print('Threshold: $threshold ${config.unit}\n');
  }

  final sourceLoader = SourceLoader(path);
  final aggregator = DebtAggregator(config: config);
  final miCalculator = MaintainabilityIndexCalculator();

  try {
    final files = sourceLoader.discoverDartFiles();
    var processed = 0;

    for (final file in files) {
      // Check exclusions
      if (_isExcluded(file, config.exclude)) continue;

      final result = await sourceLoader.resolveFile(file);
      if (result == null) continue;

      final metrics = miCalculator.calculateForFile(result.unit);
      aggregator.addFile(
        file,
        result.unit,
        lineInfo: result.lineInfo,
        metrics: metrics,
      );
      processed++;

      if (!quiet) stdout.write('\rProcessing: $processed/${files.length}');
    }
    if (!quiet) print('\n');

    final report = aggregator.generateReport();

    // Format output
    final reportOutput = switch (format) {
      'json' => const JsonEncoder.withIndent('  ').convert(report.toJson()),
      'markdown' => report.toMarkdown(),
      _ => report.toConsole(),
    };

    if (output != null) {
      await File(output).writeAsString(reportOutput);
      print('Report written to $output');
    } else {
      print(reportOutput);
    }

    // Exit code based on threshold
    if (failOnThreshold && report.summary.exceedsThreshold) {
      exit(1);
    }
  } finally {
    await sourceLoader.dispose();
  }
}

Future<void> _runClones(ArgResults args) async {
  final path = args['path'] as String;
  final format = args['format'] as String;
  final output = args['output'] as String?;
  final threshold = double.parse(args['threshold'] as String);
  final quiet = args['quiet'] as bool;

  // Validate path exists
  if (!Directory(path).existsSync() && !File(path).existsSync()) {
    stderr.writeln('Error: Path not found: $path');
    exit(66); // EX_NOINPUT
  }

  // Resolve model and vocab paths with fallback locations
  final modelPath = _resolveModelPath(
    args['model'] as String,
    'model.onnx',
  );
  final vocabPath = _resolveModelPath(
    args['vocab'] as String,
    'vocab.txt',
  );

  // Check if model and vocab files exist
  if (modelPath == null) {
    stderr.writeln('Error: Model file not found.');
    stderr.writeln('');
    stderr.writeln('Searched locations:');
    stderr.writeln('  - ./model/model.onnx (current directory)');
    stderr.writeln('  - ~/.anteater/model.onnx (home directory)');
    stderr.writeln('');
    stderr.writeln('To set up neural analysis:');
    stderr.writeln('  1. Install ONNX Runtime: brew install onnxruntime');
    stderr.writeln('  2. Download model files to ~/.anteater/:');
    stderr.writeln('     mkdir -p ~/.anteater');
    stderr.writeln('     curl -L -o ~/.anteater/model.onnx https://huggingface.co/'
        'michael-sigamani/nomic-embed-text-onnx/resolve/main/model.onnx');
    stderr.writeln('     curl -L -o ~/.anteater/vocab.txt https://huggingface.co/'
        'nomic-ai/nomic-embed-text-v1/resolve/main/vocab.txt');
    stderr.writeln('');
    stderr.writeln('  Or specify custom paths with --model and --vocab options.');
    exit(66);
  }

  if (vocabPath == null) {
    stderr.writeln('Error: Vocabulary file not found.');
    stderr.writeln('');
    stderr.writeln('Searched locations:');
    stderr.writeln('  - ./model/vocab.txt (current directory)');
    stderr.writeln('  - ~/.anteater/vocab.txt (home directory)');
    exit(66);
  }

  // Try to load ONNX Runtime
  final onnxFfi = OnnxFfi.tryLoadDefault();
  if (onnxFfi == null) {
    stderr.writeln('Error: ONNX Runtime library not found.');
    stderr.writeln('');
    stderr.writeln('Install ONNX Runtime:');
    stderr.writeln('  macOS:  brew install onnxruntime');
    stderr.writeln('  Linux:  apt install libonnxruntime-dev');
    stderr.writeln('  Or download from: https://github.com/'
        'microsoft/onnxruntime/releases');
    exit(1);
  }

  if (!quiet) {
    print('Detecting semantic clones in $path...');
    print('Model: $modelPath');
    print('Threshold: ${(threshold * 100).toStringAsFixed(0)}%\n');
  }

  // Load tokenizer
  final tokenizer = WordPieceTokenizer.fromVocabFileSync(vocabPath);

  // Load runtime and detector
  final runtime = NativeOnnxRuntime();
  final sourceLoader = SourceLoader(path);

  try {
    await runtime.loadModel(modelPath);

    final detector = SemanticCloneDetector(
      runtime: runtime,
      tokenizer: tokenizer,
      similarityThreshold: threshold,
    );

    // Discover and analyze functions
    final files = sourceLoader.discoverDartFiles();
    final functions = <_FunctionInfo>[];

    var processed = 0;
    for (final file in files) {
      final result = await sourceLoader.resolveFile(file);
      if (result == null) continue;

      // Extract functions from the file
      final visitor = _FunctionExtractor(file);
      result.unit.visitChildren(visitor);
      functions.addAll(visitor.functions);

      processed++;
      if (!quiet) stdout.write('\rIndexing: $processed/${files.length}');
    }
    if (!quiet) print('\n');

    // Index all functions
    if (!quiet) print('Indexing ${functions.length} functions...');
    for (final func in functions) {
      await detector.indexFunction(func.id, func.code);
    }

    // Find clones
    if (!quiet) print('Finding clones...\n');
    final clones = <_ClonePair>[];

    for (var i = 0; i < functions.length; i++) {
      final func = functions[i];
      final candidates = await detector.findClones(func.id, func.code);

      for (final candidate in candidates) {
        // Avoid duplicate pairs (only report A->B, not B->A)
        if (func.id.compareTo(candidate.functionId) < 0) {
          final other =
              functions.firstWhere((f) => f.id == candidate.functionId);
          clones.add(_ClonePair(
            source: func,
            target: other,
            similarity: candidate.similarity,
          ));
        }
      }

      if (!quiet) {
        stdout.write('\rAnalyzing: ${i + 1}/${functions.length}');
      }
    }
    if (!quiet) print('\n');

    // Format output
    final reportOutput = switch (format) {
      'json' => _formatClonesJson(clones),
      _ => _formatClonesText(clones, threshold),
    };

    if (output != null) {
      await File(output).writeAsString(reportOutput);
      print('Report written to $output');
    } else {
      print(reportOutput);
    }
  } finally {
    runtime.dispose();
    await sourceLoader.dispose();
  }
}

String _formatClonesText(List<_ClonePair> clones, double threshold) {
  if (clones.isEmpty) {
    return 'No semantic clones found above ${(threshold * 100).toStringAsFixed(0)}% threshold.';
  }

  final buffer = StringBuffer();
  buffer.writeln('Semantic Clone Detection Results');
  buffer.writeln('=' * 50);
  buffer.writeln('Found ${clones.length} clone pair(s)\n');

  // Sort by similarity descending
  clones.sort((a, b) => b.similarity.compareTo(a.similarity));

  for (final clone in clones) {
    buffer.writeln('${(clone.similarity * 100).toStringAsFixed(1)}% similar:');
    buffer.writeln('  ${clone.source.file}:${clone.source.line}');
    buffer.writeln('    ${clone.source.name}');
    buffer.writeln('  ${clone.target.file}:${clone.target.line}');
    buffer.writeln('    ${clone.target.name}');
    buffer.writeln();
  }

  return buffer.toString();
}

String _formatClonesJson(List<_ClonePair> clones) {
  final data = {
    'cloneCount': clones.length,
    'clones': clones.map((c) => {
      'similarity': c.similarity,
      'source': {
        'file': c.source.file,
        'line': c.source.line,
        'name': c.source.name,
      },
      'target': {
        'file': c.target.file,
        'line': c.target.line,
        'name': c.target.name,
      },
    }).toList(),
  };
  return const JsonEncoder.withIndent('  ').convert(data);
}

class _FunctionInfo {
  _FunctionInfo({
    required this.id,
    required this.name,
    required this.file,
    required this.line,
    required this.code,
  });

  final String id;
  final String name;
  final String file;
  final int line;
  final String code;
}

class _ClonePair {
  _ClonePair({
    required this.source,
    required this.target,
    required this.similarity,
  });

  final _FunctionInfo source;
  final _FunctionInfo target;
  final double similarity;
}

class _FunctionExtractor extends RecursiveAstVisitor<void> {
  _FunctionExtractor(this.file);

  final String file;
  final List<_FunctionInfo> functions = [];

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final name = node.name.lexeme;
    final line = node.offset; // Approximate, would need LineInfo for exact
    final code = node.toSource();
    final id = '$file:$name:$line';

    functions.add(_FunctionInfo(
      id: id,
      name: name,
      file: file,
      line: line,
      code: code,
    ));

    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final name = node.name.lexeme;
    final line = node.offset;
    final code = node.toSource();
    final id = '$file:$name:$line';

    functions.add(_FunctionInfo(
      id: id,
      name: name,
      file: file,
      line: line,
      code: code,
    ));

    super.visitMethodDeclaration(node);
  }
}

bool _isExcluded(String filePath, List<String> patterns) {
  for (final pattern in patterns) {
    if (pattern.contains('*')) {
      // Convert glob to regex
      final regexPattern = pattern
          .replaceAll('.', r'\.')
          .replaceAll('**', '.*')
          .replaceAll('*', '[^/]*');
      if (RegExp(regexPattern).hasMatch(filePath)) {
        return true;
      }
    } else if (filePath.contains(pattern)) {
      return true;
    }
  }
  return false;
}

/// Loads debt configuration from analysis_options.yaml.
_DebtOptionsConfig _loadDebtOptions(String projectPath) {
  final optionsFile = File(p.join(projectPath, 'analysis_options.yaml'));

  if (!optionsFile.existsSync()) {
    return _DebtOptionsConfig.defaults();
  }

  try {
    final content = optionsFile.readAsStringSync();
    final yaml = loadYaml(content) as YamlMap?;

    if (yaml == null) {
      return _DebtOptionsConfig.defaults();
    }

    final anteaterConfig = yaml['anteater'] as YamlMap?;
    if (anteaterConfig == null) {
      return _DebtOptionsConfig.defaults();
    }

    final debtConfig = anteaterConfig['technical-debt'] as YamlMap?;
    if (debtConfig == null) {
      return _DebtOptionsConfig.defaults();
    }

    return _DebtOptionsConfig.fromYaml(debtConfig);
  } catch (e) {
    stderr.writeln('Warning: Failed to parse analysis_options.yaml: $e');
    return _DebtOptionsConfig.defaults();
  }
}

class _DebtOptionsConfig {
  _DebtOptionsConfig({
    required this.costs,
    required this.multipliers,
    required this.unit,
    required this.threshold,
    required this.metricsThresholds,
    required this.exclude,
  });

  factory _DebtOptionsConfig.defaults() {
    final defaultConfig = DebtCostConfig.defaults();
    return _DebtOptionsConfig(
      costs: defaultConfig.costs,
      multipliers: defaultConfig.multipliers,
      unit: defaultConfig.unit,
      threshold: defaultConfig.threshold,
      metricsThresholds: defaultConfig.metricsThresholds,
      exclude: defaultConfig.exclude,
    );
  }

  factory _DebtOptionsConfig.fromYaml(YamlMap yaml) {
    final defaults = _DebtOptionsConfig.defaults();

    // Parse costs
    final costsYaml = yaml['costs'] as YamlMap?;
    final costs = Map<DebtType, double>.from(defaults.costs);
    if (costsYaml != null) {
      for (final entry in costsYaml.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        final debtType = _parseDebtType(key);
        if (debtType != null && value is num) {
          costs[debtType] = value.toDouble();
        }
      }
    }

    // Parse exclude
    final excludeYaml = yaml['exclude'] as YamlList?;
    final exclude = excludeYaml?.map((e) => e.toString()).toList() ?? defaults.exclude;

    // Parse metrics thresholds
    final metricsYaml = yaml['metrics'] as YamlMap?;
    final metricsThresholds = metricsYaml != null
        ? DebtMetricsThresholds(
            maintainabilityIndex:
                (metricsYaml['maintainability-index'] as num?)?.toDouble() ?? 50.0,
            cyclomaticComplexity:
                metricsYaml['cyclomatic-complexity'] as int? ?? 20,
            cognitiveComplexity:
                metricsYaml['cognitive-complexity'] as int? ?? 15,
            linesOfCode: metricsYaml['lines-of-code'] as int? ?? 100,
          )
        : defaults.metricsThresholds;

    return _DebtOptionsConfig(
      costs: costs,
      multipliers: defaults.multipliers,
      unit: yaml['unit'] as String? ?? defaults.unit,
      threshold: (yaml['threshold'] as num?)?.toDouble() ?? defaults.threshold,
      metricsThresholds: metricsThresholds,
      exclude: exclude,
    );
  }

  final Map<DebtType, double> costs;
  final Map<DebtSeverity, double> multipliers;
  final String unit;
  final double threshold;
  final DebtMetricsThresholds metricsThresholds;
  final List<String> exclude;

  static DebtType? _parseDebtType(String key) {
    final normalized = key.replaceAll('-', '').toLowerCase();
    for (final type in DebtType.values) {
      if (type.name.toLowerCase() == normalized) return type;
    }
    return switch (normalized) {
      'ignore' => DebtType.ignoreComment,
      'ignoreforfile' => DebtType.ignoreForFile,
      'asdynamic' => DebtType.asDynamic,
      'lowmaintainability' => DebtType.lowMaintainability,
      'highcomplexity' => DebtType.highComplexity,
      'longmethod' => DebtType.longMethod,
      'duplicatecode' => DebtType.duplicateCode,
      _ => null,
    };
  }
}

/// Watches for file changes and re-runs the analysis.
Future<void> _runWithWatch(String path, Future<int> Function() runOnce) async {
  final directory = Directory(path);
  if (!directory.existsSync()) {
    stderr.writeln('Error: Directory not found: $path');
    exit(1);
  }

  // Initial run
  await runOnce();

  print('\nWatching for changes... (Press Ctrl+C to stop)\n');

  // Watch for file changes
  final watcher = directory.watch(recursive: true);
  DateTime? lastRun;
  const debounce = Duration(milliseconds: 500);

  await for (final event in watcher) {
    // Only process .dart file changes
    if (!event.path.endsWith('.dart')) continue;

    // Debounce rapid changes
    final now = DateTime.now();
    if (lastRun != null && now.difference(lastRun) < debounce) {
      continue;
    }
    lastRun = now;

    print('\n${'=' * 50}');
    print('File changed: ${p.basename(event.path)}');
    print('${'=' * 50}\n');

    await runOnce();

    print('\nWatching for changes... (Press Ctrl+C to stop)\n');
  }
}

/// Configuration loaded from analysis_options.yaml
class _AnalysisOptionsConfig {
  _AnalysisOptionsConfig({
    this.maxCyclomatic = 20,
    this.minMaintainability = 50.0,
    this.maxCognitive = 15,
    this.maxLinesOfCode = 100,
  });

  final int maxCyclomatic;
  final double minMaintainability;
  final int maxCognitive;
  final int maxLinesOfCode;
}

/// Loads analysis options from analysis_options.yaml if present.
_AnalysisOptionsConfig _loadAnalysisOptions(String projectPath) {
  final optionsFile = File(p.join(projectPath, 'analysis_options.yaml'));

  if (!optionsFile.existsSync()) {
    return _AnalysisOptionsConfig();
  }

  try {
    final content = optionsFile.readAsStringSync();
    final yaml = loadYaml(content) as YamlMap?;

    if (yaml == null) {
      return _AnalysisOptionsConfig();
    }

    // Look for anteater-specific configuration
    final anteaterConfig = yaml['anteater'] as YamlMap?;
    if (anteaterConfig == null) {
      return _AnalysisOptionsConfig();
    }

    final metrics = anteaterConfig['metrics'] as YamlMap?;
    if (metrics == null) {
      return _AnalysisOptionsConfig();
    }

    return _AnalysisOptionsConfig(
      maxCyclomatic: (metrics['cyclomatic-complexity'] as int?) ?? 20,
      minMaintainability:
          (metrics['maintainability-index'] as num?)?.toDouble() ?? 50.0,
      maxCognitive: (metrics['cognitive-complexity'] as int?) ?? 15,
      maxLinesOfCode: (metrics['lines-of-code'] as int?) ?? 100,
    );
  } catch (e) {
    stderr.writeln('Warning: Failed to parse analysis_options.yaml: $e');
    return _AnalysisOptionsConfig();
  }
}

Future<void> _runServer() async {
  print('Starting Anteater Language Server...');
  print('Listening on stdin/stdout (LSP mode)');

  // TODO: Implement full LSP server
  // For now, just keep the process running
  await ProcessSignal.sigint.watch().first;
  print('\nShutting down...');
}

/// Resolves model file path with fallback locations.
///
/// Search order:
/// 1. If [cliPath] is not the default, use it as-is (user specified)
/// 2. Current working directory: ./model/[filename]
/// 3. User home directory: ~/.anteater/[filename]
///
/// Returns null if file not found in any location.
String? _resolveModelPath(String cliPath, String filename) {
  // Check if user specified a custom path (not the default)
  final defaultPath = 'model/$filename';
  if (cliPath != defaultPath) {
    // User specified a custom path, use it directly
    if (File(cliPath).existsSync()) {
      return cliPath;
    }
    return null;
  }

  // Search in default locations
  final searchPaths = [
    // Current working directory
    'model/$filename',
    // User home directory
    _getHomePath('.anteater/$filename'),
  ];

  for (final path in searchPaths) {
    if (path != null && File(path).existsSync()) {
      return path;
    }
  }

  return null;
}

/// Returns path relative to user's home directory.
String? _getHomePath(String relativePath) {
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'];
  if (home == null) return null;
  return p.join(home, relativePath);
}
