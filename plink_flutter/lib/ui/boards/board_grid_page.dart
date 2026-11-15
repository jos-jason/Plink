import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../data/library_store.dart';
import '../../models/board.dart';
import '../../theme.dart';
import '../pins/pin_grid_page.dart';
import '../widgets/common.dart';
import 'board_editor_dialog.dart';

/// Boards tab on phones: a masonry grid of board covers.
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
          SliverLayoutBuilder(
            builder: (context, constraints) => SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: AppConstants.columnsForWidth(
                  constraints.crossAxisExtent,
                ),
                mainAxisSpacing: AppConstants.cardSpacing,
                crossAxisSpacing: AppConstants.cardSpacing,
                childCount: boards.length,
                itemBuilder: (context, i) => _BoardCard(board: boards[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.board});

  final Board board;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    final theme = Theme.of(context);
    final p = PlinkPalette.of(context);
    final cover = store.coverPinFor(board);
    final count = store.pinsIn(board).length;

    return ContextMenuRegion(
      itemsBuilder: (_) => [
        PopupMenuItem(
          onTap: () => showBoardEditor(context, board: board),
          child: const Text('Rename'),
        ),
        PopupMenuItem(
          onTap: () => confirmDeleteBoard(context, board),
          child: Text(
            'Delete',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ],
      child: PlinkCard(
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => PinGridPage(board: board))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover height follows the cover pin's image, as on iOS.
            AspectRatio(
              aspectRatio: (cover?.imageAspectRatio ?? 1.3).clamp(0.4, 3.0),
              child: cover != null
                  ? StoredImage(cover.imagePath!)
                  : ColoredBox(
                      color: p.fill,
                      child: Icon(
                        board.iconData,
                        size: 36,
                        color: p.tertiaryLabel,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    board.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count ${count == 1 ? 'pin' : 'pins'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
