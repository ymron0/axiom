import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Primary accounts destination.
@RoutePage()
final class AccountsPage extends StatelessWidget {
  /// Creates the accounts page.
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: const SizedBox.expand(),
    );
  }
}
