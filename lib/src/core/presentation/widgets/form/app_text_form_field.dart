import 'package:axiom/src/core/presentation/validation/presentation_field_validator.dart';
import 'package:flutter/material.dart';

/// Standard text form field for application forms.
///
/// ## Semantics
///
/// [label] is rendered using Material's input decoration and therefore remains
/// associated with the editable field for accessibility.
///
/// Validation errors are rendered through the standard Material form-field
/// semantics.
///
/// ## Contract
///
/// [validator] performs presentation-level input validation only.
///
/// Business rules and domain invariants must still be validated by the
/// application/domain layer when the form is submitted.
final class AppTextFormField extends StatelessWidget {
  /// Field controller.
  final TextEditingController? controller;

  /// Material field label.
  final String label;

  /// Optional hint.
  final String? hint;

  /// Presentation-level validator.
  final PresentationFieldValidator<String>? validator;

  /// Keyboard configuration.
  final TextInputType? keyboardType;

  /// IME action.
  final TextInputAction? textInputAction;

  /// Called when editing completes through the keyboard action.
  final ValueChanged<String>? onFieldSubmitted;

  /// Called whenever the value changes.
  final ValueChanged<String>? onChanged;

  /// Optional prefix icon.
  final Widget? prefixIcon;

  /// Optional suffix icon.
  final Widget? suffixIcon;

  /// Whether editing is enabled.
  final bool enabled;

  /// Whether the field should initially receive focus.
  final bool autofocus;

  /// Whether text is obscured.
  final bool obscureText;

  /// Maximum number of lines.
  final int maxLines;

  /// Creates a shared text form field.
  const AppTextFormField({
    required this.label,
    this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.autofocus = false,
    this.obscureText = false,
    this.maxLines = 1,
    super.key,
  }) : assert(maxLines > 0, 'maxLines must be greater than zero.'),
       assert(
         !obscureText || maxLines == 1,
         'Obscured fields must use exactly one line.',
       );

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      enabled: enabled,
      autofocus: autofocus,
      obscureText: obscureText,
      maxLines: maxLines,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
