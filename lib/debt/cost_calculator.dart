import 'debt_config.dart';
import 'debt_item.dart';

/// Calculates the cost of technical debt items.
class DebtCostCalculator {
  DebtCostCalculator({DebtCostConfig? config})
      : config = config ?? DebtCostConfig.defaults();

  final DebtCostConfig config;

  /// Calculate cost for a single debt item.
  double calculateItemCost(DebtItem item) {
    final baseCost = config.getCost(item.type);
    final multiplier = config.getMultiplier(item.severity);
    return baseCost * multiplier;
  }

  /// Calculate total cost and summary for all items.
  DebtSummary calculateTotal(List<DebtItem> items) {
    var totalCost = 0.0;
    final byType = <DebtType, DebtTypeSummary>{};
    final bySeverity = <DebtSeverity, double>{};

    for (final item in items) {
      final cost = calculateItemCost(item);
      totalCost += cost;

      // Aggregate by type
      final typeSummary = byType[item.type] ??
          DebtTypeSummary(type: item.type, count: 0, cost: 0);
      byType[item.type] = DebtTypeSummary(
        type: item.type,
        count: typeSummary.count + 1,
        cost: typeSummary.cost + cost,
      );

      // Aggregate by severity
      bySeverity[item.severity] =
          (bySeverity[item.severity] ?? 0) + cost;
    }

    return DebtSummary(
      totalCost: totalCost,
      costByType: byType,
      costBySeverity: bySeverity,
      itemCount: items.length,
      unit: config.unit,
      threshold: config.threshold,
    );
  }
}

/// Summary of calculated debt costs.
class DebtSummary {
  const DebtSummary({
    required this.totalCost,
    required this.costByType,
    required this.costBySeverity,
    required this.itemCount,
    required this.unit,
    required this.threshold,
  });

  /// Total cost of all debt items.
  final double totalCost;

  /// Cost breakdown by debt type.
  final Map<DebtType, DebtTypeSummary> costByType;

  /// Cost breakdown by severity.
  final Map<DebtSeverity, double> costBySeverity;

  /// Total number of debt items.
  final int itemCount;

  /// Unit of measurement.
  final String unit;

  /// Threshold for alerts.
  final double threshold;

  /// Whether the total cost exceeds the threshold.
  bool get exceedsThreshold => totalCost > threshold;

  /// Get cost for a specific type.
  double getCostForType(DebtType type) => costByType[type]?.cost ?? 0;

  /// Get count for a specific type.
  int getCountForType(DebtType type) => costByType[type]?.count ?? 0;

  /// Get cost for a specific severity.
  double getCostForSeverity(DebtSeverity severity) =>
      costBySeverity[severity] ?? 0;

  /// Get types sorted by cost (highest first).
  List<DebtTypeSummary> get typesByHighestCost {
    final types = costByType.values.toList();
    types.sort((a, b) => b.cost.compareTo(a.cost));
    return types;
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() => {
        'totalCost': totalCost,
        'itemCount': itemCount,
        'unit': unit,
        'threshold': threshold,
        'exceedsThreshold': exceedsThreshold,
        'costByType': costByType.map(
          (type, summary) => MapEntry(type.name, summary.toJson()),
        ),
        'costBySeverity': costBySeverity.map(
          (severity, cost) => MapEntry(severity.name, cost),
        ),
      };

  @override
  String toString() => '''
DebtSummary(
  Total: $totalCost $unit
  Items: $itemCount
  Status: ${exceedsThreshold ? 'EXCEEDS THRESHOLD' : 'OK'}
)''';
}

/// Summary for a specific debt type.
class DebtTypeSummary {
  const DebtTypeSummary({
    required this.type,
    required this.count,
    required this.cost,
  });

  /// The debt type.
  final DebtType type;

  /// Number of items of this type.
  final int count;

  /// Total cost for this type.
  final double cost;

  /// Convert to JSON map.
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'label': type.label,
        'count': count,
        'cost': cost,
      };

  @override
  String toString() => '${type.label}: $count items, $cost cost';
}
