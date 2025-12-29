import 'package:analyzer/dart/ast/ast.dart';

import '../frontend/source_loader.dart';
import '../ir/cfg/cfg_builder.dart';
import '../ir/cfg/control_flow_graph.dart';
import '../metrics/complexity_calculator.dart';
import '../metrics/maintainability_index.dart';
import '../reasoner/abstract/bounds_checker.dart';
import '../reasoner/abstract/null_verifier.dart';
import '../reasoner/datalog/datalog_engine.dart';
import '../reasoner/datalog/fact_extractor.dart';
import '../rules/rule.dart';
import '../rules/rule_registry.dart';
import '../rules/rule_runner.dart';
import 'language_server.dart';

/// Provides LSP diagnostics from Anteater analysis results.
///
/// Converts analysis from various engines (metrics, abstract interpretation,
/// datalog, style rules) into LSP-compatible diagnostic messages.
class DiagnosticsProvider {
  DiagnosticsProvider({
    required SourceLoader sourceLoader,
    MaintainabilityIndexCalculator? miCalculator,
    DiagnosticThresholds? thresholds,
    RuleRegistry? ruleRegistry,
    List<String>? excludePatterns,
  })  : _sourceLoader = sourceLoader,
        thresholds = thresholds ?? const DiagnosticThresholds(),
        _miCalculator = miCalculator ??
            MaintainabilityIndexCalculator(ComplexityCalculator()),
        _ruleRegistry = ruleRegistry ?? RuleRegistry.withDefaults() {
    _ruleRunner = RuleRunner(
      registry: _ruleRegistry,
      excludePatterns: excludePatterns ?? const [],
    );
  }

  final SourceLoader _sourceLoader;
  final MaintainabilityIndexCalculator _miCalculator;

  /// Reusable CFG builder (ADR-016 1.2).
  final CfgBuilder _cfgBuilder = CfgBuilder();

  /// Reusable fact extractor (ADR-016 1.2).
  final FactExtractor _factExtractor = FactExtractor();

  /// Rule registry containing all style rules.
  final RuleRegistry _ruleRegistry;

  /// Rule runner for executing style rules.
  late final RuleRunner _ruleRunner;

  /// Thresholds for generating warnings.
  final DiagnosticThresholds thresholds;

  /// Analyzes a file and returns LSP diagnostics.
  Future<List<Diagnostic>> analyze(String filePath, {String? content}) async {
    final diagnostics = <Diagnostic>[];

    // Resolve the file
    final result = await _sourceLoader.resolveFile(filePath);
    if (result == null) {
      return diagnostics;
    }

    final unit = result.unit;

    // 1. Metrics-based diagnostics
    diagnostics.addAll(_analyzeMetrics(unit));

    // 2. Abstract interpretation diagnostics
    diagnostics.addAll(_analyzeAbstractInterpretation(unit));

    // 3. Datalog-based diagnostics
    diagnostics.addAll(_analyzeDatalog(unit));

    // 4. Style rules diagnostics
    diagnostics.addAll(_analyzeStyleRules(unit, filePath));

    return diagnostics;
  }

  /// Gets the rule registry for configuration.
  RuleRegistry get ruleRegistry => _ruleRegistry;

  /// Generates diagnostics from code metrics.
  List<Diagnostic> _analyzeMetrics(CompilationUnit unit) {
    final diagnostics = <Diagnostic>[];
    final fileResult = _miCalculator.calculateForFile(unit);

    for (final entry in fileResult.functions.entries) {
      final name = entry.key;
      final metrics = entry.value;
      final node = _findFunctionNode(unit, name);
      final range = node != null ? _nodeToRange(unit, node) : Range.zero;

      // Cyclomatic complexity check
      if (metrics.cyclomaticComplexity > thresholds.cyclomaticComplexity) {
        diagnostics.add(Diagnostic(
          message: 'Function "$name" has high cyclomatic complexity: '
              '${metrics.cyclomaticComplexity} (threshold: ${thresholds.cyclomaticComplexity})',
          severity: DiagnosticSeverity.warning,
          range: range,
          source: 'anteater',
          code: 'high_cyclomatic_complexity',
        ));
      }

      // Cognitive complexity check
      if (metrics.cognitiveComplexity > thresholds.cognitiveComplexity) {
        diagnostics.add(Diagnostic(
          message: 'Function "$name" has high cognitive complexity: '
              '${metrics.cognitiveComplexity} (threshold: ${thresholds.cognitiveComplexity})',
          severity: DiagnosticSeverity.hint,
          range: range,
          source: 'anteater',
          code: 'high_cognitive_complexity',
        ));
      }

      // Maintainability index check
      if (metrics.maintainabilityIndex < thresholds.maintainabilityIndex) {
        diagnostics.add(Diagnostic(
          message: 'Function "$name" has low maintainability index: '
              '${metrics.maintainabilityIndex.toStringAsFixed(1)} (threshold: ${thresholds.maintainabilityIndex})',
          severity: DiagnosticSeverity.warning,
          range: range,
          source: 'anteater',
          code: 'low_maintainability_index',
        ));
      }

      // Lines of code check
      if (metrics.linesOfCode > thresholds.linesOfCode) {
        diagnostics.add(Diagnostic(
          message: 'Function "$name" is too long: '
              '${metrics.linesOfCode} lines (threshold: ${thresholds.linesOfCode})',
          severity: DiagnosticSeverity.info,
          range: range,
          source: 'anteater',
          code: 'function_too_long',
        ));
      }
    }

    return diagnostics;
  }

