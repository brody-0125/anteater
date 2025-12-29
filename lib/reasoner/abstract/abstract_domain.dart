import 'dart:math' as math;

/// Base class for abstract domains used in abstract interpretation.
///
/// An abstract domain provides a way to approximate program states
/// for static analysis while ensuring termination through widening.
abstract class AbstractDomain<T extends AbstractDomain<T>> {
  /// Join operation (⊔): least upper bound of two abstract values.
  T join(T other);

  /// Meet operation (⊓): greatest lower bound of two abstract values.
  T meet(T other);

  /// Widening operation (∇): ensures termination in fixpoint iteration.
  T widen(T other);

  /// Narrowing operation (△): refines over-approximation after widening.
  T narrow(T other);

  /// Checks if this value is less than or equal to another (⊑).
  bool isSubsetOf(T other);

  /// Returns the bottom element (⊥).
  T get bottom;

  /// Returns the top element (⊤).
  T get top;

  /// Checks if this is the bottom element.
  bool get isBottom;

  /// Checks if this is the top element.
  bool get isTop;
}

/// Interval domain for tracking integer value ranges.
///
/// Represents values as [min, max] where min, max ∈ ℤ ∪ {-∞, +∞}.
/// Used for array bounds checking and integer overflow detection.
class IntervalDomain implements AbstractDomain<IntervalDomain> {
  const IntervalDomain(this.min, this.max);

  const IntervalDomain._bottom()
      : min = 1,
        max = 0; // Represents empty interval

  /// Creates an interval from a single constant.
  factory IntervalDomain.constant(int value) => IntervalDomain(value, value);

  /// Creates an interval [0, n-1] for array indices.
  factory IntervalDomain.arrayIndex(int length) =>
      IntervalDomain(0, length - 1);

  final int? min; // null represents -∞
  final int? max; // null represents +∞

  /// Bottom element (empty interval).
  static const IntervalDomain bottomValue = IntervalDomain._bottom();

  /// Top element (all integers).
  static const IntervalDomain topValue = IntervalDomain(null, null);

  @override
  bool get isBottom => min != null && max != null && min! > max!;

  @override
  bool get isTop => min == null && max == null;

  @override
  IntervalDomain get bottom => bottomValue;

  @override
  IntervalDomain get top => topValue;

  @override
  IntervalDomain join(IntervalDomain other) {
    if (isBottom) return other;
    if (other.isBottom) return this;

    return IntervalDomain(
      _minNullable(min, other.min),
      _maxNullable(max, other.max),
    );
  }

  @override
  IntervalDomain meet(IntervalDomain other) {
    if (isBottom || other.isBottom) return bottomValue;

    final newMin = _maxNullable(min, other.min);
    final newMax = _minNullable(max, other.max);

    if (newMin != null && newMax != null && newMin > newMax) {
      return bottomValue;
    }

    return IntervalDomain(newMin, newMax);
  }

  @override
  IntervalDomain widen(IntervalDomain other) {
    if (isBottom) return other;
    if (other.isBottom) return this;

    // Widen: if bound is growing, jump to infinity
    final newMin = (other.min != null && min != null && other.min! < min!)
        ? null // -∞
        : min;
    final newMax = (other.max != null && max != null && other.max! > max!)
        ? null // +∞
        : max;

    return IntervalDomain(newMin, newMax);
  }

  @override
  IntervalDomain narrow(IntervalDomain other) {
    if (isBottom) return bottomValue;
    if (other.isBottom) return bottomValue;

    // Narrow: replace infinity with finite bound from other
    final newMin = (min == null && other.min != null) ? other.min : min;
    final newMax = (max == null && other.max != null) ? other.max : max;

    return IntervalDomain(newMin, newMax);
  }

  @override
  bool isSubsetOf(IntervalDomain other) {
    if (isBottom) return true;
    if (other.isTop) return true;

    final minOk = other.min == null || (min != null && min! >= other.min!);
    final maxOk = other.max == null || (max != null && max! <= other.max!);

    return minOk && maxOk;
  }

