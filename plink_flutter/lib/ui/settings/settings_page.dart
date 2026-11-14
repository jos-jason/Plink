import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/library_store.dart';
import '../../sync/plink_sync.dart';
import '../widgets/common.dart';
import 'sync_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _export(BuildContext context) async {
    final store = context.read<LibraryStore>();
    final date = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final saved = await FilePicker.saveFile(
        fileName: 'Plink-Backup-$date.json',
        bytes: utf8.encode(store.exportBackup()),
        mimeType: 'application/json',
      );
      if (saved != null && context.mounted) {
        showSnack(context, 'Library exported');
      }
    } catch (e) {
      if (context.mounted) {
        _alert(
          context,
          'Export Failed',
          'Could not export the library. Please try again.',
        );
      }
    }
  }

  Future<void> _import(BuildContext context) async {
    final store = context.read<LibraryStore>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Library?'),
        content: const Text(
          'This will add the pins and boards from the backup file to your library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (files.isEmpty) return;
      final added = store.importBackup(
        utf8.decode(await files.first.readAsBytes()),
      );
      if (context.mounted) {
        showSnack(context, 'Imported $added ${added == 1 ? 'pin' : 'pins'}');
      }
    } catch (e) {
      if (context.mounted) {
        _alert(
          context,
          'Import Failed',
          "Could not read the backup file. Make sure it's a valid Plink export.",
        );
      }
    }
  }

  void _alert(BuildContext context, String title, String message) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    final theme = Theme.of(context);

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            children: [
              header('Library'),
              ListTile(
                title: const Text('Pins'),
                trailing: Text('${store.pins.length}'),
              ),
              ListTile(
                title: const Text('Boards'),
                trailing: Text('${store.boards.length}'),
              ),
              header('Sync'),
              Builder(
                builder: (context) {
                  final sync = context.watch<PlinkSync>();
                  return ListTile(
                    leading: const Icon(Icons.cloud_sync_outlined),
                    title: const Text('Sync with your server'),
                    subtitle: Text(
                      sync.signedIn ? 'Signed in as ${sync.email}' : 'Off',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openSyncPage(context),
                  );
                },
              ),
              header('Backup'),
              ListTile(
                leading: const Icon(Icons.upload_outlined),
                title: const Text('Export Library'),
                subtitle: const Text(
                  'Saves a JSON backup compatible with Plink for iOS and Mac',
                ),
                onTap: () => _export(context),
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Import Library'),
                subtitle: const Text(
                  'Images are re-fetched from each link after import',
                ),
                onTap: () => _import(context),
              ),
              header('About'),
              const ListTile(title: Text('App'), trailing: Text('Plink')),
              const ListTile(title: Text('Version'), trailing: Text('1.0.0')),
            ],
          ),
        ),
      ),
    );
  }
}
