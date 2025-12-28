import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:anteater/server/language_server.dart';
import 'package:anteater/metrics/metrics_aggregator.dart';
import 'package:anteater/frontend/source_loader.dart';
import 'package:anteater/version.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Anteater CLI - Deep Semantic Analysis Engine for Dart
void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('analyze')
    ..addCommand('metrics')
    ..addCommand('server')
    ..addFlag('help', abbr: 'h', help: 'Show this help message')
    ..addFlag('version', abbr: 'v', help: 'Show version');

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
        await _runAnalyze(analyzeParser.parse(results.command!.arguments));
        break;
      case 'metrics':
        await _runMetrics(metricsParser.parse(results.command!.arguments));
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

    server.shutdown();

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
  // Note: noFatalInfos is parsed but not used since metrics don't have
  // info-level severity. Reserved for future use.
  final _ = args['no-fatal-infos'] as bool;
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

    sourceLoader.dispose();

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
  final int maxCyclomatic;
  final double minMaintainability;
  final int maxCognitive;
  final int maxLinesOfCode;

  _AnalysisOptionsConfig({
    this.maxCyclomatic = 20,
    this.minMaintainability = 50.0,
    this.maxCognitive = 15,
    this.maxLinesOfCode = 100,
  });
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
