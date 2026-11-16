import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/library_store.dart';
import '../../sync/plink_sync.dart';
import '../../theme.dart';
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
    final sync = context.watch<PlinkSync>();
    final p = PlinkPalette.of(context);

    return LargeTitlePage(
      title: 'Settings',
      background: p.groupedBackground,
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  GroupedSection(
                    header: 'Library',
                    children: [
                      GroupedRow(title: 'Pins', value: '${store.pins.length}'),
                      GroupedRow(
                        title: 'Boards',
                        value: '${store.boards.length}',
                      ),
                    ],
                  ),
                  GroupedSection(
                    header: 'Sync',
                    children: [
                      GroupedRow(
                        icon: Icons.cloud_sync,
                        title: 'Sync with your server',
                        value: sync.signedIn ? 'On' : 'Off',
                        subtitle: sync.signedIn ? sync.email : null,
                        chevron: true,
                        onTap: () => openSyncPage(context),
                      ),
                    ],
                  ),
                  GroupedSection(
                    header: 'Backup',
                    footer:
                        'Backups work with Plink for iOS and Mac. Images are '
                        'fetched again from each link after an import.',
                    children: [
                      GroupedRow(
                        icon: Icons.ios_share,
                        title: 'Export Library',
                        isButton: true,
                        onTap: () => _export(context),
                      ),
                      GroupedRow(
                        icon: Icons.download,
                        title: 'Import Library',
                        isButton: true,
                        onTap: () => _import(context),
                      ),
                    ],
                  ),
                  const GroupedSection(
                    header: 'About',
                    children: [
                      GroupedRow(title: 'Version', value: '1.1.2'),
                      GroupedRow(title: 'App', value: 'Plink'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
