/// Anteater - Deep Semantic Analysis Engine for Dart
///
/// A next-generation static analyzer combining:
/// - SSA-based data flow analysis
/// - Datalog-based relational reasoning (Soufflé)
/// - AI-powered semantic analysis (CodeBERT/ONNX)
///
/// ## Quick Start
///
/// For simple use cases, use the [Anteater] facade class:
///
/// ```dart
/// import 'package:anteater/anteater.dart';
///
/// // Analyze metrics
/// final report = await Anteater.analyzeMetrics('lib');
/// print('Health Score: ${report.healthScore}');
///
/// // Run diagnostics
/// final result = await Anteater.analyze('lib');
/// print('Errors: ${result.errorCount}');
/// ```
///
/// ## Advanced Usage
///
/// For more control, use the component classes directly:
///
/// ```dart
/// final loader = SourceLoader('lib');
/// final aggregator = MetricsAggregator(
///   thresholds: MetricsThresholds(maxCyclomatic: 15),
/// );
///
/// for (final file in loader.discoverDartFiles()) {
///   final result = await loader.resolveFile(file);
///   if (result != null) aggregator.addFile(file, result.unit);
/// }
///
/// final report = aggregator.generateReport();
/// loader.dispose();
/// ```
library anteater;

// High-level API
export 'api/anteater.dart' show Anteater;

// Frontend - Dart/Kernel parsing
export 'frontend/source_loader.dart' show SourceLoader;
export 'frontend/kernel_reader.dart';

// IR - Intermediate Representations
export 'ir/cfg/control_flow_graph.dart';
export 'ir/cfg/cfg_builder.dart';
export 'ir/ssa/ssa_builder.dart';

// IR Generator Pipeline
export 'frontend/ir_generator.dart';

// Reasoner - Semantic Analysis
export 'reasoner/datalog/datalog_engine.dart';
export 'reasoner/datalog/fact_extractor.dart';
export 'reasoner/datalog/points_to_analysis.dart';
export 'reasoner/abstract/abstract_domain.dart';
export 'reasoner/abstract/abstract_interpreter.dart';
export 'reasoner/abstract/bounds_checker.dart';
export 'reasoner/abstract/null_verifier.dart';

// Neural - AI-based Analysis
export 'neural/tokenizer/wordpiece_tokenizer.dart';
export 'neural/inference/onnx_runtime.dart';
export 'neural/inference/onnx_ffi.dart';
export 'neural/cache/embedding_cache.dart';

// Metrics - Code Quality
export 'metrics/complexity_calculator.dart';
export 'metrics/maintainability_index.dart';
export 'metrics/metrics_aggregator.dart'
    show
        MetricsAggregator,
        MetricsThresholds,
        AggregatedReport,
        FunctionMetrics,
        ProjectMetrics,
        RatingDistribution;

// Server - LSP Integration
export 'server/language_server.dart' show AnteaterLanguageServer, ProjectAnalysisResult, Diagnostic;
export 'server/diagnostics_provider.dart';
export 'server/code_actions_provider.dart';
export 'server/hover_provider.dart';