  // Arithmetic operations
  IntervalDomain add(IntervalDomain other) {
    if (isBottom || other.isBottom) return bottomValue;

    return IntervalDomain(
      _addNullable(min, other.min),
      _addNullable(max, other.max),
    );
  }

  IntervalDomain subtract(IntervalDomain other) {
    if (isBottom || other.isBottom) return bottomValue;

    return IntervalDomain(
      _subtractNullable(min, other.max),
      _subtractNullable(max, other.min),
    );
  }

  IntervalDomain multiply(IntervalDomain other) {
    if (isBottom || other.isBottom) return bottomValue;

    // If either operand is top, result is top
    if (isTop || other.isTop) return topValue;

    // Handle infinity cases conservatively
    if (min == null || max == null || other.min == null || other.max == null) {
      return _multiplyWithInfinity(other);
    }

    // All bounds are finite - compute all corner products
    final products = <int>[
      min! * other.min!,
      min! * other.max!,
      max! * other.min!,
      max! * other.max!,
    ];

    return IntervalDomain(
      products.reduce(math.min),
      products.reduce(math.max),
    );
  }

  /// Handles multiplication when one or more bounds are infinite.
  IntervalDomain _multiplyWithInfinity(IntervalDomain other) {
    // Check if either interval contains zero
    final thisContainsZero =
        (min == null || min! <= 0) && (max == null || max! >= 0);
    final otherContainsZero =
        (other.min == null || other.min! <= 0) &&
            (other.max == null || other.max! >= 0);

    // If zero is involved, result could swing between -∞ and +∞
    if (thisContainsZero || otherContainsZero) {
      return topValue;
    }

    // Determine signs: both intervals are same-sign (no zero crossing)
    final thisPositive = min != null && min! > 0;
    final otherPositive = other.min != null && other.min! > 0;

    // Compute new bounds based on sign combinations
    int? newMin;
    int? newMax;

    if (thisPositive && otherPositive) {
      // Positive * Positive = Positive
      newMin = _multiplyNullable(min, other.min);
      newMax = _multiplyNullable(max, other.max);
    } else if (!thisPositive && !otherPositive) {
      // Negative * Negative = Positive
      newMin = _multiplyNullable(max, other.max);
      newMax = _multiplyNullable(min, other.min);
    } else if (thisPositive && !otherPositive) {
      // Positive * Negative = Negative
      newMin = _multiplyNullable(max, other.min);
      newMax = _multiplyNullable(min, other.max);
    } else {
      // Negative * Positive = Negative
      newMin = _multiplyNullable(min, other.max);
      newMax = _multiplyNullable(max, other.min);
    }

    return IntervalDomain(newMin, newMax);
  }

  /// Integer division of two intervals.
  ///
  /// Returns top if the divisor interval contains zero (division by zero possible).
  IntervalDomain divide(IntervalDomain other) {
    if (isBottom || other.isBottom) return bottomValue;

    // If either operand is top, result is top
    if (isTop || other.isTop) return topValue;

    // Division by interval containing zero is undefined
    if (other.containsValue(0)) {
      return topValue;
    }

    // Handle infinity cases conservatively
    if (min == null || max == null || other.min == null || other.max == null) {
      return _divideWithInfinity(other);
    }

    // All bounds are finite and divisor doesn't contain zero
    // Compute all corner quotients using truncating division
    final quotients = <int>[
      min! ~/ other.min!,
      min! ~/ other.max!,
      max! ~/ other.min!,
      max! ~/ other.max!,
    ];

    return IntervalDomain(
      quotients.reduce(math.min),
      quotients.reduce(math.max),
    );
  }

