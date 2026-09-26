import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Primary transaction activity destination.
@RoutePage()
final class ActivityPage extends StatelessWidget {
  /// Creates the activity page.
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: const SizedBox.expand(),
    );
  }
}
