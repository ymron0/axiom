import 'package:auto_route/auto_route.dart';

import 'app_router.gr.dart';

/// Root application router.
///
/// ## Semantics
///
/// The root route hosts the five persistent primary destinations. Additional
/// routes can be added alongside [AppShellRoute] when they should temporarily
/// cover or replace the persistent application navigation.
///
/// ## Contract
///
/// Unknown paths are handled by [NavigationNotFoundRoute].
@AutoRouterConfig(replaceInRouteName: 'Page,Route')
final class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: AppShellRoute.page,
      children: [
        AutoRoute(path: '', page: HomeRoute.page),
        AutoRoute(path: 'activity', page: ActivityRoute.page),
        AutoRoute(path: 'accounts', page: AccountsRoute.page),
        AutoRoute(path: 'categories', page: CategoriesRoute.page),
        AutoRoute(path: 'more', page: MoreRoute.page),
      ],
    ),
    AutoRoute(path: '*', page: NavigationNotFoundRoute.page),
  ];
}
