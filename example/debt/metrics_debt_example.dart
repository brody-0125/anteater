// ignore_for_file: unused_local_variable, dead_code, unused_element

/// Example: Metrics-Based Technical Debt
///
/// This file demonstrates functions that exceed quality thresholds.
///
/// ## Default Thresholds
///
/// | Metric | Threshold | Debt Type |
/// |--------|-----------|-----------|
/// | Maintainability Index | < 50 | lowMaintainability |
/// | Cyclomatic Complexity | > 20 | highComplexity |
/// | Lines of Code | > 100 | longMethod |
///
/// ## Severity and Costs
///
/// | Debt Type | Severity | Base Cost |
/// |-----------|----------|-----------|
/// | lowMaintainability | High | 8 hours |
/// | highComplexity | Medium | 4 hours |
/// | longMethod | Medium | 4 hours |
///
/// ## Detection Requirements
///
/// Metrics debt detection requires passing `FileMaintainabilityResult`
/// to the detector. Without metrics data, these debts are not detected.
///
/// Run with:
/// ```bash
/// anteater debt -p example/debt/metrics_debt_example.dart
/// ```
library;

import 'dart:math' as math;

// ============================================================================
// Low Maintainability Index (MI < 50)
// ============================================================================

/// This function has LOW maintainability due to:
/// - High Halstead Volume (many operators/operands)
/// - High Cyclomatic Complexity
/// - Many lines of code
///
/// MI Formula: max(0, (171 - 5.2×ln(V) - 0.23×G - 16.2×ln(LOC)) × 100/171)
///
/// Expected: MI ≈ 30-45 (Poor - Red)
Map<String, dynamic> processComplexData(
  List<Map<String, dynamic>> data,
  Map<String, dynamic> config,
  bool validateAll,
  bool strictMode,
  int maxErrors,
) {
  final results = <String, dynamic>{};
  final errors = <String>[];
  final warnings = <String>[];
  var processedCount = 0;
  var skippedCount = 0;
  var errorCount = 0;

  // Validation phase
  if (validateAll) {
    for (final item in data) {
      if (!item.containsKey('id')) {
        if (strictMode) {
          errors.add('Missing id field');
          errorCount++;
          if (errorCount >= maxErrors) {
            results['status'] = 'failed';
            results['errors'] = errors;
            return results;
          }
        } else {
          warnings.add('Missing id field');
          skippedCount++;
          continue;
        }
      }

      if (!item.containsKey('type')) {
        if (strictMode) {
          errors.add('Missing type field');
          errorCount++;
        } else {
          warnings.add('Missing type field');
        }
      }

      if (item.containsKey('value')) {
        final value = item['value'];
        if (value is! num) {
          if (strictMode) {
            errors.add('Invalid value type');
            errorCount++;
          } else {
            warnings.add('Value is not a number');
          }
        } else if (value < 0) {
          if (strictMode) {
            errors.add('Negative value not allowed');
            errorCount++;
          } else {
            warnings.add('Negative value detected');
          }
        }
      }
    }
  }

  // Processing phase
  for (final item in data) {
    final type = item['type'] as String?;

    if (type == null) {
      skippedCount++;
      continue;
    }

    switch (type) {
      case 'numeric':
        final value = item['value'] as num?;
        if (value != null) {
          if (config['transform'] == 'square') {
            results[item['id'].toString()] = value * value;
          } else if (config['transform'] == 'sqrt') {
            results[item['id'].toString()] = math.sqrt(value.toDouble());
          } else if (config['transform'] == 'log') {
            results[item['id'].toString()] = math.log(value.toDouble());
          } else {
            results[item['id'].toString()] = value;
          }
          processedCount++;
        }
      case 'text':
        final text = item['value'] as String?;
        if (text != null) {
          if (config['uppercase'] == true) {
            results[item['id'].toString()] = text.toUpperCase();
          } else if (config['lowercase'] == true) {
            results[item['id'].toString()] = text.toLowerCase();
          } else {
            results[item['id'].toString()] = text;
          }
          processedCount++;
        }
      case 'boolean':
        results[item['id'].toString()] = item['value'] ?? false;
        processedCount++;
      default:
        skippedCount++;
    }
  }

  results['metadata'] = {
    'processed': processedCount,
    'skipped': skippedCount,
    'errors': errorCount,
    'warnings': warnings.length,
  };

  if (errors.isNotEmpty) {
    results['errors'] = errors;
    results['status'] = 'partial';
  } else {
    results['status'] = 'success';
  }

  if (warnings.isNotEmpty) {
    results['warnings'] = warnings;
  }

  return results;
}