  /// Generates diagnostics from abstract interpretation analysis.
  List<Diagnostic> _analyzeAbstractInterpretation(CompilationUnit unit) {
    final diagnostics = <Diagnostic>[];

    // Build CFG for each function
    for (final declaration in unit.declarations) {
      if (declaration is FunctionDeclaration) {
        try {
          // ADR-016 1.2: Reuse CfgBuilder instance
          final cfg = _cfgBuilder.buildFromFunction(declaration);

          // Null safety verification
          final nullDiags = _checkNullSafety(cfg, unit, declaration);
          diagnostics.addAll(nullDiags);

          // Bounds checking
          final boundsDiags = _checkBounds(cfg, unit, declaration);
          diagnostics.addAll(boundsDiags);
        } catch (e) {
          // Analysis failed, skip this function
          continue;
        }
      }
    }

    return diagnostics;
  }

  /// Checks for potential null dereference issues.
  List<Diagnostic> _checkNullSafety(
    ControlFlowGraph cfg,
    CompilationUnit unit,
    FunctionDeclaration function,
  ) {
    final diagnostics = <Diagnostic>[];

    try {
      final verifier = NullVerifier();
      final issues = verifier.verifyCfg(cfg);

      for (final issue in issues) {
        if (!issue.isSafe && !issue.isDefinitelyNull) {
          diagnostics.add(Diagnostic(
            message: 'Potential null dereference: ${issue.reason}',
            severity: DiagnosticSeverity.warning,
            range: _nodeToRange(unit, function),
            source: 'anteater',
            code: 'potential_null_dereference',
          ));
        } else if (issue.isDefinitelyNull) {
          diagnostics.add(Diagnostic(
            message: 'Definite null dereference: ${issue.reason}',
            severity: DiagnosticSeverity.error,
            range: _nodeToRange(unit, function),
            source: 'anteater',
            code: 'definite_null_dereference',
          ));
        }
      }
    } catch (e) {
      // Verification failed
    }

    return diagnostics;
  }

  /// Checks for potential array bounds violations.
  List<Diagnostic> _checkBounds(
    ControlFlowGraph cfg,
    CompilationUnit unit,
    FunctionDeclaration function,
  ) {
    final diagnostics = <Diagnostic>[];

    try {
      final checker = BoundsChecker();
      final issues = checker.checkCfg(cfg);

      for (final issue in issues) {
        if (issue.isDefinitelyUnsafe) {
          diagnostics.add(Diagnostic(
            message: 'Definite bounds violation: ${issue.reason}',
            severity: DiagnosticSeverity.error,
            range: _nodeToRange(unit, function),
            source: 'anteater',
            code: 'definite_bounds_violation',
          ));
        } else if (!issue.isSafe) {
          diagnostics.add(Diagnostic(
            message: 'Potential bounds violation: ${issue.reason}',
            severity: DiagnosticSeverity.warning,
            range: _nodeToRange(unit, function),
            source: 'anteater',
            code: 'potential_bounds_violation',
          ));
        }
      }
    } catch (e) {
      // Check failed
    }

    return diagnostics;
  }

