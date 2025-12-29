import 'dart:math' as math;

import 'package:analyzer/dart/ast/ast.dart';

import 'complexity_calculator.dart';

/// Calculates the Maintainability Index for Dart code.
///
/// MI = max(0, (171 - 5.2×ln(V) - 0.23×G - 16.2×ln(LOC)) × 100/171)
///
/// Where:
/// - V = Halstead Volume
/// - G = Cyclomatic Complexity
/// - LOC = Lines of Code
class MaintainabilityIndexCalculator {
  MaintainabilityIndexCalculator([ComplexityCalculator? calculator])
      : _complexityCalculator = calculator ?? ComplexityCalculator();

  final ComplexityCalculator _complexityCalculator;

  /// Calculates the maintainability index for a function/method.
  MaintainabilityResult calculate(FunctionBody body) {
    final cyclomaticComplexity =
        _complexityCalculator.calculateCyclomaticComplexity(body);

    final cognitiveComplexity =
        _complexityCalculator.calculateCognitiveComplexity(body);

    final halstead = _complexityCalculator.calculateHalsteadMetrics(body);

    final linesOfCode = _countLines(body);

    final mi = _computeMI(
      halsteadVolume: halstead.volume,
      cyclomaticComplexity: cyclomaticComplexity,
      linesOfCode: linesOfCode,
    );

    return MaintainabilityResult(
      maintainabilityIndex: mi,
      cyclomaticComplexity: cyclomaticComplexity,
      cognitiveComplexity: cognitiveComplexity,
      halsteadMetrics: halstead,
      linesOfCode: linesOfCode,
      rating: _getRating(mi),
    );
  }

  /// Calculates MI for a compilation unit (file-level).
  FileMaintainabilityResult calculateForFile(CompilationUnit unit) {
    final functions = <String, MaintainabilityResult>{};
    var totalMI = 0.0;
    var count = 0;

    for (final declaration in unit.declarations) {
      if (declaration is FunctionDeclaration) {
        final body = declaration.functionExpression.body;
        final result = calculate(body);
        functions[declaration.name.lexeme] = result;
        totalMI += result.maintainabilityIndex;
        count++;
      } else if (declaration is ClassDeclaration) {
        for (final member in declaration.members) {
          if (member is MethodDeclaration) {
            final body = member.body;
            final result = calculate(body);
            final name = '${declaration.name.lexeme}.${member.name.lexeme}';
            functions[name] = result;
            totalMI += result.maintainabilityIndex;
            count++;
          }
        }
      }
    }

    final averageMI = count > 0 ? totalMI / count : 100.0;

    return FileMaintainabilityResult(
      functions: functions,
      averageMaintainabilityIndex: averageMI,
      rating: _getRating(averageMI),
    );
  }

  double _computeMI({
    required double halsteadVolume,
    required int cyclomaticComplexity,
    required int linesOfCode,
  }) {
    if (linesOfCode <= 0 || halsteadVolume <= 0) {
      return 100.0;
    }

    final mi = 171 -
        5.2 * math.log(halsteadVolume) -
        0.23 * cyclomaticComplexity -
        16.2 * math.log(linesOfCode);

    return math.max(0, mi * 100 / 171);
  }

  /// Counts lines by counting newline characters.
  /// ADR-016 2.2: Avoids allocating a list via split().
  int _countLines(AstNode node) {
    final source = node.toSource();
    var count = 1;
    for (var i = 0; i < source.length; i++) {
      if (source.codeUnitAt(i) == 0x0A) count++; // '\n'
    }
    return count;
  }

  MaintainabilityRating _getRating(double mi) {
    if (mi >= 80) return MaintainabilityRating.good;
    if (mi >= 50) return MaintainabilityRating.moderate;
    return MaintainabilityRating.poor;
  }
}

/// Result of maintainability calculation for a single function.
class MaintainabilityResult {
  const MaintainabilityResult({
    required this.maintainabilityIndex,
    required this.cyclomaticComplexity,
    required this.cognitiveComplexity,
    required this.halsteadMetrics,
    required this.linesOfCode,
    required this.rating,
  });

  final double maintainabilityIndex;
  final int cyclomaticComplexity;
  final int cognitiveComplexity;
  final HalsteadMetrics halsteadMetrics;
  final int linesOfCode;
  final MaintainabilityRating rating;

  @override
  String toString() => '''
MaintainabilityResult(
  MI: ${maintainabilityIndex.toStringAsFixed(2)} ($rating)
  Cyclomatic: $cyclomaticComplexity
  Cognitive: $cognitiveComplexity
  LOC: $linesOfCode
  $halsteadMetrics
)''';
}

/// Result of maintainability calculation for an entire file.
class FileMaintainabilityResult {
  const FileMaintainabilityResult({
    required this.functions,
    required this.averageMaintainabilityIndex,
    required this.rating,
  });

  final Map<String, MaintainabilityResult> functions;
  final double averageMaintainabilityIndex;
  final MaintainabilityRating rating;

  /// Returns functions that need attention (MI < 50).
  Iterable<MapEntry<String, MaintainabilityResult>> get needsAttention =>
      functions.entries.where(
        (e) => e.value.rating == MaintainabilityRating.poor,
      );

  @override
  String toString() => '''
FileMaintainabilityResult(
  Average MI: ${averageMaintainabilityIndex.toStringAsFixed(2)} ($rating)
  Functions: ${functions.length}
  Needs Attention: ${needsAttention.length}
)''';
}

/// Maintainability rating categories.
/// ADR-016 3.1: Enhanced enum with built-in properties.
enum MaintainabilityRating {
  /// MI >= 80: Easy to maintain
  good('🟢', 'Good'),

  /// 50 <= MI < 80: Moderate difficulty
  moderate('🟡', 'Moderate'),

  /// MI < 50: Difficult to maintain
  poor('🔴', 'Poor');

  const MaintainabilityRating(this.emoji, this.label);

  /// Visual indicator emoji.
  final String emoji;

  /// Human-readable label.
  final String label;
}
