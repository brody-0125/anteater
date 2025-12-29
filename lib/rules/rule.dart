import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

/// Severity level for rule violations.
enum RuleSeverity {
  /// Critical issues that must be fixed.
  error,

  /// Issues that should be addressed.
  warning,

  /// Suggestions for improvement.
  info,

  /// Minor style hints.
  hint,
}

/// Category of style rules.
enum RuleCategory {
  /// Safety-related rules (avoid-dynamic, avoid-global-state).
  safety,

  /// Code quality rules (prefer-async-await).
  quality,

  /// Style consistency rules (trailing-comma).
  style,

  /// Performance-related rules.
  performance,
}

/// Base class for all style rules.
///
/// Implement this class to create custom rules that analyze
/// Dart AST and report violations.
abstract class StyleRule {
  /// Unique identifier for this rule (e.g., 'avoid-dynamic').
  String get id;

  /// Human-readable description of what this rule checks.
  String get description;

  /// Default severity for violations of this rule.
  RuleSeverity get defaultSeverity;

  /// Category this rule belongs to.
  RuleCategory get category;

  /// Documentation URL for this rule.
  String? get documentationUrl => null;

  /// Check the compilation unit for violations.
  ///
  /// Returns a list of [Violation]s found in the unit.
  List<Violation> check(CompilationUnit unit, {LineInfo? lineInfo});
}

/// Represents a violation of a style rule.
class Violation {
  const Violation({
    required this.ruleId,
    required this.message,
    required this.location,
    required this.severity,
    this.suggestion,
    this.sourceCode,
  });

  /// The rule that was violated.
  final String ruleId;

  /// Human-readable message describing the violation.
  final String message;

  /// Location of the violation in source code.
  final SourceRange location;

  /// Severity of this violation.
  final RuleSeverity severity;

  /// Optional suggestion for fixing the violation.
  final String? suggestion;

  /// Optional code that triggered the violation.
  final String? sourceCode;

  @override
  String toString() =>
      'Violation($ruleId at ${location.start.line}:${location.start.column}: $message)';
}

/// Represents a range in source code.
class SourceRange {
  const SourceRange({
    required this.start,
    required this.end,
    required this.offset,
    required this.length,
  });

  /// Create from AST node and line info.
  factory SourceRange.fromNode(AstNode node, LineInfo lineInfo) {
    final startLocation = lineInfo.getLocation(node.offset);
    final endLocation = lineInfo.getLocation(node.end);
    return SourceRange(
      start: SourcePosition(
        line: startLocation.lineNumber,
        column: startLocation.columnNumber,
      ),
      end: SourcePosition(
        line: endLocation.lineNumber,
        column: endLocation.columnNumber,
      ),
      offset: node.offset,
      length: node.length,
    );
  }

  /// Create from offset and length with line info.
  factory SourceRange.fromOffset(int offset, int length, LineInfo lineInfo) {
    final startLocation = lineInfo.getLocation(offset);
    final endLocation = lineInfo.getLocation(offset + length);
    return SourceRange(
      start: SourcePosition(
        line: startLocation.lineNumber,
        column: startLocation.columnNumber,
      ),
      end: SourcePosition(
        line: endLocation.lineNumber,
        column: endLocation.columnNumber,
      ),
      offset: offset,
      length: length,
    );
  }

  /// Start position.
  final SourcePosition start;

  /// End position.
  final SourcePosition end;

  /// Offset from beginning of file.
  final int offset;

  /// Length of the range.
  final int length;

  /// Zero range for unknown locations.
  static const zero = SourceRange(
    start: SourcePosition(line: 0, column: 0),
    end: SourcePosition(line: 0, column: 0),
    offset: 0,
    length: 0,
  );

  @override
  String toString() => '${start.line}:${start.column}-${end.line}:${end.column}';
}

/// Represents a position in source code.
class SourcePosition {
  const SourcePosition({
    required this.line,
    required this.column,
  });

  /// 1-based line number.
  final int line;

  /// 1-based column number.
  final int column;

  @override
  String toString() => '$line:$column';
}

/// Settings for a specific rule.
class RuleSettings {
  /// Private const constructor for internal use and static instances.
  const RuleSettings._({
    required this.enabled,
    this.severity,
    required this.options,
    required this.exclude,
  });

  /// Creates rule settings with unmodifiable collections.
  ///
  /// Wraps [options] and [exclude] in unmodifiable views to prevent mutation.
  factory RuleSettings({
    bool enabled = true,
    RuleSeverity? severity,
    Map<String, dynamic> options = const {},
    List<String> exclude = const [],
  }) =>
      RuleSettings._(
        enabled: enabled,
        severity: severity,
        options: Map.unmodifiable(options),
        exclude: List.unmodifiable(exclude),
      );

  /// Whether the rule is enabled.
  final bool enabled;

  /// Override severity (null = use default).
  final RuleSeverity? severity;

  /// Rule-specific options (unmodifiable).
  final Map<String, dynamic> options;

  /// File patterns to exclude from this rule (unmodifiable).
  final List<String> exclude;

  /// Default settings with rule enabled.
  static const defaultEnabled = RuleSettings._(
    enabled: true,
    options: {},
    exclude: [],
  );

  /// Default settings with rule disabled.
  static const defaultDisabled = RuleSettings._(
    enabled: false,
    options: {},
    exclude: [],
  );
}