  /// Handles division when one or more bounds are infinite.
  IntervalDomain _divideWithInfinity(IntervalDomain other) {
    // Divisor doesn't contain zero (checked by caller)
    final divisorPositive = other.min != null && other.min! > 0;

    // If dividend contains both positive and negative infinity,
    // result spans -∞ to +∞
    if (min == null && max == null) {
      return topValue;
    }

    // Determine result signs based on dividend and divisor signs
    if (divisorPositive) {
      // Dividing by positive: result has same sign as dividend
      return IntervalDomain(
        min == null ? null : (other.max != null ? min! ~/ other.max! : 0),
        max == null ? null : (other.min != null ? max! ~/ other.min! : 0),
      );
    } else {
      // Dividing by negative: result has opposite sign
      return IntervalDomain(
        max == null ? null : (other.min != null ? max! ~/ other.min! : 0),
        min == null ? null : (other.max != null ? min! ~/ other.max! : 0),
      );
    }
  }

  /// Modulo operation on two intervals.
  ///
  /// Returns top if the divisor interval contains zero.
  IntervalDomain modulo(IntervalDomain other) {
    if (isBottom || other.isBottom) return bottomValue;

    // Modulo by interval containing zero is undefined
    if (other.containsValue(0)) {
      return topValue;
    }

    // If either is infinite, result is bounded by divisor
    if (min == null || max == null || other.min == null || other.max == null) {
      // Result of a % b is in range [0, |b|-1] for positive a
      // or [-(|b|-1), |b|-1] for possibly negative a
      final maxDivisor = other.max?.abs();
      if (maxDivisor == null) return topValue;

      if (min != null && min! >= 0) {
        // Non-negative dividend: result is in [0, |b|-1]
        return IntervalDomain(0, maxDivisor - 1);
      }
      // Possibly negative dividend: result spans negative to positive
      return IntervalDomain(-(maxDivisor - 1), maxDivisor - 1);
    }

    // All bounds are finite
    final maxDivisor = math.max(other.min!.abs(), other.max!.abs());
    if (min! >= 0) {
      // Non-negative dividend
      return IntervalDomain(0, math.min(max!, maxDivisor - 1));
    } else if (max! < 0) {
      // Strictly negative dividend
      return IntervalDomain(math.max(min!, -(maxDivisor - 1)), 0);
    } else {
      // Spans zero
      return IntervalDomain(
        math.max(min!, -(maxDivisor - 1)),
        math.min(max!, maxDivisor - 1),
      );
    }
  }

  /// Checks if this interval contains a specific value.
  bool containsValue(int value) {
    if (isBottom) return false;
    if (min != null && value < min!) return false;
    if (max != null && value > max!) return false;
    return true;
  }

  /// Checks if this interval satisfies a < b relation.
  bool isLessThan(IntervalDomain other) {
    if (isBottom || other.isBottom) return false;
    if (max == null || other.min == null) return false;
    return max! < other.min!;
  }

  /// Checks if value is definitely within bounds [0, length).
  bool isValidArrayIndex(int length) {
    if (isBottom) return true; // vacuously true
    if (min == null || min! < 0) return false;
    if (max == null || max! >= length) return false;
    return true;
  }

  // Helper functions for nullable arithmetic
  int? _minNullable(int? a, int? b) {
    if (a == null) return null;
    if (b == null) return null;
    return math.min(a, b);
  }

  int? _maxNullable(int? a, int? b) {
    if (a == null) return null;
    if (b == null) return null;
    return math.max(a, b);
  }

  int? _addNullable(int? a, int? b) {
    if (a == null || b == null) return null;
    return a + b;
  }

  int? _subtractNullable(int? a, int? b) {
    if (a == null || b == null) return null;
    return a - b;
  }

  int? _multiplyNullable(int? a, int? b) {
    if (a == null || b == null) return null;
    return a * b;
  }

  @override
  String toString() {
    if (isBottom) return '⊥';
    final minStr = min?.toString() ?? '-∞';
    final maxStr = max?.toString() ?? '+∞';
    return '[$minStr, $maxStr]';
  }

  @override
  bool operator ==(Object other) =>
      other is IntervalDomain && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);
}

/// Abstract state mapping variables to their abstract values.
class AbstractState<D extends AbstractDomain<D>> {
  AbstractState(this._defaultValue, [Map<String, D>? values])
      : _values = values ?? {};

