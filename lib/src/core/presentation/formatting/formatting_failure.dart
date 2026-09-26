import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'formatting_failure.mapper.dart';

/// Expected failure produced while interpreting formatted user input.
///
/// Output formatting of valid domain values is deterministic and does not
/// return failures. Parsing user-entered localized values can legitimately
/// fail and therefore uses this typed failure.
///
/// ## Semantics
///
/// This failure represents presentation input that cannot be interpreted as
/// the expected formatted value.
///
/// ## Contract
///
/// Formatting failures are safe to expose through the presentation failure
/// mapper and must not contain infrastructure details.
@MappableClass()
final class FormattingFailure extends Failure<FormattingFailure>
    with FormattingFailureMappable {
  /// Stable identifier for invalid numeric input.
  static const String typeId = 'presentation.formatting.invalidNumber';

  /// Creates an invalid-format failure.
  const FormattingFailure({String message = 'Enter a valid number.'})
    : super(message);

  @override
  FormattingFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
