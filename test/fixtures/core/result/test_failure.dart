import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'test_failure.mapper.dart';

/// Failure used to exercise the result contracts in tests.
///
/// ```dart
/// const failure = TestFailure(message: 'Operation failed.');
/// ```
@MappableClass()
final class TestFailure extends Failure<TestFailure> with TestFailureMappable {
  /// Creates a test failure with optional human-readable details.
  const TestFailure({String? message}) : super(message);

  /// Stable identifier used by this test failure.
  static const typeId = 'test.failure';

  /// Returns this instance as a [TestFailure].
  @override
  TestFailure get failureOrNull => this;

  /// Returns the stable identifier for this failure kind.
  @override
  String get type => typeId;
}