  final D _defaultValue;
  final Map<String, D> _values;

  /// Returns the value for a variable, or TOP if not defined.
  D operator [](String variable) => _values[variable] ?? _defaultValue.top;

  /// Returns the value for a variable during join operations.
  /// Returns BOTTOM if the variable is not defined in this state.
  D getForJoin(String variable) => _values[variable] ?? _defaultValue.bottom;

  void operator []=(String variable, D value) {
    _values[variable] = value;
  }

  AbstractState<D> join(AbstractState<D> other) {
    final result = <String, D>{};
    final allVars = {..._values.keys, ...other._values.keys};

    for (final v in allVars) {
      // Use getForJoin to treat missing variables as BOTTOM
      // This ensures that unprocessed predecessors don't pollute the join
      final thisVal = getForJoin(v);
      final otherVal = other.getForJoin(v);
      result[v] = thisVal.join(otherVal);
    }

    return AbstractState(_defaultValue, result);
  }

  AbstractState<D> widen(AbstractState<D> other) {
    final result = <String, D>{};
    final allVars = {..._values.keys, ...other._values.keys};

    for (final v in allVars) {
      // Use getForJoin for consistent handling of missing variables
      final thisVal = getForJoin(v);
      final otherVal = other.getForJoin(v);
      result[v] = thisVal.widen(otherVal);
    }

    return AbstractState(_defaultValue, result);
  }

  /// Narrows this state with another to recover precision after widening.
  AbstractState<D> narrow(AbstractState<D> other) {
    final result = <String, D>{};
    final allVars = {..._values.keys, ...other._values.keys};

    for (final v in allVars) {
      final thisVal = getForJoin(v);
      final otherVal = other.getForJoin(v);
      result[v] = thisVal.narrow(otherVal);
    }

    return AbstractState(_defaultValue, result);
  }

  @override
  String toString() {
    return _values.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  Map<String, D> get values => Map.unmodifiable(_values);
}

/// Nullability states for null safety analysis.
enum Nullability {
  /// Definitely null
  definitelyNull,

  /// Definitely non-null
  definitelyNonNull,

  /// May be null or non-null
  maybeNull,

  /// Unreachable/bottom
  bottom,
}

/// Nullability domain for tracking null/non-null states of variables.
///
/// Used for null safety verification and detecting potential null dereferences.
class NullabilityDomain implements AbstractDomain<NullabilityDomain> {
  const NullabilityDomain(this.state);

  final Nullability state;

  /// Bottom element (unreachable).
  static const NullabilityDomain bottomValue =
      NullabilityDomain(Nullability.bottom);

  /// Top element (may be null).
  static const NullabilityDomain topValue =
      NullabilityDomain(Nullability.maybeNull);

  /// Definitely null constant.
  static const NullabilityDomain nullValue =
      NullabilityDomain(Nullability.definitelyNull);

  /// Definitely non-null constant.
  static const NullabilityDomain nonNullValue =
      NullabilityDomain(Nullability.definitelyNonNull);

  @override
  bool get isBottom => state == Nullability.bottom;

  @override
  bool get isTop => state == Nullability.maybeNull;

  @override
  NullabilityDomain get bottom => bottomValue;

  @override
  NullabilityDomain get top => topValue;

  /// Whether this state definitely represents null.
  bool get isDefinitelyNull => state == Nullability.definitelyNull;

  /// Whether this state definitely represents non-null.
  bool get isDefinitelyNonNull => state == Nullability.definitelyNonNull;

  /// Whether this state may be null (including definitely null).
  bool get mayBeNull =>
      state == Nullability.maybeNull || state == Nullability.definitelyNull;

  @override
  NullabilityDomain join(NullabilityDomain other) {
    if (isBottom) return other;
    if (other.isBottom) return this;

    // Join lattice:
    //       maybeNull (top)
    //      /          \
    // definitelyNull  definitelyNonNull
    //      \          /
    //        bottom
    if (state == other.state) return this;
    return topValue; // Different non-bottom states join to top
  }

