import 'package:axiom/src/core/presentation/failures/presentation_failure_mapper.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.dart';
import 'package:axiom/src/core/presentation/theme/app_theme.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:axiom/src/features/onboarding/presentation/state/onboarding_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root presentation shell.
///
/// Owns application-wide presentation concerns that sit above every route:
///
/// - first-run detection;
/// - onboarding presentation;
/// - root navigation;
/// - application restoration;
/// - global theme selection.
///
/// ## Invariants
///
/// Exactly one [AppRouter] exists for the lifetime of this widget's state.
///
/// Normal application navigation is unavailable until onboarding completion
/// has been confirmed.
///
/// ## Semantics
///
/// First-run onboarding is a root presentation concern rather than a regular
/// application route. Completing onboarding causes [firstRunDetectionProvider]
/// to refresh, after which the normal router becomes active.
///
/// ## Contract
///
/// Infrastructure bootstrap remains outside this widget. Feature-specific
/// business logic remains in application services and feature use cases.
final class ApplicationShell extends ConsumerStatefulWidget {
  /// Creates the root application shell.
  const ApplicationShell({super.key});

  @override
  ConsumerState<ApplicationShell> createState() => _ApplicationShellState();
}

final class _ApplicationShellState extends ConsumerState<ApplicationShell> {
  static const String _applicationRestorationScopeId = 'application';
  static const String _navigationRestorationScopeId = 'root-navigation';

  late final AppRouter _router;

  @override
  void initState() {
    super.initState();

    _router = AppRouter();
  }

  @override
  void dispose() {
    _router.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firstRun = ref.watch(firstRunDetectionProvider);

    return firstRun.when(
      loading: () => _buildStateApplication(
        const LoadingStateView(semanticLabel: 'Checking application setup'),
      ),
      error: (error, stackTrace) => _buildStateApplication(
        ErrorStateView(
          error: const PresentationFailureMapper().fromObject(error),
          onRetry: () {
            ref.invalidate(firstRunDetectionProvider);
          },
        ),
      ),
      data: (result) {
        return result.when(
          success: (isFirstRun) {
            if (isFirstRun) {
              return _buildOnboardingApplication();
            }

            return _buildRouterApplication();
          },
          failure: (failure) {
            return _buildStateApplication(
              ErrorStateView(
                error: const PresentationFailureMapper().fromFailure(failure),
                onRetry: () {
                  ref.invalidate(firstRunDetectionProvider);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOnboardingApplication() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      restorationScopeId: _applicationRestorationScopeId,
      theme: AppTheme.light,
      home: const OnboardingPage(),
    );
  }

  Widget _buildRouterApplication() {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      restorationScopeId: _applicationRestorationScopeId,
      theme: AppTheme.light,
      routerConfig: _router.config(
        navRestorationScopeId: _navigationRestorationScopeId,
        placeholder: _buildNavigationPlaceholder,
      ),
    );
  }

  Widget _buildStateApplication(Widget body) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      restorationScopeId: _applicationRestorationScopeId,
      theme: AppTheme.light,
      home: Scaffold(body: body),
    );
  }

  Widget _buildNavigationPlaceholder(BuildContext context) {
    return const Scaffold(
      body: LoadingStateView(semanticLabel: 'Loading navigation'),
    );
  }
}
