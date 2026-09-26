import 'package:auto_route/auto_route.dart';

import 'app_router.gr.dart';

/// Root application router.
///
/// ## Semantics
///
/// The root route hosts the five persistent primary destinations.
///
/// Detail and editing flows are root stack routes so they can temporarily cover
/// the persistent navigation shell without making primary destinations own
/// nested routing state.
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

    AutoRoute(path: '/accounts/new', page: CreateAccountRoute.page),
    AutoRoute(path: '/accounts/:accountId/edit', page: EditAccountRoute.page),
    AutoRoute(path: '/accounts/:accountId', page: AccountDetailsRoute.page),

    AutoRoute(path: '/custodians/new', page: CreateCustodianRoute.page),
    AutoRoute(
      path: '/custodians/:custodianId/edit',
      page: EditCustodianRoute.page,
    ),
    AutoRoute(
      path: '/custodians/:custodianId',
      page: CustodianDetailsRoute.page,
    ),
    AutoRoute(path: '/custodians', page: CustodiansRoute.page),

    AutoRoute(path: '*', page: NavigationNotFoundRoute.page),
  ];
}
