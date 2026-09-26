import 'package:axiom/src/application/bootstrap/application_bootstrap.dart';
import 'package:axiom/src/application/bootstrap/resolve_database_overrides.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure_kind.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/development/fixtures/development_startup.dart';
import 'package:axiom/src/presentation/navigation/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final overrides = await resolveDatabaseOverrides(overrides: const []);

  final bootstrapResult = await bootstrapApplication(overrides: overrides);

  if (bootstrapResult.isFailure) {
    runApp(const _BootstrapFailureApp());
    return;
  }

  final container = bootstrapResult.valueOrNull!;

  await runDevelopmentStartupTasks(container);

  runApp(
    UncontrolledProviderScope(container: container, child: const MainApp()),
  );
}

/// Root presentation widget.
final class MainApp extends StatefulWidget {
  /// Creates the root presentation widget.
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

final class _MainAppState extends State<MainApp> {
  late final AppRouter _router;

  @override
  void initState() {
    super.initState();

    _router = AppRouter();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      restorationScopeId: 'application',
      theme: ThemeData(useMaterial3: true),
      routerConfig: _router.config(
        navRestorationScopeId: 'root-navigation',
        placeholder: (context) {
          return const Scaffold(
            body: LoadingStateView(semanticLabel: 'Loading navigation'),
          );
        },
      ),
    );
  }
}

final class _BootstrapFailureApp extends StatelessWidget {
  static const _failure = PresentationFailure(
    kind: PresentationFailureKind.unavailable,
    title: 'Unable to start',
    message: 'The application could not be started.',
  );

  const _BootstrapFailureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(body: ErrorStateView(error: _failure)),
    );
  }
}
