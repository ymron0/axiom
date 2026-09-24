@Tags(['presentation'])
library;

import 'package:axiom/src/presentation/layout/responsive_layout.dart';
import 'package:axiom/src/presentation/layout/window_size_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResponsiveLayout.sizeClassFor', () {
    test('uses compact for phone width', () {
      expect(ResponsiveLayout.sizeClassFor(360), WindowSizeClass.compact);
    });

    test('uses medium from 600dp', () {
      expect(ResponsiveLayout.sizeClassFor(600), WindowSizeClass.medium);
    });

    test('uses expanded from 840dp', () {
      expect(ResponsiveLayout.sizeClassFor(840), WindowSizeClass.expanded);
    });
  });

  testWidgets('renders compact layout at 360dp', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 360,
          child: ResponsiveLayout(
            compact: Text('compact'),
            medium: Text('medium'),
            expanded: Text('expanded'),
          ),
        ),
      ),
    );

    expect(find.text('compact'), findsOneWidget);
    expect(find.text('medium'), findsNothing);
    expect(find.text('expanded'), findsNothing);
  });

  testWidgets('falls back to compact when medium is omitted', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 700,
          child: ResponsiveLayout(compact: Text('compact')),
        ),
      ),
    );

    expect(find.text('compact'), findsOneWidget);
  });
}
