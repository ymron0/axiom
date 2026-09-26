import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Primary destination for secondary application areas.
@RoutePage()
final class MorePage extends StatelessWidget {
  /// Creates the more page.
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: const SizedBox.expand(),
    );
  }
}
