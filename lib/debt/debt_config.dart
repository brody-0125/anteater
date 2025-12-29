import 'debt_item.dart';

/// Configuration for technical debt cost calculation.
class DebtCostConfig {
  const DebtCostConfig({
    required this.costs,
    required this.multipliers,
    required this.unit,
    required this.threshold,
    required this.metricsThresholds,
    required this.exclude,
  });

  /// Default configuration based on DCM reference values.
  factory DebtCostConfig.defaults() => const DebtCostConfig(
        costs: {
          DebtType.todo: 4.0,
          DebtType.fixme: 8.0,
          DebtType.ignoreComment: 8.0,
          DebtType.ignoreForFile: 16.0,
          DebtType.asDynamic: 16.0,
          DebtType.deprecated: 2.0,
          DebtType.lowMaintainability: 8.0,
          DebtType.highComplexity: 4.0,
          DebtType.longMethod: 4.0,
          DebtType.duplicateCode: 8.0,
        },
        multipliers: {
          DebtSeverity.critical: 4.0,
          DebtSeverity.high: 2.0,
          DebtSeverity.medium: 1.0,
          DebtSeverity.low: 0.5,
        },
        unit: 'hours',
        threshold: 40.0,
        metricsThresholds: DebtMetricsThresholds(),
        exclude: [],
      );

  /// Create configuration from YAML map.
  factory DebtCostConfig.fromYaml(Map<String, dynamic> yaml) {
    final defaults = DebtCostConfig.defaults();

    final costsYaml = yaml['costs'] as Map<String, dynamic>?;
    final costs = Map<DebtType, double>.from(defaults.costs);

    if (costsYaml != null) {
      for (final entry in costsYaml.entries) {
        final debtType = _parseDebtType(entry.key);
        if (debtType != null && entry.value is num) {
          costs[debtType] = (entry.value as num).toDouble();
        }
      }
    }

    final multipliersYaml = yaml['multipliers'] as Map<String, dynamic>?;
    final multipliers = Map<DebtSeverity, double>.from(defaults.multipliers);

    if (multipliersYaml != null) {
      for (final entry in multipliersYaml.entries) {
        final severity = _parseSeverity(entry.key);
        if (severity != null && entry.value is num) {
          multipliers[severity] = (entry.value as num).toDouble();
        }
      }
    }

    final metricsYaml = yaml['metrics'] as Map<String, dynamic>?;
    final metricsThresholds = metricsYaml != null
        ? DebtMetricsThresholds.fromYaml(metricsYaml)
        : defaults.metricsThresholds;

    final excludeYaml = yaml['exclude'] as List<dynamic>?;
    final exclude =
        excludeYaml?.map((e) => e.toString()).toList() ?? defaults.exclude;

    return DebtCostConfig(
      costs: costs,
      multipliers: multipliers,
      unit: yaml['unit'] as String? ?? defaults.unit,
      threshold: (yaml['threshold'] as num?)?.toDouble() ?? defaults.threshold,
      metricsThresholds: metricsThresholds,
      exclude: exclude,
    );
  }

  /// Base cost for each debt type (in hours by default).
  final Map<DebtType, double> costs;

  /// Multipliers for each severity level.
  final Map<DebtSeverity, double> multipliers;

  /// Unit of measurement ('hours', 'days', 'story_points').
  final String unit;

  /// Alert threshold - report exceeds if total cost > threshold.
  final double threshold;

  /// Metrics thresholds.
  final DebtMetricsThresholds metricsThresholds;

  /// File patterns to exclude from debt analysis.
  final List<String> exclude;

  static DebtType? _parseDebtType(String key) {
    final normalized = key.replaceAll('-', '').toLowerCase();
    for (final type in DebtType.values) {
      if (type.name.toLowerCase() == normalized) return type;
    }
    // Handle common aliases
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

  static DebtSeverity? _parseSeverity(String key) {
    final normalized = key.toLowerCase();
    for (final severity in DebtSeverity.values) {
      if (severity.name.toLowerCase() == normalized) return severity;
    }
    return null;
  }

  /// Get cost for a debt type.
  double getCost(DebtType type) => costs[type] ?? 0.0;

  /// Get multiplier for a severity level.
  double getMultiplier(DebtSeverity severity) => multipliers[severity] ?? 1.0;

  /// Convert to JSON map.
  Map<String, dynamic> toJson() => {
        'costs':
            costs.map((type, cost) => MapEntry(type.name, cost)),
        'multipliers':
            multipliers.map((sev, mult) => MapEntry(sev.name, mult)),
        'unit': unit,
        'threshold': threshold,
        'metricsThresholds': metricsThresholds.toJson(),
        'exclude': exclude,
      };
}

/// Thresholds for metrics-based debt detection.
class DebtMetricsThresholds {
  const DebtMetricsThresholds({
    this.maintainabilityIndex = 50.0,
    this.cyclomaticComplexity = 20,
    this.cognitiveComplexity = 15,
    this.linesOfCode = 100,
  });

  factory DebtMetricsThresholds.fromYaml(Map<String, dynamic> yaml) =>
      DebtMetricsThresholds(
        maintainabilityIndex:
            (yaml['maintainability-index'] as num?)?.toDouble() ?? 50.0,
        cyclomaticComplexity: yaml['cyclomatic-complexity'] as int? ?? 20,
        cognitiveComplexity: yaml['cognitive-complexity'] as int? ?? 15,
        linesOfCode: yaml['lines-of-code'] as int? ?? 100,
      );

  final double maintainabilityIndex;
  final int cyclomaticComplexity;
  final int cognitiveComplexity;
  final int linesOfCode;

  Map<String, dynamic> toJson() => {
        'maintainabilityIndex': maintainabilityIndex,
        'cyclomaticComplexity': cyclomaticComplexity,
        'cognitiveComplexity': cognitiveComplexity,
        'linesOfCode': linesOfCode,
      };
}
