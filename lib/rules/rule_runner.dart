import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

import 'rule.dart';
import 'rule_registry.dart';

/// Executes style rules on compilation units.
///
/// Coordinates rule execution, violation collection, and file filtering.
class RuleRunner {
  /// Creates a rule runner with the given registry.
  RuleRunner({
    required this.registry,
    this.excludePatterns = const [],
  });

  /// Rule registry containing all registered rules.
  final RuleRegistry registry;

  /// File patterns to exclude from analysis.
  final List<String> excludePatterns;

  /// Cache for compiled glob patterns to avoid repeated RegExp compilation.
  final Map<String, RegExp> _patternCache = {};

  /// Runs all enabled rules on a compilation unit.
  ///
  /// Returns a list of violations found by all rules.
  List<Violation> analyze(
    CompilationUnit unit, {
    LineInfo? lineInfo,
    String? filePath,
  }) {
    final violations = <Violation>[];

    for (final rule in registry.enabledRules) {
      // Check file-level exclusion
      if (filePath != null && _isExcluded(rule.id, filePath)) {
        continue;
      }

      try {
        final ruleViolations = rule.check(unit, lineInfo: lineInfo);

        // Apply severity override from registry
        for (final violation in ruleViolations) {
          violations.add(_applySettings(rule.id, violation));
        }
      } catch (e) {
        // Report rule execution failure as warning instead of silently swallowing
        violations.add(Violation(
          ruleId: rule.id,
          message: 'Rule analysis failed: ${e.toString().split('\n').first}',
          location: SourceRange.zero,
          severity: RuleSeverity.warning,
        ));
      }
    }

    return violations;
  }

  /// Runs a specific rule by ID.
  List<Violation> analyzeWithRule(
    String ruleId,
    CompilationUnit unit, {
    LineInfo? lineInfo,
    String? filePath,
  }) {
    final rule = registry.get(ruleId);
    if (rule == null) {
      return const [];
    }

    if (!registry.isEnabled(ruleId)) {
      return const [];
    }

    if (filePath != null && _isExcluded(ruleId, filePath)) {
      return const [];
    }

    try {
      final violations = rule.check(unit, lineInfo: lineInfo);
      return violations.map((v) => _applySettings(ruleId, v)).toList();
    } catch (e) {
      // Report rule execution failure as warning
      return [
        Violation(
          ruleId: ruleId,
          message: 'Rule analysis failed: ${e.toString().split('\n').first}',
          location: SourceRange.zero,
          severity: RuleSeverity.warning,
        ),
      ];
    }
  }

  /// Runs rules by category.
  List<Violation> analyzeByCategory(
    RuleCategory category,
    CompilationUnit unit, {
    LineInfo? lineInfo,
    String? filePath,
  }) {
    final violations = <Violation>[];
    final categoryRules = registry.getRulesByCategory(category);

    for (final rule in categoryRules) {
      if (!registry.isEnabled(rule.id)) {
        continue;
      }

      if (filePath != null && _isExcluded(rule.id, filePath)) {
        continue;
      }

      try {
        final ruleViolations = rule.check(unit, lineInfo: lineInfo);
        for (final violation in ruleViolations) {
          violations.add(_applySettings(rule.id, violation));
        }
      } catch (e) {
        // Report rule execution failure as warning
        violations.add(Violation(
          ruleId: rule.id,
          message: 'Rule analysis failed: ${e.toString().split('\n').first}',
          location: SourceRange.zero,
          severity: RuleSeverity.warning,
        ));
      }
    }

    return violations;
  }

  /// Checks if a file should be excluded for a rule.
  bool _isExcluded(String ruleId, String filePath) {
    // Check global exclude patterns
    for (final pattern in excludePatterns) {
      if (_matchesPattern(filePath, pattern)) {
        return true;
      }
    }

    // Check rule-specific exclude patterns
    final ruleExcludes = registry.getExcludePatterns(ruleId);
    for (final pattern in ruleExcludes) {
      if (_matchesPattern(filePath, pattern)) {
        return true;
      }
    }

    return false;
  }

