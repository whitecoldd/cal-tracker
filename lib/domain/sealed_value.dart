/// A value that the app may or may not be permitted to show yet.
///
/// This is the spine of the product. Between week-start and the configured
/// week-end day, the app must never reveal whether the user is losing or
/// gaining weight — see CLAUDE.md §1. Routing every verdict-bearing value
/// through this type means a widget *cannot* render a number it has not
/// unwrapped, and `non_exhaustive_switch_expression` is an analyzer error, so
/// a forgotten branch fails the build rather than leaking a number.
///
/// ```dart
/// final text = switch (balance) {
///   Revealed(:final value) => '${value.round()} kcal',
///   Sealed() => '???',
/// };
/// ```
sealed class SealedValue<T> {
  const SealedValue();

  /// Wraps [value] as revealed.
  const factory SealedValue.revealed(T value) = Revealed<T>;

  /// A value that exists but may not be shown yet.
  const factory SealedValue.sealed() = Sealed<T>;

  bool get isRevealed => this is Revealed<T>;

  /// The value if revealed, otherwise null.
  ///
  /// Prefer an exhaustive `switch` at the UI boundary; this exists for
  /// composing sealed values inside the domain layer.
  T? get valueOrNull => switch (this) {
        Revealed<T>(:final value) => value,
        Sealed<T>() => null,
      };

  /// Applies [transform] without unsealing.
  SealedValue<R> map<R>(R Function(T) transform) => switch (this) {
        Revealed<T>(:final value) => Revealed<R>(transform(value)),
        Sealed<T>() => Sealed<R>(),
      };
}

/// The value is visible.
final class Revealed<T> extends SealedValue<T> {
  const Revealed(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      other is Revealed<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Revealed<T>, value);

  @override
  String toString() => 'Revealed($value)';
}

/// The value exists and is recorded, but the week has not closed.
final class Sealed<T> extends SealedValue<T> {
  const Sealed();

  @override
  bool operator ==(Object other) => other is Sealed<T>;

  @override
  int get hashCode => Object.hash(Sealed, T);

  @override
  String toString() => 'Sealed()';
}