// ============================================================================
// High Cyclomatic Complexity (CC > 20)
// ============================================================================

/// This function has HIGH cyclomatic complexity.
/// Many decision points (if, switch cases, &&, ||) increase CC.
///
/// Counting decisions:
/// - Base: 1
/// - if statements: +10
/// - switch cases: +7 (excluding default)
/// - && operators: +3
/// - || operators: +2
///
/// Expected: CC ≈ 23+
String categorizeValue(
  dynamic value,
  bool strict,
  bool allowNull,
  int minLength,
  int maxLength,
) {
  // Null handling (2 decisions)
  if (value == null) {
    if (allowNull) {
      return 'null_allowed';
    } else {
      return 'null_rejected';
    }
  }

  // Type checks (multiple decisions)
  if (value is String) {
    if (value.isEmpty) {
      return 'empty_string';
    }
    if (value.length < minLength && strict) {
      return 'too_short_strict';
    }
    if (value.length < minLength) {
      return 'too_short';
    }
    if (value.length > maxLength && strict) {
      return 'too_long_strict';
    }
    if (value.length > maxLength) {
      return 'too_long';
    }
    return 'valid_string';
  }

  if (value is int) {
    if (value < 0 && strict) {
      return 'negative_strict';
    }
    if (value < 0) {
      return 'negative';
    }
    if (value == 0) {
      return 'zero';
    }
    if (value > 1000000 && strict) {
      return 'too_large_strict';
    }
    return 'valid_int';
  }

  if (value is double) {
    if (value.isNaN || value.isInfinite) {
      return 'invalid_double';
    }
    return 'valid_double';
  }

  if (value is bool) {
    return value ? 'true' : 'false';
  }

  if (value is List) {
    if (value.isEmpty) {
      return 'empty_list';
    }
    if (value.length > 100 && strict) {
      return 'large_list_strict';
    }
    return 'valid_list';
  }

  if (value is Map) {
    if (value.isEmpty) {
      return 'empty_map';
    }
    return 'valid_map';
  }

  return 'unknown_type';
}

// ============================================================================
// Long Method (LOC > 100)
// ============================================================================

/// This function exceeds the line count threshold.
/// Even with moderate complexity, length alone creates debt.
///
/// Expected: LOC ≈ 110+
String generateDetailedReport(
  String title,
  List<String> sections,
  Map<String, int> metrics,
  List<String> notes,
  bool includeTimestamp,
) {
  final buffer = StringBuffer();

  // Header section
  buffer.writeln('=' * 60);
  buffer.writeln('REPORT: $title');
  buffer.writeln('=' * 60);
  buffer.writeln();

  // Timestamp
  if (includeTimestamp) {
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln();
  }

  // Table of contents
  buffer.writeln('TABLE OF CONTENTS');
  buffer.writeln('-' * 40);
  for (var i = 0; i < sections.length; i++) {
    buffer.writeln('  ${i + 1}. ${sections[i]}');
  }
  buffer.writeln();

  // Executive summary
  buffer.writeln('EXECUTIVE SUMMARY');
  buffer.writeln('-' * 40);
  buffer.writeln('This report contains ${sections.length} sections.');
  buffer.writeln('Total metrics tracked: ${metrics.length}');
  buffer.writeln('Additional notes: ${notes.length}');
  buffer.writeln();

  // Metrics section
  buffer.writeln('METRICS OVERVIEW');
  buffer.writeln('-' * 40);
  buffer.writeln();
  buffer.writeln('| Metric Name          | Value     |');
  buffer.writeln('|---------------------|-----------|');
  for (final entry in metrics.entries) {
    final name = entry.key.padRight(20);
    final value = entry.value.toString().padLeft(9);
    buffer.writeln('| $name | $value |');
  }
  buffer.writeln();

  // Statistics
  if (metrics.isNotEmpty) {
    final values = metrics.values.toList();
    final sum = values.reduce((a, b) => a + b);
    final avg = sum / values.length;
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);

    buffer.writeln('STATISTICS');
    buffer.writeln('-' * 40);
    buffer.writeln('  Sum:     $sum');
    buffer.writeln('  Average: ${avg.toStringAsFixed(2)}');
    buffer.writeln('  Maximum: $max');
    buffer.writeln('  Minimum: $min');
    buffer.writeln();
  }

  // Detailed sections
  buffer.writeln('DETAILED SECTIONS');
  buffer.writeln('-' * 40);
  for (var i = 0; i < sections.length; i++) {
    buffer.writeln();
    buffer.writeln('${i + 1}. ${sections[i]}');
    buffer.writeln('   ' + '-' * 37);
    buffer.writeln('   Content for section "${sections[i]}"');
    buffer.writeln('   This section provides detailed information.');
    buffer.writeln('   Additional analysis may be added here.');
  }
  buffer.writeln();

  // Notes section
  if (notes.isNotEmpty) {
    buffer.writeln('NOTES AND OBSERVATIONS');
    buffer.writeln('-' * 40);
    for (var i = 0; i < notes.length; i++) {
      buffer.writeln('  * ${notes[i]}');
    }
    buffer.writeln();
  }

  // Footer
  buffer.writeln('=' * 60);
  buffer.writeln('END OF REPORT');
  buffer.writeln('=' * 60);

  return buffer.toString();
}

