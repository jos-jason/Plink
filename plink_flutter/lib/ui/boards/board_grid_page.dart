import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../data/library_store.dart';
import '../../models/board.dart';
import '../../theme.dart';
import '../pins/pin_grid_page.dart';
import '../widgets/common.dart';
import '../widgets/board_glyph.dart';
import 'board_editor_dialog.dart';

/// Boards tab on phones: a grid of board icon tiles.
class BoardGridPage extends StatelessWidget {
  const BoardGridPage({super.key});

  @override
  Widget build(BuildContext context) {
    final boards = context.watch<LibraryStore>().boards;

    return LargeTitlePage(
      title: 'Boards',
      actions: [
        IconButton(
          tooltip: 'New Board',
          icon: const Icon(Icons.add),
          onPressed: () => showBoardEditor(context),
        ),
      ],
      slivers: [
        if (boards.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.folder,
              title: 'No Boards',
              subtitle: 'Group your pins into boards.',
              actionTitle: 'New Board',
              onAction: () => showBoardEditor(context),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 100,
                mainAxisSpacing: AppConstants.cardSpacing,
                crossAxisSpacing: AppConstants.cardSpacing,
                childAspectRatio: 0.8,
              ),
              itemCount: boards.length,
              itemBuilder: (context, i) => _BoardTile(board: boards[i]),
            ),
          ),
      ],
    );
  }
}

/// A board as an icon tile, like the iOS share sheet's board picker.
class _BoardTile extends StatelessWidget {
  const _BoardTile({required this.board});

  final Board board;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = PlinkPalette.of(context);
    final radius = BorderRadius.circular(16);

    return ContextMenuRegion(
      itemsBuilder: (_) => [
        PopupMenuItem(
          onTap: () => showBoardEditor(context, board: board),
          child: const Text('Edit Board'),
        ),
        PopupMenuItem(
          onTap: () => confirmDeleteBoard(context, board),
          child: Text(
            'Delete',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ],
      child: Material(
        color: p.fill,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => PinGridPage(board: board))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BoardGlyph(board.boardIcon, size: 30, color: p.label),
                const SizedBox(height: 8),
                _TileLabel(
                  board.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Up to two centered lines. A single long word ("Backpacking") shrinks to
/// fit on one line instead of breaking mid-word.
class _TileLabel extends StatelessWidget {
  const _TileLabel(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (!text.trim().contains(' ')) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, maxLines: 1, style: style),
      );
    }
    return Text(
      text,
      maxLines: 2,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
