import 'package:flutter/material.dart';

import 'accounts_screen.dart';
import 'notes_screen.dart';

/// Vault home -- Accounts and Notes tabs, each independently gated on Drive
/// connection and loading only its own Drive file (see AccountsScreen/
/// NotesScreen), mirroring passvault-client's separate /accounts and
/// /notes pages rather than one combined view.
class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your vault'),
          bottom: const TabBar(tabs: [Tab(text: 'Accounts', icon: Icon(Icons.key)), Tab(text: 'Notes', icon: Icon(Icons.note))]),
        ),
        body: const TabBarView(children: [AccountsScreen(), NotesScreen()]),
      ),
    );
  }
}
