import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/library_store.dart';
import '../../models/board.dart';
import '../../models/board_icons.dart';
import '../../theme.dart';
import '../widgets/board_glyph.dart';

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
  final _search = TextEditingController();
  late String _icon = _initialIcon();

  /// Once the user taps an icon, typing the name stops changing it.
  late bool _picked = widget.board != null && widget.board!.icon != 'folder';

  String _initialIcon() {
    final board = widget.board;
    if (board == null) return 'folder';
    final chosen = boardIconForKey(board.icon);
    if (chosen != null && chosen.key != 'folder') return chosen.key;
    return suggestBoardIcon(board.name)?.key ?? 'folder';
  }

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  void _nameChanged(String name) {
    setState(() {
      if (!_picked) _icon = suggestBoardIcon(name)?.key ?? 'folder';
    });
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
    final p = PlinkPalette.of(context);
    final icons = searchBoardIcons(_search.text);
    return AlertDialog(
      title: Text(widget.board == null ? 'New Board' : 'Edit Board'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.board == null,
              decoration: InputDecoration(
                hintText: 'Board name',
                prefixIcon: Center(
                  widthFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: BoardGlyph(
                      boardIconForKey(_icon) ?? boardIconCatalog.first,
                      size: 22,
                      color: plinkAccent,
                    ),
                  ),
                ),
              ),
              onChanged: _nameChanged,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search icons',
                prefixIcon: Icon(Icons.search, color: p.secondaryLabel),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: icons.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No icons match "${_search.text}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.secondaryLabel),
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 78,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 0.9,
                            ),
                        itemCount: icons.length,
                        itemBuilder: (context, i) => _IconChoice(
                          choice: icons[i],
                          selected: icons[i].key == _icon,
                          onTap: () => setState(() {
                            _icon = icons[i].key;
                            _picked = true;
                          }),
                        ),
                      ),
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

/// A small icon tile; the selected one is amber, as in the iOS share sheet.
class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final BoardIcon choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PlinkPalette.of(context);
    final color = selected ? plinkAccent : p.label;
    final radius = BorderRadius.circular(12);
    return Tooltip(
      message: choice.label,
      child: Material(
        color: selected ? plinkAccent.withValues(alpha: 0.14) : p.fill,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? plinkAccent : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BoardGlyph(choice, size: 24, color: color),
                const SizedBox(height: 4),
                Text(
                  choice.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
