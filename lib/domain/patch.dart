/// Distinguishes "leave this field alone" from "set this field to null".
///
/// A `copyWith` that takes a plain nullable parameter cannot express clearing:
/// `value ?? this.value` reads an explicit null as "no change". The usual
/// workaround is an `Object?` sentinel, but that erases the field's type — an
/// `int` passed where a `double?` belongs then compiles cleanly and fails at
/// runtime. Wrapping the value keeps the type.
///
/// ```dart
/// draft.copyWith(target: const Patch(74.0)); // set
/// draft.copyWith(target: const Patch.clear()); // set to null
/// draft.copyWith(weightKg: 79); // target untouched
/// ```
class Patch<T extends Object> {
  const Patch(this.value);

  /// Sets the field to null.
  const Patch.clear() : value = null;

  final T? value;

  @override
  bool operator ==(Object other) => other is Patch<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Patch<T>, value);

  @override
  String toString() => value == null ? 'Patch.clear()' : 'Patch($value)';
}

/// Applies [patch] to [current]: unchanged when the patch is absent.
T? applyPatch<T extends Object>(Patch<T>? patch, T? current) =>
    patch == null ? current : patch.value;
