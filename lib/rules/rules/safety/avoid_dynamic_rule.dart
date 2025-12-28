import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../../rule.dart';

/// Rule that discourages use of 'dynamic' type.
///
/// The 'dynamic' type bypasses static type checking and can lead to
/// runtime errors that could have been caught at compile time.
///
/// ## Known Limitations
///
/// This rule only detects **explicit** `dynamic` type annotations. It uses
/// syntactic analysis without resolved type information, so it **cannot detect**
/// implicit dynamic from type inference failures.
///
/// ### Detected (Explicit Dynamic)
///
/// ```dart
/// dynamic x;                    // Detected
/// Map<String, dynamic> map;     // Detected (nested)
/// void fn(dynamic param) {}     // Detected
/// x as dynamic;                 // Detected
/// ```
///
/// ### NOT Detected (Implicit Dynamic)
///
/// ```dart
/// var x = json['key'];          // NOT detected (inferred dynamic)
/// final data = response.body;   // NOT detected if body is dynamic
/// list.map((e) => e.name);      // NOT detected if e is inferred dynamic
/// ```
///
/// ### Why This Limitation Exists
///
/// Detecting implicit dynamic requires resolved type information from the
/// Dart analyzer, which adds significant complexity and performance overhead.
/// This rule prioritizes speed and simplicity for the common case of catching
/// explicit `dynamic` annotations that developers consciously write.
///
/// ### Complementary Analysis
///
/// For comprehensive dynamic detection, use Dart's strict analysis options:
/// ```yaml
/// analyzer:
///   language:
///     strict-casts: true
///     strict-inference: true
///     strict-raw-types: true
/// ```
class AvoidDynamicRule extends StyleRule {
  @override
  String get id => 'avoid-dynamic';

  @override
  String get description =>
      'Avoid using dynamic type. Use Object? or specific types instead.';

  @override
  RuleSeverity get defaultSeverity => RuleSeverity.warning;

  @override
  RuleCategory get category => RuleCategory.safety;

  @override
  String? get documentationUrl =>
      'https://dart.dev/tools/linter-rules/avoid_dynamic_calls';

  @override
  List<Violation> check(CompilationUnit unit, {LineInfo? lineInfo}) {
    final effectiveLineInfo = lineInfo ?? unit.lineInfo;
    final visitor = _AvoidDynamicVisitor(effectiveLineInfo);
    unit.accept(visitor);
    return visitor.violations;
  }
}

class _AvoidDynamicVisitor extends RecursiveAstVisitor<void> {
  final LineInfo lineInfo;
  final List<Violation> violations = [];

  _AvoidDynamicVisitor(this.lineInfo);

  @override
  void visitNamedType(NamedType node) {
    // Check if the type is 'dynamic'
    if (node.name.lexeme == 'dynamic') {
      violations.add(_createViolation(node));
    }
    super.visitNamedType(node);
  }

  @override
  void visitAsExpression(AsExpression node) {
    // Check for 'as dynamic' casts
    final type = node.type;
    if (type is NamedType && type.name.lexeme == 'dynamic') {
      violations.add(Violation(
        ruleId: 'avoid-dynamic',
        message: "Avoid casting to 'dynamic'. This bypasses type checking.",
        location: SourceRange.fromNode(node, lineInfo),
        severity: RuleSeverity.warning,
        suggestion: 'Use a specific type or Object? instead.',
        sourceCode: node.toSource(),
      ));
    }
    super.visitAsExpression(node);
  }

  Violation _createViolation(NamedType node) {
    return Violation(
      ruleId: 'avoid-dynamic',
      message:
          "Avoid using 'dynamic' type. It bypasses static type checking.",
      location: SourceRange.fromNode(node, lineInfo),
      severity: RuleSeverity.warning,
      suggestion: 'Use Object?, a specific type, or a generic type parameter.',
      sourceCode: node.toSource(),
    );
  }
}
