import 'package:axiom/src/core/presentation/layout/responsive_layout.dart';
import 'package:axiom/src/presentation/navigation/app_navigation_destination.dart';
import 'package:flutter/material.dart';

/// Responsive shell around the application's primary navigation destinations.
///
/// Compact layouts use a Material 3 [NavigationBar].
///
/// Medium layouts use a labelled [NavigationRail].
///
/// Expanded layouts use an extended [NavigationRail].
///
/// ## Invariants
///
/// [selectedIndex] is normalized before being supplied to Material navigation
/// widgets, preventing an invalid routing state from crashing presentation.
///
/// Destination selection outside the supported range is ignored.
///
/// ## Semantics
///
/// Navigation labels remain visible in every layout. Material navigation
/// widgets expose selected state and destination labels to accessibility
/// services.
///
/// ## Contract
///
/// This widget only renders navigation. Route state remains owned by
/// `auto_route`.
final class AppNavigationShell extends StatelessWidget {
  /// Currently selected primary destination.
  final int selectedIndex;

  /// Invoked when a valid primary destination is selected.
  final ValueChanged<int> onDestinationSelected;

  /// Active route content.
  final Widget child;

  /// Creates the primary navigation shell.
  const AppNavigationShell({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedIndex = _normalizeIndex(selectedIndex);

    return ResponsiveLayout(
      compact: _CompactNavigationShell(
        selectedIndex: normalizedIndex,
        onDestinationSelected: _selectDestination,
        child: child,
      ),
      medium: _RailNavigationShell(
        selectedIndex: normalizedIndex,
        onDestinationSelected: _selectDestination,
        extended: false,
        child: child,
      ),
      expanded: _RailNavigationShell(
        selectedIndex: normalizedIndex,
        onDestinationSelected: _selectDestination,
        extended: true,
        child: child,
      ),
    );
  }

  int _normalizeIndex(int index) {
    if (index < 0 || index >= AppNavigationDestination.values.length) {
      return 0;
    }

    return index;
  }

  void _selectDestination(int index) {
    if (index < 0 || index >= AppNavigationDestination.values.length) {
      return;
    }

    onDestinationSelected(index);
  }
}

final class _CompactNavigationShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  const _CompactNavigationShell({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final destination in AppNavigationDestination.values)
            destination.toNavigationDestination(),
        ],
      ),
    );
  }
}

final class _RailNavigationShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;
  final Widget child;

  const _RailNavigationShell({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.extended,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              extended: extended,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              groupAlignment: -1,
              destinations: [
                for (final destination in AppNavigationDestination.values)
                  destination.toNavigationRailDestination(),
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
