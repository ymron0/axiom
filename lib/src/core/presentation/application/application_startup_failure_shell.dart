import 'package:axiom/src/core/persistence/failures/persistence_failure.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure_mapper.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:flutter/material.dart';

/// Root presentation shown when application bootstrap cannot complete.
///
/// The underlying [PersistenceFailure] remains typed until it reaches this
/// presentation boundary. It is then mapped to a safe user-facing
/// presentation failure.
///
/// ## Semantics
///
/// Infrastructure details are not rendered directly to the user.
///
/// ## Contract
///
/// This widget renders an already-determined bootstrap failure. It does not
/// retry bootstrap or perform infrastructure operations itself.
final class ApplicationStartupFailureShell extends StatelessWidget {
  final PersistenceFailure failure;

  /// Creates the startup-failure shell.
  const ApplicationStartupFailureShell({required this.failure, super.key});

  @override
  Widget build(BuildContext context) {
    final presentationFailure = const PresentationFailureMapper().fromFailure(
      failure,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(body: ErrorStateView(error: presentationFailure)),
    );
  }
}