  @override
  NullabilityDomain meet(NullabilityDomain other) {
    if (isBottom || other.isBottom) return bottomValue;

    if (state == other.state) return this;
    if (state == Nullability.maybeNull) return other;
    if (other.state == Nullability.maybeNull) return this;

    // definitelyNull meet definitelyNonNull = bottom
    return bottomValue;
  }

  @override
  NullabilityDomain widen(NullabilityDomain other) {
    // Nullability domain is finite, so widening is just join
    return join(other);
  }

  @override
  NullabilityDomain narrow(NullabilityDomain other) {
    // Narrowing is meet for finite domains
    return meet(other);
  }

  @override
  bool isSubsetOf(NullabilityDomain other) {
    if (isBottom) return true;
    if (other.isTop) return true;
    return state == other.state;
  }

  /// Applies a null check constraint.
  ///
  /// If we know `x != null`, then x becomes definitelyNonNull.
  NullabilityDomain applyNonNullConstraint() {
    if (isBottom) return bottomValue;
    if (state == Nullability.definitelyNull) {
      return bottomValue; // Contradiction: null != null is false
    }
    return nonNullValue;
  }

  /// Applies a null constraint.
  ///
  /// If we know `x == null`, then x becomes definitelyNull.
  NullabilityDomain applyNullConstraint() {
    if (isBottom) return bottomValue;
    if (state == Nullability.definitelyNonNull) {
      return bottomValue; // Contradiction: nonNull == null is false
    }
    return nullValue;
  }

  @override
  String toString() {
    return switch (state) {
      Nullability.definitelyNull => 'null',
      Nullability.definitelyNonNull => 'non-null',
      Nullability.maybeNull => 'null?',
      Nullability.bottom => '⊥',
    };
  }

  @override
  bool operator ==(Object other) =>
      other is NullabilityDomain && other.state == state;

  @override
  int get hashCode => state.hashCode;
}

/// Combined domain pairing interval and nullability analysis.
///
/// Tracks both the numeric range and null status of variables.
class CombinedDomain implements AbstractDomain<CombinedDomain> {
  const CombinedDomain(this.interval, this.nullability);

  final NullabilityDomain nullability;
  final IntervalDomain interval;

  static const CombinedDomain bottomValue = CombinedDomain(
    IntervalDomain.bottomValue,
    NullabilityDomain.bottomValue,
  );

  static const CombinedDomain topValue = CombinedDomain(
    IntervalDomain.topValue,
    NullabilityDomain.topValue,
  );

  @override
  bool get isBottom => interval.isBottom || nullability.isBottom;

  @override
  bool get isTop => interval.isTop && nullability.isTop;

  @override
  CombinedDomain get bottom => bottomValue;

  @override
  CombinedDomain get top => topValue;

  @override
  CombinedDomain join(CombinedDomain other) {
    return CombinedDomain(
      interval.join(other.interval),
      nullability.join(other.nullability),
    );
  }

  @override
  CombinedDomain meet(CombinedDomain other) {
    return CombinedDomain(
      interval.meet(other.interval),
      nullability.meet(other.nullability),
    );
  }

  @override
  CombinedDomain widen(CombinedDomain other) {
    return CombinedDomain(
      interval.widen(other.interval),
      nullability.widen(other.nullability),
    );
  }

  @override
  CombinedDomain narrow(CombinedDomain other) {
    return CombinedDomain(
      interval.narrow(other.interval),
      nullability.narrow(other.nullability),
    );
  }

  @override
  bool isSubsetOf(CombinedDomain other) {
    return interval.isSubsetOf(other.interval) &&
        nullability.isSubsetOf(other.nullability);
  }

  @override
  String toString() => '($interval, $nullability)';

  @override
  bool operator ==(Object other) =>
      other is CombinedDomain &&
      other.interval == interval &&
      other.nullability == nullability;

  @override
  int get hashCode => Object.hash(interval, nullability);
}