// ============================================================================
// Combined Debt: All Thresholds Exceeded
// ============================================================================

/// This function exceeds ALL thresholds:
/// - MI < 50 (low maintainability)
/// - CC > 20 (high complexity)
/// - LOC > 100 (long method)
///
/// This represents severe technical debt requiring immediate attention.
Map<String, dynamic> extremelyComplexValidator(
  Map<String, dynamic> input,
  Map<String, dynamic> schema,
  Map<String, dynamic> options,
  List<String> requiredFields,
  List<String> optionalFields,
  Map<String, List<String>> fieldDependencies,
) {
  final errors = <String, List<String>>{};
  final warnings = <String, List<String>>{};
  final processed = <String, dynamic>{};
  final metadata = <String, dynamic>{};

  var fieldCount = 0;
  var errorCount = 0;
  var warningCount = 0;
  var skippedCount = 0;

  final strictMode = options['strict'] == true;
  final allowExtra = options['allowExtraFields'] == true;
  final coerceTypes = options['coerceTypes'] == true;

  // Check required fields
  for (final field in requiredFields) {
    fieldCount++;
    if (!input.containsKey(field)) {
      errors[field] = ['Field is required'];
      errorCount++;
      continue;
    }

    final value = input[field];
    final fieldSchema = schema[field] as Map<String, dynamic>?;

    if (fieldSchema == null) {
      if (strictMode) {
        errors[field] = ['No schema defined for required field'];
        errorCount++;
      } else {
        warnings[field] = ['No schema defined'];
        warningCount++;
        processed[field] = value;
      }
      continue;
    }

    final expectedType = fieldSchema['type'] as String?;
    var isValid = false;

    if (expectedType == 'string') {
      if (value is String) {
        isValid = true;
        final minLength = fieldSchema['minLength'] as int?;
        final maxLength = fieldSchema['maxLength'] as int?;
        if (minLength != null && value.length < minLength) {
          errors[field] = ['String too short (min: $minLength)'];
          errorCount++;
          continue;
        }
        if (maxLength != null && value.length > maxLength) {
          errors[field] = ['String too long (max: $maxLength)'];
          errorCount++;
          continue;
        }
      } else if (coerceTypes) {
        processed[field] = value.toString();
        isValid = true;
      }
    } else if (expectedType == 'number') {
      if (value is num) {
        isValid = true;
        final min = fieldSchema['min'] as num?;
        final max = fieldSchema['max'] as num?;
        if (min != null && value < min) {
          errors[field] = ['Value below minimum ($min)'];
          errorCount++;
          continue;
        }
        if (max != null && value > max) {
          errors[field] = ['Value above maximum ($max)'];
          errorCount++;
          continue;
        }
      } else if (coerceTypes && value is String) {
        final parsed = num.tryParse(value);
        if (parsed != null) {
          processed[field] = parsed;
          isValid = true;
        }
      }
    } else if (expectedType == 'boolean') {
      if (value is bool) {
        isValid = true;
      } else if (coerceTypes) {
        if (value == 'true' || value == 1) {
          processed[field] = true;
          isValid = true;
        } else if (value == 'false' || value == 0) {
          processed[field] = false;
          isValid = true;
        }
      }
    } else if (expectedType == 'array') {
      if (value is List) {
        isValid = true;
        final minItems = fieldSchema['minItems'] as int?;
        final maxItems = fieldSchema['maxItems'] as int?;
        if (minItems != null && value.length < minItems) {
          errors[field] = ['Array too short (min: $minItems items)'];
          errorCount++;
          continue;
        }
        if (maxItems != null && value.length > maxItems) {
          errors[field] = ['Array too long (max: $maxItems items)'];
          errorCount++;
          continue;
        }
      }
    }

    if (!isValid) {
      errors[field] = ['Type mismatch: expected $expectedType'];
      errorCount++;
    } else if (!processed.containsKey(field)) {
      processed[field] = value;
    }
  }

  // Check optional fields
  for (final field in optionalFields) {
    if (!input.containsKey(field)) continue;
    fieldCount++;
    processed[field] = input[field];
  }

  // Check for extra fields
  if (!allowExtra) {
    final allKnown = {...requiredFields, ...optionalFields};
    for (final key in input.keys) {
      if (!allKnown.contains(key)) {
        if (strictMode) {
          errors[key] = ['Unknown field not allowed'];
          errorCount++;
        } else {
          warnings[key] = ['Unknown field ignored'];
          warningCount++;
          skippedCount++;
        }
      }
    }
  }

  // Check dependencies
  for (final entry in fieldDependencies.entries) {
    final field = entry.key;
    final deps = entry.value;

    if (processed.containsKey(field)) {
      for (final dep in deps) {
        if (!processed.containsKey(dep)) {
          errors[field] = ['Depends on missing field: $dep'];
          errorCount++;
        }
      }
    }
  }

  metadata['fieldCount'] = fieldCount;
  metadata['errorCount'] = errorCount;
  metadata['warningCount'] = warningCount;
  metadata['skippedCount'] = skippedCount;

  return {
    'valid': errorCount == 0,
    'data': processed,
    'errors': errors,
    'warnings': warnings,
    'metadata': metadata,
  };
}

