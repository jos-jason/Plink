import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../data/library_store.dart';
import '../../models/pin.dart';
import '../boards/board_picker_dialog.dart';
import '../widgets/common.dart';
import '../widgets/board_glyph.dart';
import 'page_image_picker.dart';

class PinDetailPage extends StatefulWidget {
  const PinDetailPage({super.key, required this.pinId});

  final String pinId;

  @override
  State<PinDetailPage> createState() => _PinDetailPageState();
}

class _PinDetailPageState extends State<PinDetailPage> {
  late final TextEditingController _notes;
  Timer? _notesDebounce;

  @override
  void initState() {
    super.initState();
    final pin = context.read<LibraryStore>().pinById(widget.pinId);
    _notes = TextEditingController(text: pin?.notes ?? '');
  }

  @override
  void dispose() {
    _notesDebounce?.cancel();
    _notes.dispose();
    super.dispose();
  }

  void _onNotesChanged(Pin pin, String value) {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 400), () {
      pin.notes = value;
      context.read<LibraryStore>().updatePin(pin);
    });
  }

  Future<void> _changeImage(Pin pin) async {
    final store = context.read<LibraryStore>();
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    final ok = await store.setImage(
      pin,
      await files.first.readAsBytes(),
      custom: true,
    );
    if (!ok && mounted) {
      showSnack(context, 'That file could not be read as an image');
    }
  }

  Future<void> _confirmDelete(Pin pin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pin?'),
        content: const Text('This will permanently remove this pin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
      await context.read<LibraryStore>().deletePin(pin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    final pin = store.pinById(widget.pinId);
    if (pin == null) return const Scaffold();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final boards = pin.boardIds.map(store.boardById).nonNulls.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin Details'),
        actions: [
          if (store.isFetching(pin))
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Builder(
            builder: (buttonContext) => PopupMenuButton<void>(
              icon: const Icon(Icons.more_horiz),
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: () => showPageImagePicker(context, pin),
                  child: const Text('Choose Image from Page'),
                ),
                PopupMenuItem(
                  onTap: () => _changeImage(pin),
                  child: const Text('Choose from Photos'),
                ),
                PopupMenuItem(
                  onTap: () => store.refreshMetadata(pin),
                  child: const Text('Refresh Metadata'),
                ),
                PopupMenuItem(
                  onTap: () => copyLink(context, pin.urlString),
                  child: const Text('Copy Link'),
                ),
                PopupMenuItem(
                  onTap: () => shareLink(
                    context,
                    pin.urlString,
                    origin: originRect(buttonContext),
                  ),
                  child: const Text('Share'),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  onTap: () => _confirmDelete(pin),
                  child: Text(
                    'Delete Pin',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pin.imagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppConstants.cardCornerRadius,
                  ),
                  child: AspectRatio(
                    aspectRatio: pin.imageAspectRatio.clamp(0.4, 3.0),
                    child: StoredImage(pin.imagePath!, fit: BoxFit.contain),
                  ),
                )
              else if (pin.faviconPath != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.square(
                      dimension: 64,
                      child: StoredImage(pin.faviconPath!, fit: BoxFit.contain),
                    ),
                  ),
                ),
              if (pin.imagePath == null)
                Center(
                  child: TextButton.icon(
                    onPressed: () => showPageImagePicker(context, pin),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Choose an image from the page'),
                  ),
                ),
              const SizedBox(height: 16),
              if (pin.title.isNotEmpty)
                SelectableText(
                  pin.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (pin.domain.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.public, size: 16, color: muted),
                      const SizedBox(width: 6),
                      Text(
                        pin.domain,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              if (pin.pageDescription.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SelectableText(
                    pin.pageDescription,
                    style: theme.textTheme.bodyLarge?.copyWith(color: muted),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => openLink(context, pin.urlString),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Open Link'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const Divider(height: 32),
              Text('Notes', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _notes,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Add notes...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _onNotesChanged(pin, v),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text('Boards', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => showBoardPicker(context, pin),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add to Board'),
                  ),
                ],
              ),
              if (boards.isEmpty)
                Text(
                  'Not in any boards',
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final board in boards)
                      InputChip(
                        avatar: BoardGlyph(board.boardIcon, size: 18),
                        label: Text(board.name),
                        onDeleted: () => store.setBoards(
                          pin,
                          pin.boardIds.toSet()..remove(board.id),
                        ),
                      ),
                  ],
                ),
              const Divider(height: 32),
              Text(
                'Added ${MaterialLocalizations.of(context).formatMediumDate(pin.dateAdded)}',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              const SizedBox(height: 4),
              SelectableText(
                pin.urlString,
                maxLines: 2,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
