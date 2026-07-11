import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/developer_mode.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final developerMode = ref.watch(developerModeProvider);
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
          const Divider(height: 1),
          SwitchListTile(
            secondary: CircleAvatar(
              backgroundColor: colorScheme.tertiaryContainer,
              child: Icon(Icons.bug_report_outlined, color: colorScheme.onTertiaryContainer),
            ),
            title: const Text('Developer mode'),
            subtitle: const Text(
              'Show a share button after scanning to export the corrected '
              'card photo for diagnosing detection problems.',
            ),
            value: developerMode,
            onChanged: (enabled) =>
                ref.read(developerModeProvider.notifier).setEnabled(enabled),
          ),
        ],
      ),
    );
  }
}
