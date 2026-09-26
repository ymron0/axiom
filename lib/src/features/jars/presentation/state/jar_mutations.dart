import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/di/archive_jar_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/create_jar_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/unarchive_jar_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/update_jar_use_case_provider.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/presentation/models/jar_form_data.dart';
import 'package:axiom/src/features/jars/presentation/state/jars_state.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks jar creation.
final createJarMutation = Mutation<Result<Jar, BaseFailure>>(
  label: 'create-jar',
);

/// Tracks jar editing.
final updateJarMutation = Mutation<Result<void, BaseFailure>>(
  label: 'update-jar',
);

/// Tracks jar archival.
final archiveJarMutation = Mutation<Result<Jar, JarFailure>>(
  label: 'archive-jar',
);

/// Tracks jar reactivation.
final unarchiveJarMutation = Mutation<Result<Jar, JarFailure>>(
  label: 'unarchive-jar',
);

/// Creates a jar.
///
/// Persisted jar projections are watched directly, so [jarsProvider],
/// [allJarsProvider], and [jarProvider] update automatically after the write.
///
/// [jarFormOptionsProvider] remains a bounded query and is invalidated because
/// the next available sort order changes after successful creation.
Future<Result<Jar, BaseFailure>?> executeCreateJar(
  WidgetRef ref, {
  required JarFormData data,
  required JarFormOptions options,
}) async {
  try {
    final result = await createJarMutation.run(ref, (transaction) {
      final useCase = transaction.get(createJarUseCaseProvider);

      return useCase(
        data.toCreateCommand(
          valuationCurrency: options.valuationCurrency,
          effectiveDate: options.effectiveDate,
        ),
      );
    });

    if (result.isSuccess) {
      ref.invalidate(jarFormOptionsProvider);
    }

    return result;
  } on Object {
    return null;
  }
}

/// Updates a jar.
///
/// The persisted jar entity is observed directly by the presentation layer, so
/// the jar overview and details projections require no explicit invalidation.
///
/// Progress is invalidated because jar target configuration may have changed.
/// Form options are invalidated because sort-order data may also have changed.
Future<Result<void, BaseFailure>?> executeUpdateJar(
  WidgetRef ref, {
  required Jar original,
  required JarFormData data,
  required JarFormOptions options,
}) async {
  try {
    final result = await updateJarMutation.run(ref, (transaction) {
      final clock = transaction.get(clockProvider);
      final useCase = transaction.get(updateJarUseCaseProvider);

      final updated = data.applyTo(
        original,
        valuationCurrency: options.valuationCurrency,
        effectiveDate: options.effectiveDate,
        modifiedAt: clock.nowUtc,
      );

      return useCase(updated);
    });

    if (result.isSuccess) {
      ref.invalidate(jarFormOptionsProvider);
      ref.invalidate(jarProgressPresentationProvider(original.id));
    }

    return result;
  } on Object {
    return null;
  }
}

/// Archives [jarId].
///
/// The watched jar streams update automatically after persistence changes.
/// Progress is recalculated because lifecycle state may affect presentation.
Future<Result<Jar, JarFailure>?> executeArchiveJar(
  WidgetRef ref,
  JarId jarId,
) async {
  try {
    final result = await archiveJarMutation.run(ref, (transaction) {
      final useCase = transaction.get(archiveJarUseCaseProvider);

      return useCase(jarId);
    });

    if (result.isSuccess) {
      ref.invalidate(jarProgressPresentationProvider(jarId));
      ref.invalidate(jarFormOptionsProvider);
    }

    return result;
  } on Object {
    return null;
  }
}

/// Reactivates [jarId].
///
/// The watched jar streams update automatically after persistence changes.
Future<Result<Jar, JarFailure>?> executeUnarchiveJar(
  WidgetRef ref,
  JarId jarId,
) async {
  try {
    final result = await unarchiveJarMutation.run(ref, (transaction) {
      final useCase = transaction.get(unarchiveJarUseCaseProvider);

      return useCase(jarId);
    });

    if (result.isSuccess) {
      ref.invalidate(jarProgressPresentationProvider(jarId));
      ref.invalidate(jarFormOptionsProvider);
    }

    return result;
  } on Object {
    return null;
  }
}
