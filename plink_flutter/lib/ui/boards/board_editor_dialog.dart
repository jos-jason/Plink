import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/library_store.dart';
import '../../models/board.dart';

/// Creates a board, or renames [board] when given. Returns the board on save.
Future<Board?> showBoardEditor(BuildContext context, {Board? board}) {
  final store = context.read<LibraryStore>();
  return showDialog<Board>(
    context: context,
    builder: (_) => _BoardEditor(store: store, board: board),
  );
}

Future<void> confirmDeleteBoard(BuildContext context, Board board) async {
  final store = context.read<LibraryStore>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete "${board.name}"?'),
      content: const Text('Pins in this board stay in your library.'),
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
  if (confirmed == true) store.deleteBoard(board);
}

class _BoardEditor extends StatefulWidget {
  const _BoardEditor({required this.store, this.board});

  final LibraryStore store;
  final Board? board;

  @override
  State<_BoardEditor> createState() => _BoardEditorState();
}

class _BoardEditorState extends State<_BoardEditor> {
  late final _name = TextEditingController(text: widget.board?.name ?? '');
  late String _icon = widget.board?.icon ?? 'folder';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final existing = widget.board;
    if (existing != null) {
      existing
        ..name = name
        ..icon = _icon;
      widget.store.updateBoard(existing);
      Navigator.pop(context, existing);
    } else {
      Navigator.pop(context, widget.store.createBoard(name, icon: _icon));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.board == null ? 'New Board' : 'Edit Board'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Board name'),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                children: [
                  for (final entry in boardIcons.entries)
                    IconButton(
                      isSelected: entry.key == _icon,
                      style: IconButton.styleFrom(
                        backgroundColor: entry.key == _icon
                            ? scheme.primaryContainer
                            : null,
                      ),
                      icon: Icon(entry.value),
                      onPressed: () => setState(() => _icon = entry.key),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _save,
          child: Text(widget.board == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}
