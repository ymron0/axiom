import 'package:axiom/src/application/bootstrap/application_bootstrap.dart';
import 'package:axiom/src/application/bootstrap/resolve_database_overrides.dart';
import 'package:axiom/src/development/fixtures/development_startup.dart';
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

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Hello World!'))),
    );
  }
}

class _BootstrapFailureApp extends StatelessWidget {
  const _BootstrapFailureApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Unable to start the application.')),
      ),
    );
  }
}
