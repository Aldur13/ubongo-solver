import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.style, color: colorScheme.onPrimaryContainer),
            ),
            title: const Text('Edition'),
            subtitle: const Text('Classic Ubongo (2D)'),
            trailing: Icon(Icons.check_circle, color: colorScheme.primary),
          ),
          const Divider(height: 1),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(Icons.info_outline, color: colorScheme.onSecondaryContainer),
            ),
            title: const Text('Piece catalog'),
            subtitle: const Text(
              'Placeholder shapes — not yet matched to a real physical Ubongo set.',
            ),
          ),
        ],
      ),
    );
  }
}
