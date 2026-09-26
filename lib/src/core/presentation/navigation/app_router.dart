import 'package:auto_route/auto_route.dart';

import 'app_router.gr.dart';

/// Root navigation configuration for the application.
///
/// ## Navigation model
///
/// The primary destinations are hosted by [AppShellRoute]:
///
/// - Home
/// - Activity
/// - Accounts
/// - Categories
/// - More
///
/// Detail, creation, editing, management and settings screens live on the root
/// stack so they cover the shell while retaining the selected tab underneath.
///
/// ## Contract
///
/// Every routable page must be annotated with `@RoutePage()` and included in
/// this configuration when it requires an explicit route.
///
/// Generated route classes are written to `app_router.gr.dart`.
@AutoRouterConfig(replaceInRouteName: 'Page|Screen,Route')
final class AppRouter extends RootStackRouter {
  /// Uses Material page transitions throughout the application.
  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
    //
    // Application shell.
    //
    AutoRoute(
      path: '/',
      page: AppShellRoute.page,
      initial: true,
      children: [
        AutoRoute(path: '', page: HomeRoute.page, initial: true),
        AutoRoute(path: 'activity', page: ActivityRoute.page),
        AutoRoute(path: 'accounts', page: AccountsRoute.page),
        AutoRoute(path: 'categories', page: CategoriesRoute.page),
        AutoRoute(path: 'more', page: MoreRoute.page),
      ],
    ),

    //
    // Accounts.
    //
    AutoRoute(path: '/accounts/new', page: CreateAccountRoute.page),
    AutoRoute(path: '/accounts/:accountId/edit', page: EditAccountRoute.page),
    AutoRoute(path: '/accounts/:accountId', page: AccountDetailsRoute.page),

    // Custodians
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

    //
    // Categories.
    //
    AutoRoute(path: '/categories/new', page: CreateCategoryRoute.page),
    AutoRoute(
      path: '/categories/:categoryId/edit',
      page: EditCategoryRoute.page,
    ),
    AutoRoute(path: '/categories/:categoryId', page: CategoryDetailsRoute.page),

    //
    // Jars.
    //
    AutoRoute(path: '/jars', page: JarsRoute.page),
    AutoRoute(path: '/jars/new', page: CreateJarRoute.page),
    AutoRoute(path: '/jars/:jarId/edit', page: EditJarRoute.page),
    AutoRoute(path: '/jars/:jarId', page: JarDetailsRoute.page),

    //
    // Tags.
    //
    AutoRoute(path: '/tags', page: TagManagementRoute.page),

    //
    // Settings and reference data.
    //
    AutoRoute(path: '/settings', page: SettingsRoute.page),
    AutoRoute(
      path: '/settings/valuation-currency',
      page: ValuationCurrencyRoute.page,
    ),
    AutoRoute(path: '/settings/assets', page: AssetManagementRoute.page),
    AutoRoute(path: '/settings/merchants', page: MerchantManagementRoute.page),
    AutoRoute(path: '/settings/rates', page: RateStatusRoute.page),
    AutoRoute(path: '/settings/data', page: DataManagementRoute.page),
    AutoRoute(path: '/settings/data/reset', page: ResetApplicationRoute.page),

    //
    // Fallback.
    //
    AutoRoute(path: '*', page: NavigationNotFoundRoute.page),
  ];
}