  /// Matches a file path against a glob pattern.
  ///
  /// Uses [_patternCache] to avoid repeated RegExp compilation.
  bool _matchesPattern(String filePath, String pattern) {
    final regex = _patternCache.putIfAbsent(pattern, () {
      // Convert glob pattern to regex
      final regexPattern = pattern
          .replaceAll('.', r'\.')
          .replaceAll('**', '{{DOUBLE_STAR}}')
          .replaceAll('*', r'[^/]*')
          .replaceAll('{{DOUBLE_STAR}}', r'.*')
          .replaceAll('?', r'.');
      return RegExp('^$regexPattern\$');
    });
    return regex.hasMatch(filePath);
  }

  /// Applies settings (severity override) to a violation.
  Violation _applySettings(String ruleId, Violation violation) {
    final overrideSeverity = registry.getSeverity(ruleId);

    // Only create new violation if severity differs
    if (overrideSeverity != violation.severity) {
      return Violation(
        ruleId: violation.ruleId,
        message: violation.message,
        location: violation.location,
        severity: overrideSeverity,
        suggestion: violation.suggestion,
        sourceCode: violation.sourceCode,
      );
    }

    return violation;
  }
}

/// Result of running rules on multiple files.
class AnalysisResult {
  AnalysisResult({
    required this.violationsByFile,
    required this.filesAnalyzed,
  });

  /// Creates an empty result.
  factory AnalysisResult.empty() => AnalysisResult(
        violationsByFile: const {},
        filesAnalyzed: 0,
      );

  /// Violations grouped by file path.
  final Map<String, List<Violation>> violationsByFile;

  /// Number of files analyzed.
  final int filesAnalyzed;

  /// Total number of violations (lazily computed, cached).
  late final int totalViolations =
      violationsByFile.values.fold(0, (sum, list) => sum + list.length);

  /// Violations grouped by severity (lazily computed, cached).
  late final Map<RuleSeverity, int> countBySeverity = _computeSeverityCounts();

  /// Violations grouped by rule ID (lazily computed, cached).
  late final Map<String, int> countByRule = _computeRuleCounts();

  /// Files with violations.
  Iterable<String> get filesWithViolations => violationsByFile.keys;

  Map<RuleSeverity, int> _computeSeverityCounts() {
    final counts = <RuleSeverity, int>{};
    for (final violations in violationsByFile.values) {
      for (final v in violations) {
        counts[v.severity] = (counts[v.severity] ?? 0) + 1;
      }
    }
    return counts;
  }

  Map<String, int> _computeRuleCounts() {
    final counts = <String, int>{};
    for (final violations in violationsByFile.values) {
      for (final v in violations) {
        counts[v.ruleId] = (counts[v.ruleId] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Checks if there are any violations.
  bool get hasViolations => totalViolations > 0;

  /// Checks if there are any errors.
  bool get hasErrors => (countBySeverity[RuleSeverity.error] ?? 0) > 0;

  /// Summary string for display.
  @override
  String toString() {
    final errors = countBySeverity[RuleSeverity.error] ?? 0;
    final warnings = countBySeverity[RuleSeverity.warning] ?? 0;
    final infos = countBySeverity[RuleSeverity.info] ?? 0;
    final hints = countBySeverity[RuleSeverity.hint] ?? 0;

    return 'AnalysisResult('
        '$filesAnalyzed files, '
        '$errors errors, '
        '$warnings warnings, '
        '$infos info, '
        '$hints hints)';
  }
}

/// Builder for accumulating analysis results across multiple files.
class AnalysisResultBuilder {
  final Map<String, List<Violation>> _violationsByFile = {};
  int _filesAnalyzed = 0;

  /// Adds violations for a file.
  void addViolations(String filePath, List<Violation> violations) {
    if (violations.isNotEmpty) {
      _violationsByFile[filePath] = violations;
    }
    _filesAnalyzed++;
  }

  /// Builds the final result.
  AnalysisResult build() {
    return AnalysisResult(
      violationsByFile: Map.unmodifiable(_violationsByFile),
      filesAnalyzed: _filesAnalyzed,
    );
  }
}
