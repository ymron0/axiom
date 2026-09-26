import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Primary categories destination.
@RoutePage()
final class CategoriesPage extends StatelessWidget {
  /// Creates the categories page.
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: const SizedBox.expand(),
    );
  }
}
