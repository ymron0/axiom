import 'package:axiom/src/application/bootstrap/application_bootstrap.dart';
import 'package:axiom/src/application/bootstrap/resolve_database_overrides.dart';
import 'package:axiom/src/core/presentation/application/application_startup_failure_shell.dart';
import 'package:axiom/src/development/fixtures/development_startup.dart';
import 'package:axiom/src/core/presentation/application/application_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final overrides = await resolveDatabaseOverrides(overrides: const []);

  final bootstrapResult = await bootstrapApplication(overrides: overrides);

  if (bootstrapResult.isFailure) {
    runApp(
      ApplicationStartupFailureShell(failure: bootstrapResult.failureOrNull!),
    );

    return;
  }

  final container = bootstrapResult.valueOrNull!;

  await runDevelopmentStartupTasks(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ApplicationShell(),
    ),
  );
}
