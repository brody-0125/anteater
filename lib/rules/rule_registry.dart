import 'rule.dart';
import 'rules/safety/avoid_dynamic_rule.dart';
import 'rules/safety/avoid_global_state_rule.dart';
import 'rules/safety/avoid_late_keyword_rule.dart';
import 'rules/safety/no_empty_block_rule.dart';
import 'rules/safety/no_equal_then_else_rule.dart';
import 'rules/quality/avoid_unnecessary_cast_rule.dart';
import 'rules/quality/binary_expression_order_rule.dart';
import 'rules/quality/prefer_async_await_rule.dart';
import 'rules/quality/prefer_first_last_rule.dart';
import 'rules/quality/prefer_trailing_comma_rule.dart';

/// Registry for style rules.
///
/// Manages rule registration, lookup, and configuration.
/// Provides access to all available rules and their enabled state.
class RuleRegistry {
  /// Creates an empty registry.
  RuleRegistry();

  /// Creates a registry with default rules.
  factory RuleRegistry.withDefaults() {
    final registry = RuleRegistry();
    registry.registerBuiltInRules();
    return registry;
  }

  /// All registered rules indexed by ID.
  final Map<String, StyleRule> _rules = {};

  /// Rule settings indexed by rule ID.
  final Map<String, RuleSettings> _settings = {};

  /// Registers a single rule.
  void register(StyleRule rule) {
    _rules[rule.id] = rule;
    // Default to enabled if no setting exists
    _settings.putIfAbsent(rule.id, () => RuleSettings.defaultEnabled);
  }

  /// Registers multiple rules.
  void registerAll(Iterable<StyleRule> rules) {
    for (final rule in rules) {
      register(rule);
    }
  }

  /// Registers all built-in rules.
  ///
  /// This is called automatically by [RuleRegistry.withDefaults].
  void registerBuiltInRules() {
    // Safety rules
    registerAll([
      AvoidDynamicRule(),
      AvoidGlobalStateRule(),
      AvoidLateKeywordRule(),
      NoEmptyBlockRule(),
      NoEqualThenElseRule(),
    ]);

    // Quality rules
    registerAll([
      PreferAsyncAwaitRule(),
      PreferFirstLastRule(),
      PreferTrailingCommaRule(),
      BinaryExpressionOrderRule(),
      AvoidUnnecessaryCastRule(),
    ]);
  }

  /// Gets a rule by ID.
  StyleRule? get(String id) => _rules[id];

  /// Gets all registered rules.
  Iterable<StyleRule> get allRules => _rules.values;

  /// Gets all rule IDs.
  Iterable<String> get ruleIds => _rules.keys;

  /// Gets the number of registered rules.
  int get ruleCount => _rules.length;

  /// Checks if a rule is registered.
  bool contains(String id) => _rules.containsKey(id);

  /// Gets enabled rules.
  Iterable<StyleRule> get enabledRules {
    return _rules.entries
        .where((entry) => isEnabled(entry.key))
        .map((entry) => entry.value);
  }

  /// Gets rules by category.
  Iterable<StyleRule> getRulesByCategory(RuleCategory category) {
    return _rules.values.where((rule) => rule.category == category);
  }

  /// Checks if a rule is enabled.
  bool isEnabled(String ruleId) {
    return _settings[ruleId]?.enabled ?? true;
  }

  /// Enables a rule.
  void enable(String ruleId) {
    final current = _settings[ruleId] ?? RuleSettings.defaultEnabled;
    _settings[ruleId] = RuleSettings(
      enabled: true,
      severity: current.severity,
      options: current.options,
      exclude: current.exclude,
    );
  }

  /// Disables a rule.
  void disable(String ruleId) {
    final current = _settings[ruleId] ?? RuleSettings.defaultEnabled;
    _settings[ruleId] = RuleSettings(
      enabled: false,
      severity: current.severity,
      options: current.options,
      exclude: current.exclude,
    );
  }

  /// Gets settings for a rule.
  RuleSettings getSettings(String ruleId) {
    return _settings[ruleId] ?? RuleSettings.defaultEnabled;
  }

  /// Sets settings for a rule.
  void setSettings(String ruleId, RuleSettings settings) {
    _settings[ruleId] = settings;
  }

  /// Gets the effective severity for a rule.
  ///
  /// Returns the override severity if set, otherwise the default.
  RuleSeverity getSeverity(String ruleId) {
    final settings = _settings[ruleId];
    if (settings?.severity != null) {
      return settings!.severity!;
    }
    return _rules[ruleId]?.defaultSeverity ?? RuleSeverity.warning;
  }

  /// Sets severity override for a rule.
  void setSeverity(String ruleId, RuleSeverity severity) {
    final current = _settings[ruleId] ?? RuleSettings.defaultEnabled;
    _settings[ruleId] = RuleSettings(
      enabled: current.enabled,
      severity: severity,
      options: current.options,
      exclude: current.exclude,
    );
  }

  /// Gets options for a rule.
  Map<String, dynamic> getOptions(String ruleId) {
    return _settings[ruleId]?.options ?? {};
  }

  /// Gets exclude patterns for a rule.
  List<String> getExcludePatterns(String ruleId) {
    return _settings[ruleId]?.exclude ?? [];
  }

  /// Clears all settings (rules remain registered).
  void clearSettings() {
    _settings.clear();
  }

  /// Clears all rules and settings.
  void clear() {
    _rules.clear();
    _settings.clear();
  }

  /// Applies configuration from a map.
  ///
  /// Expected format:
  /// ```yaml
  /// rules:
  ///   - avoid-dynamic
  ///   - prefer-async-await:
  ///       severity: warning
  ///       exclude:
  ///         - test/**
  /// ```
  void applyConfig(Map<String, dynamic> config) {
    final rules = config['rules'];
    if (rules is! List) return;

    for (final entry in rules) {
      if (entry is String) {
        // Simple enable: - avoid-dynamic
        enable(entry);
      } else if (entry is Map<String, dynamic>) {
        // With options: - avoid-dynamic: { severity: warning }
        for (final ruleEntry in entry.entries) {
          final ruleId = ruleEntry.key;
          final options = ruleEntry.value;

          if (options is Map<String, dynamic>) {
            _applyRuleOptions(ruleId, options);
          } else if (options == true) {
            enable(ruleId);
          } else if (options == false) {
            disable(ruleId);
          }
        }
      }
    }
  }

  void _applyRuleOptions(String ruleId, Map<String, dynamic> options) {
    final excludeList = options['exclude'];
    final exclude = excludeList is List
        ? excludeList.map((e) => e.toString()).toList()
        : <String>[];

    final severityStr = options['severity'];
    RuleSeverity? severity;
    if (severityStr is String) {
      severity = _parseSeverity(severityStr);
    }

    final ruleOptions = Map<String, dynamic>.from(options)
      ..remove('severity')
      ..remove('exclude');

    _settings[ruleId] = RuleSettings(
      enabled: true,
      severity: severity,
      options: ruleOptions,
      exclude: exclude,
    );
  }

  RuleSeverity? _parseSeverity(String value) {
    switch (value.toLowerCase()) {
      case 'error':
        return RuleSeverity.error;
      case 'warning':
        return RuleSeverity.warning;
      case 'info':
        return RuleSeverity.info;
      case 'hint':
        return RuleSeverity.hint;
      default:
        return null;
    }
  }

  /// Summary of registered rules for debugging.
  @override
  String toString() {
    final enabled = enabledRules.length;
    return 'RuleRegistry(${_rules.length} rules, $enabled enabled)';
  }
}
