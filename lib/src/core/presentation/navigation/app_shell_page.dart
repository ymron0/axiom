import 'package:axiom/src/core/presentation/navigation/app_navigation_destination.dart';
import 'package:axiom/src/core/presentation/navigation/app_navigation_shell.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.gr.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Hosts the application's five persistent primary destinations.
///
/// `AutoTabsRouter` is used rather than manually replacing routes so each
/// destination can retain its own presentation state while inactive.
///
/// ## Invariants
///
/// [_tabRoutes] and [AppNavigationDestination.values] have identical ordering.
///
/// ## Semantics
///
/// Tab transitions honor the platform reduced-motion accessibility preference.
///
/// ## Contract
///
/// This page owns only primary navigation. Feature pages remain responsible
/// for their own application bars, content state, loading states, and actions.
@RoutePage()
final class AppShellPage extends StatelessWidget {
  static const List<PageRouteInfo<void>> _tabRoutes = [
    HomeRoute(),
    ActivityRoute(),
    AccountsRoute(),
    CategoriesRoute(),
    MoreRoute(),
  ];

  /// Creates the primary application shell.
  const AppShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    assert(
      _tabRoutes.length == AppNavigationDestination.values.length,
      'Primary tab routes and navigation destinations must remain aligned.',
    );

    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return AutoTabsRouter(
      routes: _tabRoutes,
      lazyLoad: true,
      duration: disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      transitionBuilder: (context, child, animation) {
        if (disableAnimations) {
          return child;
        }

        return FadeTransition(opacity: animation, child: child);
      },
      builder: (context, child) {
        final tabsRouter = AutoTabsRouter.of(context);

        return AppNavigationShell(
          selectedIndex: tabsRouter.activeIndex,
          onDestinationSelected: tabsRouter.setActiveIndex,
          child: child,
        );
      },
    );
  }
}
