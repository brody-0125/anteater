import '../rules/rule.dart';

/// Type of technical debt.
enum DebtType {
  /// TODO comment indicating planned work.
  todo('TODO', DebtSeverity.medium),

  /// FIXME comment indicating known issue.
  fixme('FIXME', DebtSeverity.high),

  /// Single ignore comment suppressing a warning.
  ignoreComment('ignore comment', DebtSeverity.high),

  /// File-level ignore suppressing warnings for entire file.
  ignoreForFile('ignore_for_file', DebtSeverity.critical),

  /// Cast to dynamic type.
  asDynamic('as dynamic', DebtSeverity.high),

  /// Usage of deprecated API.
  deprecated('@deprecated', DebtSeverity.medium),

  /// Function with low maintainability index (MI < 50).
  lowMaintainability('low maintainability', DebtSeverity.high),

  /// Function with high cyclomatic complexity (> threshold).
  highComplexity('high complexity', DebtSeverity.medium),

  /// Function with too many lines of code.
  longMethod('long method', DebtSeverity.medium),

  /// Duplicate or similar code detected.
  duplicateCode('duplicate code', DebtSeverity.medium);

  /// Human-readable label.
  final String label;

  /// Default severity for this debt type.
  final DebtSeverity defaultSeverity;

  const DebtType(this.label, this.defaultSeverity);
}

/// Severity level for technical debt.
enum DebtSeverity {
  /// Critical issues requiring immediate attention.
  critical(4.0, 'Critical'),

  /// High priority issues.
  high(2.0, 'High'),

  /// Medium priority issues.
  medium(1.0, 'Medium'),

  /// Low priority issues.
  low(0.5, 'Low');

  /// Cost multiplier for this severity.
  final double multiplier;

  /// Human-readable label.
  final String label;

  const DebtSeverity(this.multiplier, this.label);
}

/// Represents a single technical debt item.
class DebtItem {
  /// Type of debt.
  final DebtType type;

  /// Description of the debt item.
  final String description;

  /// Location in source code.
  final SourceRange location;

  /// File path where debt was detected.
  final String filePath;

  /// Context (e.g., function name, class name).
  final String? context;

  /// Severity level (defaults to type's default severity).
  final DebtSeverity severity;

  /// Original source code snippet.
  final String? sourceCode;

  DebtItem({
    required this.type,
    required this.description,
    required this.location,
    required this.filePath,
    this.context,
    DebtSeverity? severity,
    this.sourceCode,
  }) : severity = severity ?? type.defaultSeverity;

  @override
  String toString() =>
      'DebtItem(${type.label} at $filePath:${location.start.line}: $description)';

  /// Convert to JSON map.
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'description': description,
        'filePath': filePath,
        'line': location.start.line,
        'column': location.start.column,
        'severity': severity.name,
        if (context != null) 'context': context,
        if (sourceCode != null) 'sourceCode': sourceCode,
      };
}
