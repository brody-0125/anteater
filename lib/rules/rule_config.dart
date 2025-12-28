import 'dart:io';

import 'package:yaml/yaml.dart';

import 'rule.dart';
import 'rule_registry.dart';

/// Configuration for style rules.
///
/// Parses YAML configuration and provides rule settings.
class RuleConfig {
  /// Global file patterns to exclude from all rules.
  final List<String> excludePatterns;

  /// Rule-specific settings.
  final Map<String, RuleSettings> ruleSettings;

  /// Metrics thresholds for rule integration.
  final MetricsThresholds metrics;

  const RuleConfig({
    this.excludePatterns = const [],
    this.ruleSettings = const {},
    this.metrics = const MetricsThresholds(),
  });

  /// Creates default configuration.
  factory RuleConfig.defaults() => const RuleConfig();

  /// Parses configuration from YAML content.
  factory RuleConfig.fromYaml(String yamlContent) {
    final yaml = loadYaml(yamlContent);
    if (yaml is! Map) {
      return RuleConfig.defaults();
    }

    return RuleConfig.fromMap(Map<String, dynamic>.from(yaml));
  }

  /// Parses configuration from a Map.
  factory RuleConfig.fromMap(Map<String, dynamic> map) {
    final anteaterConfig = map['anteater'];
    if (anteaterConfig is! Map) {
      return RuleConfig.defaults();
    }

    // Parse exclude patterns
    final excludePatterns = <String>[];
    final excludeList = anteaterConfig['exclude'];
    if (excludeList is List) {
      excludePatterns.addAll(excludeList.map((e) => e.toString()));
    }

    // Parse rule settings
    final ruleSettings = <String, RuleSettings>{};
    final rules = anteaterConfig['rules'];
    if (rules is List) {
      for (final entry in rules) {
        if (entry is String) {
          // Simple enable: - avoid-dynamic
          ruleSettings[entry] = RuleSettings.defaultEnabled;
        } else if (entry is Map) {
          // With options: - avoid-dynamic: { severity: warning }
          for (final ruleEntry in entry.entries) {
            final ruleId = ruleEntry.key.toString();
            final options = ruleEntry.value;
            ruleSettings[ruleId] = _parseRuleSettings(options);
          }
        }
      }
    }

    // Parse metrics thresholds
    final metricsMap = anteaterConfig['metrics'];
    final metrics = metricsMap is Map
        ? MetricsThresholds.fromMap(Map<String, dynamic>.from(metricsMap))
        : const MetricsThresholds();

    return RuleConfig(
      excludePatterns: excludePatterns,
      ruleSettings: ruleSettings,
      metrics: metrics,
    );
  }

  /// Loads configuration from a file.
  static Future<RuleConfig> loadFromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return RuleConfig.defaults();
    }

    final content = await file.readAsString();
    return RuleConfig.fromYaml(content);
  }

  /// Loads configuration from analysis_options.yaml in a directory.
  static Future<RuleConfig> loadFromDirectory(String directory) async {
    final analysisOptionsPath = '$directory/analysis_options.yaml';
    return loadFromFile(analysisOptionsPath);
  }

  /// Checks if a rule is enabled in configuration.
  bool isEnabled(String ruleId) {
    return ruleSettings[ruleId]?.enabled ?? false;
  }

  /// Gets settings for a rule.
  RuleSettings getSettings(String ruleId) {
    return ruleSettings[ruleId] ?? RuleSettings.defaultDisabled;
  }

  /// Gets options for a rule.
  Map<String, dynamic> getOptions(String ruleId) {
    return ruleSettings[ruleId]?.options ?? {};
  }

  /// Gets exclude patterns for a rule.
  List<String> getExcludePatterns(String ruleId) {
    return ruleSettings[ruleId]?.exclude ?? [];
  }

  /// Applies this configuration to a rule registry.
  void applyTo(RuleRegistry registry) {
    for (final entry in ruleSettings.entries) {
      registry.setSettings(entry.key, entry.value);
    }
  }

  /// Parses rule settings from various formats.
  static RuleSettings _parseRuleSettings(dynamic options) {
    if (options == true) {
      return RuleSettings.defaultEnabled;
    }
    if (options == false) {
      return RuleSettings.defaultDisabled;
    }
    if (options is! Map) {
      return RuleSettings.defaultEnabled;
    }

    final optionsMap = Map<String, dynamic>.from(options);

    // Parse exclude list
    final excludeList = optionsMap['exclude'];
    final exclude = excludeList is List
        ? excludeList.map((e) => e.toString()).toList()
        : <String>[];

    // Parse severity
    final severityStr = optionsMap['severity'];
    RuleSeverity? severity;
    if (severityStr is String) {
      severity = _parseSeverity(severityStr);
    }

    // Remaining options (excluding 'severity' and 'exclude')
    final ruleOptions = Map<String, dynamic>.from(optionsMap)
      ..remove('severity')
      ..remove('exclude');

    return RuleSettings(
      enabled: true,
      severity: severity,
      options: ruleOptions,
      exclude: exclude,
    );
  }

  /// Parses severity string to enum.
  static RuleSeverity? _parseSeverity(String value) {
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
}

