/// Persisted completion state of the first-run onboarding workflow.
///
/// The absence of a persisted status is equivalent to [pending].
///
/// ## Invariants
///
/// - [completedAt], when present, is normalized to UTC.
///
/// ## Semantics
///
/// Onboarding completion is deliberately separate from Settings creation.
/// Settings are created before the optional custodian, account, and initial
/// balance steps, so Settings existence alone cannot safely identify a
/// completed onboarding flow.
final class OnboardingStatus {
  /// Creates an incomplete onboarding status.
  const OnboardingStatus.pending() : completedAt = null;

  /// Creates a completed onboarding status.
  OnboardingStatus.completed(DateTime completedAt)
    : completedAt = completedAt.toUtc();

  /// Time at which onboarding was completed.
  ///
  /// `null` means onboarding has not been completed.
  final DateTime? completedAt;

  /// Whether first-run onboarding has been completed.
  bool get isCompleted => completedAt != null;
}