  /// Generates diagnostics from datalog analysis.
  List<Diagnostic> _analyzeDatalog(CompilationUnit unit) {
    final diagnostics = <Diagnostic>[];

    // Build CFG and extract facts for analysis
    for (final declaration in unit.declarations) {
      if (declaration is FunctionDeclaration) {
        try {
          // ADR-016 1.2: Reuse CfgBuilder and FactExtractor instances
          final cfg = _cfgBuilder.buildFromFunction(declaration);
          final facts = _factExtractor.extractFromCfg(cfg);

          // DatalogEngine must be per-analysis (stateful)
          final engine = InMemoryDatalogEngine();
          engine.loadFacts(facts);
          engine.run();

          // Check for mutable shared state
          final mutableHeaps = engine.query('Mutable');
          if (mutableHeaps.isNotEmpty) {
            diagnostics.add(Diagnostic(
              message:
                  'Function "${declaration.name.lexeme}" contains mutable shared state '
                  '(${mutableHeaps.length} mutable allocations)',
              severity: DiagnosticSeverity.info,
              range: _nodeToRange(unit, declaration),
              source: 'anteater',
              code: 'mutable_shared_state',
            ));
          }
        } catch (e) {
          // Analysis failed
          continue;
        }
      }
    }

    return diagnostics;
  }

  /// Generates diagnostics from style rules.
  List<Diagnostic> _analyzeStyleRules(CompilationUnit unit, String filePath) {
    final diagnostics = <Diagnostic>[];

    try {
      final violations = _ruleRunner.analyze(
        unit,
        lineInfo: unit.lineInfo,
        filePath: filePath,
      );

      for (final violation in violations) {
        diagnostics.add(_violationToDiagnostic(unit, violation));
      }
    } catch (e) {
      // Style rule analysis failed, continue without style diagnostics
    }

    return diagnostics;
  }

  /// Converts a style rule violation to an LSP Diagnostic.
  Diagnostic _violationToDiagnostic(CompilationUnit unit, Violation violation) {
    final range = Range(
      start: Position(
        line: violation.location.start.line - 1,
        character: violation.location.start.column - 1,
      ),
      end: Position(
        line: violation.location.end.line - 1,
        character: violation.location.end.column - 1,
      ),
    );

    return Diagnostic(
      message: violation.suggestion != null
          ? '${violation.message}\nSuggestion: ${violation.suggestion}'
          : violation.message,
      severity: _mapSeverity(violation.severity),
      range: range,
      source: 'anteater',
      code: violation.ruleId,
    );
  }

  /// Maps rule severity to LSP diagnostic severity.
  DiagnosticSeverity _mapSeverity(RuleSeverity severity) {
    switch (severity) {
      case RuleSeverity.error:
        return DiagnosticSeverity.error;
      case RuleSeverity.warning:
        return DiagnosticSeverity.warning;
      case RuleSeverity.info:
        return DiagnosticSeverity.info;
      case RuleSeverity.hint:
        return DiagnosticSeverity.hint;
    }
  }

  /// Finds a function node by name in the compilation unit.
  AstNode? _findFunctionNode(CompilationUnit unit, String name) {
    for (final declaration in unit.declarations) {
      if (declaration is FunctionDeclaration &&
          declaration.name.lexeme == name) {
        return declaration;
      }
      if (declaration is ClassDeclaration) {
        for (final member in declaration.members) {
          if (member is MethodDeclaration && member.name.lexeme == name) {
            return member;
          }
        }
      }
    }
    return null;
  }

  /// Converts an AST node to an LSP Range.
  Range _nodeToRange(CompilationUnit unit, AstNode node) {
    final lineInfo = unit.lineInfo;
    final startLocation = lineInfo.getLocation(node.offset);
    final endLocation = lineInfo.getLocation(node.end);

    return Range(
      start: Position(
        line: startLocation.lineNumber - 1,
        character: startLocation.columnNumber - 1,
      ),
      end: Position(
        line: endLocation.lineNumber - 1,
        character: endLocation.columnNumber - 1,
      ),
    );
  }
}

/// Configuration thresholds for diagnostic generation.
class DiagnosticThresholds {
  const DiagnosticThresholds({
    this.cyclomaticComplexity = 20,
    this.cognitiveComplexity = 15,
    this.maintainabilityIndex = 50.0,
    this.linesOfCode = 100,
    this.parameters = 4,
  });

  /// Maximum cyclomatic complexity before warning.
  final int cyclomaticComplexity;

  /// Maximum cognitive complexity before hint.
  final int cognitiveComplexity;

  /// Minimum maintainability index before warning.
  final double maintainabilityIndex;

  /// Maximum lines of code before info.
  final int linesOfCode;

  /// Maximum number of parameters before warning.
  final int parameters;
}