/// Metrics thresholds for rule integration.
class MetricsThresholds {
  /// Maximum cyclomatic complexity.
  final int cyclomaticComplexity;

  /// Maximum cognitive complexity.
  final int cognitiveComplexity;

  /// Maximum source lines of code per function.
  final int sourceLinesOfCode;

  /// Minimum maintainability index.
  final int maintainabilityIndex;

  /// Maximum nesting level.
  final int maximumNesting;

  /// Maximum number of parameters.
  final int numberOfParameters;

  /// Maximum number of methods per class.
  final int numberOfMethods;

  /// Maximum Halstead volume.
  final int halsteadVolume;

  const MetricsThresholds({
    this.cyclomaticComplexity = 20,
    this.cognitiveComplexity = 15,
    this.sourceLinesOfCode = 50,
    this.maintainabilityIndex = 50,
    this.maximumNesting = 5,
    this.numberOfParameters = 4,
    this.numberOfMethods = 20,
    this.halsteadVolume = 150,
  });

  /// Creates from a map.
  factory MetricsThresholds.fromMap(Map<String, dynamic> map) {
    return MetricsThresholds(
      cyclomaticComplexity:
          _parseInt(map['cyclomatic-complexity'], defaultValue: 20),
      cognitiveComplexity:
          _parseInt(map['cognitive-complexity'], defaultValue: 15),
      sourceLinesOfCode:
          _parseInt(map['source-lines-of-code'], defaultValue: 50),
      maintainabilityIndex:
          _parseInt(map['maintainability-index'], defaultValue: 50),
      maximumNesting: _parseInt(map['maximum-nesting'], defaultValue: 5),
      numberOfParameters:
          _parseInt(map['number-of-parameters'], defaultValue: 4),
      numberOfMethods: _parseInt(map['number-of-methods'], defaultValue: 20),
      halsteadVolume: _parseInt(map['halstead-volume'], defaultValue: 150),
    );
  }

  static int _parseInt(dynamic value, {required int defaultValue}) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Converts to map for serialization.
  Map<String, int> toMap() => {
        'cyclomatic-complexity': cyclomaticComplexity,
        'cognitive-complexity': cognitiveComplexity,
        'source-lines-of-code': sourceLinesOfCode,
        'maintainability-index': maintainabilityIndex,
        'maximum-nesting': maximumNesting,
        'number-of-parameters': numberOfParameters,
        'number-of-methods': numberOfMethods,
        'halstead-volume': halsteadVolume,
      };
}

/// Configuration builder for programmatic setup.
class RuleConfigBuilder {
  final List<String> _excludePatterns = [];
  final Map<String, RuleSettings> _ruleSettings = {};
  MetricsThresholds _metrics = const MetricsThresholds();

  /// Adds a global exclude pattern.
  RuleConfigBuilder exclude(String pattern) {
    _excludePatterns.add(pattern);
    return this;
  }

  /// Adds multiple global exclude patterns.
  RuleConfigBuilder excludeAll(Iterable<String> patterns) {
    _excludePatterns.addAll(patterns);
    return this;
  }

  /// Enables a rule with default settings.
  RuleConfigBuilder enableRule(String ruleId) {
    _ruleSettings[ruleId] = RuleSettings.defaultEnabled;
    return this;
  }

  /// Disables a rule.
  RuleConfigBuilder disableRule(String ruleId) {
    _ruleSettings[ruleId] = RuleSettings.defaultDisabled;
    return this;
  }

  /// Configures a rule with custom settings.
  RuleConfigBuilder configureRule(
    String ruleId, {
    bool enabled = true,
    RuleSeverity? severity,
    Map<String, dynamic>? options,
    List<String>? exclude,
  }) {
    _ruleSettings[ruleId] = RuleSettings(
      enabled: enabled,
      severity: severity,
      options: options ?? const {},
      exclude: exclude ?? const [],
    );
    return this;
  }

  /// Sets metrics thresholds.
  RuleConfigBuilder withMetrics(MetricsThresholds metrics) {
    _metrics = metrics;
    return this;
  }

  /// Builds the configuration.
  RuleConfig build() {
    return RuleConfig(
      excludePatterns: List.unmodifiable(_excludePatterns),
      ruleSettings: Map.unmodifiable(_ruleSettings),
      metrics: _metrics,
    );
  }
}
