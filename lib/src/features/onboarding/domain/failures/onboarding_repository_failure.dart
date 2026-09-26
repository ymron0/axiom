import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/onboarding/domain/failures/onboarding_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'onboarding_repository_failure.mapper.dart';

/// Indicates that onboarding persistence could not be accessed.
@MappableClass()
final class OnboardingRepositoryFailure
    extends Failure<OnboardingRepositoryFailure>
    with OnboardingRepositoryFailureMappable
    implements OnboardingFailure {
  /// Creates an onboarding repository failure.
  const OnboardingRepositoryFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'onboarding.repository';

  @override
  OnboardingRepositoryFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
