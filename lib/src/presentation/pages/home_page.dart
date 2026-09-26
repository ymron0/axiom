import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Primary home destination.
@RoutePage()
final class HomePage extends StatelessWidget {
  /// Creates the home page.
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const SizedBox.expand(),
    );
  }
}