// ============================================================================
// Good Examples: Within Thresholds
// ============================================================================

/// Well-structured function with:
/// - High MI (80+)
/// - Low CC (< 5)
/// - Short LOC (< 20)
bool isValidEmail(String? email) {
  if (email == null || email.isEmpty) return false;
  return email.contains('@') && email.contains('.');
}

/// Another well-structured function
int sumPositive(List<int> numbers) {
  var sum = 0;
  for (final n in numbers) {
    if (n > 0) sum += n;
  }
  return sum;
}

/// Single responsibility, clear purpose
String formatCurrency(double amount, {String symbol = '\$'}) {
  return '$symbol${amount.toStringAsFixed(2)}';
}

// ============================================================================
// Runnable Demo
// ============================================================================

void main() {
  print('=== Metrics-Based Debt Demo ===\n');

  print('1. Default Thresholds:\n');
  print('   Maintainability Index: < 50  → lowMaintainability');
  print('   Cyclomatic Complexity: > 20  → highComplexity');
  print('   Lines of Code:         > 100 → longMethod');

  print('\n2. Severity and Costs:\n');
  print('   lowMaintainability: High (8h × 2.0 = 16h)');
  print('   highComplexity:     Medium (4h × 1.0 = 4h)');
  print('   longMethod:         Medium (4h × 1.0 = 4h)');

  print('\n3. Examples in this file:\n');
  print('   processComplexData:       MI < 50 (low maintainability)');
  print('   categorizeValue:          CC > 20 (high complexity)');
  print('   generateDetailedReport:   LOC > 100 (long method)');
  print('   extremelyComplexValidator: ALL thresholds exceeded');

  print('\n4. Good Examples:\n');
  print('   isValidEmail:    MI 85+, CC 3, LOC 4');
  print('   sumPositive:     MI 80+, CC 2, LOC 6');
  print('   formatCurrency:  MI 90+, CC 1, LOC 2');

  print('\n5. Refactoring Strategies:\n');
  print('   - Extract methods to reduce LOC');
  print('   - Replace conditionals with polymorphism');
  print('   - Use guard clauses for early returns');
  print('   - Apply Single Responsibility Principle');

  print('\nRun "anteater debt -p example/debt" for full analysis.');
}
