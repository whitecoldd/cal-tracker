import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// A labelled numeric input with a unit suffix.
///
/// Validation is deliberately about plausibility rather than correctness: the
/// job is to catch a slipped decimal point or a height typed in metres, not to
/// tell anyone their body is out of range.
class MeasureField extends StatelessWidget {
  const MeasureField({
    required this.label,
    required this.unit,
    required this.controller,
    this.min,
    this.max,
    this.decimal = false,
    this.hint,
    this.helper,
    this.onChanged,
    super.key,
  });

  final String label;
  final String unit;
  final TextEditingController controller;

  /// Plausible range. Outside it the field explains itself rather than
  /// silently refusing.
  final double? min;
  final double? max;

  final bool decimal;
  final String? hint;
  final String? helper;
  final ValueChanged<String>? onChanged;

  /// The parsed value, or null if the text is not a number.
  static double? parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  String? _validate(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return 'Required';

    final value = parse(text);
    if (value == null) return 'Not a number';
    if (min != null && value < min!) return 'Seems too low — expected at least ${_fmt(min!)}$unit';
    if (max != null && value > max!) return 'Seems too high — expected at most ${_fmt(max!)}$unit';
    return null;
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: Type.label()),
        const SizedBox(height: Space.sm),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
            ),
          ],
          style: Type.prose(size: 17, weight: 600),
          cursorColor: Hue.gold,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: _validate,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperStyle: Type.lore(size: 11, color: Hue.parchmentFaint),
            helperMaxLines: 2,
            errorStyle: Type.prose(size: 11, color: Hue.vitality),
            errorMaxLines: 2,
            suffixText: unit,
            suffixStyle: Type.label(size: 12, color: Hue.parchmentDim),
          ),
        ),
      ],
    );
  }
}
