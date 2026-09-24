@Tags(['presentation'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/presentation/widgets/state/async_result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows loading state', (tester) async {
    const value = AsyncLoading<Result<List<String>, AccountFailure>>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncResultView<List<String>, AccountFailure>(
            value: value,
            builder: (context, items) {
              return const Text('loaded');
            },
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows loaded data', (tester) async {
    const value = AsyncData<Result<List<String>, AccountFailure>>(
      Success<List<String>>(['one', 'two']),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncResultView<List<String>, AccountFailure>(
            value: value,
            builder: (context, items) {
              return Text(items.join(','));
            },
          ),
        ),
      ),
    );

    expect(find.text('one,two'), findsOneWidget);
  });

  testWidgets('shows empty state for successful empty data', (tester) async {
    const value = AsyncData<Result<List<String>, AccountFailure>>(
      Success<List<String>>([]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncResultView<List<String>, AccountFailure>(
            value: value,
            isEmpty: (items) => items.isEmpty,
            emptyTitle: 'No accounts',
            builder: (context, items) {
              return const Text('loaded');
            },
          ),
        ),
      ),
    );

    expect(find.text('No accounts'), findsOneWidget);
    expect(find.text('loaded'), findsNothing);
  });

  testWidgets('maps expected result failure', (tester) async {
    const value = AsyncData<Result<List<String>, AccountFailure>>(
      AccountNotFoundFailure(
        message: 'The requested account could not be found.',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncResultView<List<String>, AccountFailure>(
            value: value,
            builder: (context, items) {
              return const Text('loaded');
            },
          ),
        ),
      ),
    );

    expect(find.text('Not found'), findsOneWidget);
    expect(
      find.text('The requested account could not be found.'),
      findsOneWidget,
    );
  });

  testWidgets('does not expose unexpected exception details', (tester) async {
    final value = AsyncError<Result<List<String>, AccountFailure>>(
      StateError('Internal technical detail'),
      StackTrace.empty,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncResultView<List<String>, AccountFailure>(
            value: value,
            builder: (context, items) {
              return const Text('loaded');
            },
          ),
        ),
      ),
    );

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.textContaining('Internal technical detail'), findsNothing);
  });
}
