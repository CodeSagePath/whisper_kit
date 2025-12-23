/// A/B testing framework for experiments.
///
/// Run experiments with different configurations.
library;

import 'dart:math';

/// Experiment variant.
class Variant {
  const Variant({
    required this.name,
    this.weight = 1.0,
    this.config,
  });

  /// Variant name (e.g., "control", "treatment").
  final String name;

  /// Weight for random assignment (higher = more likely).
  final double weight;

  /// Variant-specific configuration.
  final Map<String, dynamic>? config;
}

/// Experiment definition.
class Experiment {
  const Experiment({
    required this.id,
    required this.variants,
    this.description,
    this.startDate,
    this.endDate,
    this.targetPercentage = 100,
  });

  /// Unique experiment ID.
  final String id;

  /// Available variants.
  final List<Variant> variants;

  /// Experiment description.
  final String? description;

  /// When experiment starts.
  final DateTime? startDate;

  /// When experiment ends.
  final DateTime? endDate;

  /// Percentage of users to include (0-100).
  final int targetPercentage;

  /// Check if experiment is active.
  bool get isActive {
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }
}

/// User's assigned variant for an experiment.
class Assignment {
  const Assignment({
    required this.experimentId,
    required this.variantName,
    required this.assignedAt,
  });

  final String experimentId;
  final String variantName;
  final DateTime assignedAt;

  Map<String, dynamic> toJson() => {
        'experimentId': experimentId,
        'variantName': variantName,
        'assignedAt': assignedAt.toIso8601String(),
      };

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      experimentId: json['experimentId'] as String,
      variantName: json['variantName'] as String,
      assignedAt: DateTime.parse(json['assignedAt'] as String),
    );
  }
}

/// A/B testing manager.
class ABTesting {
  ABTesting._();

  static ABTesting? _instance;

  /// Singleton instance.
  static ABTesting get instance {
    _instance ??= ABTesting._();
    return _instance!;
  }

  final Map<String, Experiment> _experiments = {};
  final Map<String, Assignment> _assignments = {};
  final Random _random = Random();
  String? _userId;

  /// Set user ID for consistent assignment.
  void setUserId(String userId) {
    _userId = userId;
  }

  /// Register an experiment.
  void registerExperiment(Experiment experiment) {
    _experiments[experiment.id] = experiment;
  }

  /// Get assigned variant for an experiment.
  String? getVariant(String experimentId) {
    // Check existing assignment
    final existing = _assignments[experimentId];
    if (existing != null) return existing.variantName;

    // Get experiment
    final experiment = _experiments[experimentId];
    if (experiment == null || !experiment.isActive) return null;

    // Check target percentage
    if (_random.nextInt(100) >= experiment.targetPercentage) {
      return null;
    }

    // Assign variant
    final variant = _assignVariant(experiment);
    _assignments[experimentId] = Assignment(
      experimentId: experimentId,
      variantName: variant.name,
      assignedAt: DateTime.now(),
    );

    return variant.name;
  }

  /// Get variant configuration.
  Map<String, dynamic>? getVariantConfig(String experimentId) {
    final variantName = getVariant(experimentId);
    if (variantName == null) return null;

    final experiment = _experiments[experimentId];
    final variant = experiment?.variants.firstWhere(
      (v) => v.name == variantName,
      orElse: () => const Variant(name: ''),
    );

    return variant?.config;
  }

  /// Check if user is in specific variant.
  bool isInVariant(String experimentId, String variantName) {
    return getVariant(experimentId) == variantName;
  }

  /// Force a specific variant (for testing).
  void forceVariant(String experimentId, String variantName) {
    _assignments[experimentId] = Assignment(
      experimentId: experimentId,
      variantName: variantName,
      assignedAt: DateTime.now(),
    );
  }

  /// Clear all assignments.
  void clearAssignments() {
    _assignments.clear();
  }

  /// Get all assignments.
  Map<String, String> getAllAssignments() {
    return _assignments.map((k, v) => MapEntry(k, v.variantName));
  }

  /// Export assignments for persistence.
  List<Map<String, dynamic>> exportAssignments() {
    return _assignments.values.map((a) => a.toJson()).toList();
  }

  /// Import assignments from persistence.
  void importAssignments(List<Map<String, dynamic>> data) {
    for (final json in data) {
      final assignment = Assignment.fromJson(json);
      _assignments[assignment.experimentId] = assignment;
    }
  }

  Variant _assignVariant(Experiment experiment) {
    // Calculate total weight
    final totalWeight = experiment.variants.fold<double>(
      0,
      (sum, v) => sum + v.weight,
    );

    // Generate random value based on user ID or random
    double randomValue;
    if (_userId != null) {
      // Consistent assignment based on user ID + experiment ID
      final hash = '${_userId}_${experiment.id}'.hashCode;
      randomValue = (hash.abs() % 1000) / 1000.0;
    } else {
      randomValue = _random.nextDouble();
    }

    // Select variant
    var cumulative = 0.0;
    for (final variant in experiment.variants) {
      cumulative += variant.weight / totalWeight;
      if (randomValue < cumulative) {
        return variant;
      }
    }

    return experiment.variants.last;
  }
}
