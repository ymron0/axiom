import 'package:axiom/src/core/presentation/navigation/app_router.dart';
import 'package:axiom/src/core/presentation/theme/app_theme.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:flutter/material.dart';

/// Root presentation shell.
///
/// Owns application-wide presentation concerns that sit above every route:
///
/// - root navigation;
/// - application restoration;
/// - global theme selection;
/// - root navigation loading state.
///
/// Global theme construction itself belongs to [AppTheme].
///
/// Feature-specific state, loading behavior, validation, and application bars
/// remain owned by their respective feature pages.
///
/// ## Invariants
///
/// Exactly one [AppRouter] exists for the lifetime of this widget's state.
///
/// The router is disposed when the shell leaves the widget tree.
///
/// The root application always receives the shared Material 3 theme.
///
/// ## Semantics
///
/// Navigation restoration is enabled independently from the root application
/// restoration scope.
///
/// While root navigation is resolving, an accessible loading state is shown.
///
/// ## Contract
///
/// This widget does not initialize infrastructure, perform application
/// bootstrap, construct feature themes, or own feature presentation state.
///
/// Those responsibilities belong to the application's composition root,
/// shared presentation theme, application layer, and individual feature
/// presentation layers respectively.
final class ApplicationShell extends StatefulWidget {
  /// Creates the root application shell.
  const ApplicationShell({super.key});

  @override
  State<ApplicationShell> createState() => _ApplicationShellState();
}

final class _ApplicationShellState extends State<ApplicationShell> {
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

  Widget _buildNavigationPlaceholder(BuildContext context) {
    return const Scaffold(
      body: LoadingStateView(semanticLabel: 'Loading navigation'),
    );
  }
}
