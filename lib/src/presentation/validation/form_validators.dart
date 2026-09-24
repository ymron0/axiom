import 'package:axiom/src/presentation/validation/presentation_field_validator.dart';
import 'package:decimal/decimal.dart';

/// Common presentation-level input validators.
///
/// These validators check input shape only. Business and domain validation
/// remains in application services, use cases, value objects, and entities.
///
/// ## Contract
///
/// A `null` return value means that the presentation-level validation passed.
/// A non-null value is suitable for display below the corresponding input.
abstract final class FormValidators {
  /// Requires non-empty text.
  static String? requiredText(
    String? value, {
    String message = 'This field is required.',
  }) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }

    return null;
  }

  /// Requires a non-null selection.
  static String? requiredValue<T>(
    T? value, {
    String message = 'Please select a value.',
  }) {
    if (value == null) {
      return message;
    }

    return null;
  }

  /// Validates the maximum length of optional text.
  static String? maxLength(String? value, int maximum, {String? message}) {
    if (value == null || value.isEmpty) {
      return null;
    }

    if (value.length > maximum) {
      return message ?? 'Use no more than $maximum characters.';
    }

    return null;
  }

  /// Validates a decimal number.
  ///
  /// Both `.` and `,` are accepted as decimal separators at the input
  /// boundary. The presentation layer should normalize the value before
  /// passing it further into the application.
  static String? decimalNumber(
    String? value, {
    bool required = true,
    String requiredMessage = 'This field is required.',
    String invalidMessage = 'Enter a valid number.',
  }) {
    final input = value?.trim() ?? '';

    if (input.isEmpty) {
      return required ? requiredMessage : null;
    }

    if (_tryParseDecimal(input) == null) {
      return invalidMessage;
    }

    return null;
  }

  /// Validates a decimal number greater than zero.
  static String? positiveDecimal(
    String? value, {
    bool required = true,
    String requiredMessage = 'This field is required.',
    String invalidMessage = 'Enter a valid number.',
    String positiveMessage = 'Enter an amount greater than zero.',
  }) {
    final validation = decimalNumber(
      value,
      required: required,
      requiredMessage: requiredMessage,
      invalidMessage: invalidMessage,
    );

    if (validation != null) {
      return validation;
    }

    final input = value?.trim() ?? '';

    if (input.isEmpty) {
      return null;
    }

    final parsed = _tryParseDecimal(input)!;

    if (parsed <= Decimal.zero) {
      return positiveMessage;
    }

    return null;
  }

  /// Validates a decimal number greater than or equal to zero.
  static String? nonNegativeDecimal(
    String? value, {
    bool required = true,
    String requiredMessage = 'This field is required.',
    String invalidMessage = 'Enter a valid number.',
    String nonNegativeMessage = 'Enter zero or a positive amount.',
  }) {
    final validation = decimalNumber(
      value,
      required: required,
      requiredMessage: requiredMessage,
      invalidMessage: invalidMessage,
    );

    if (validation != null) {
      return validation;
    }

    final input = value?.trim() ?? '';

    if (input.isEmpty) {
      return null;
    }

    final parsed = _tryParseDecimal(input)!;

    if (parsed < Decimal.zero) {
      return nonNegativeMessage;
    }

    return null;
  }

  /// Combines multiple validators and returns the first validation message.
  static PresentationFieldValidator<T> combine<T>(
    Iterable<PresentationFieldValidator<T>> validators,
  ) {
    return (value) {
      for (final validator in validators) {
        final message = validator(value);

        if (message != null) {
          return message;
        }
      }

      return null;
    };
  }

  static Decimal? _tryParseDecimal(String value) {
    final normalized = value.replaceAll(',', '.');

    try {
      return Decimal.parse(normalized);
    } on FormatException {
      return null;
    }
  }
}
