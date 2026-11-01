import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../data/library_store.dart';
import '../../models/board.dart';
import '../pins/pin_grid_page.dart';
import '../widgets/common.dart';
import 'board_editor_dialog.dart';

/// Boards tab on phones: a grid of board covers.
class BoardGridPage extends StatelessWidget {
  const BoardGridPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    final boards = store.boards;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boards'),
        actions: [
          IconButton(
            tooltip: 'New Board',
            icon: const Icon(Icons.add),
            onPressed: () => showBoardEditor(context),
          ),
        ],
      ),
      body: boards.isEmpty
          ? EmptyState(
              icon: Icons.folder_outlined,
              title: 'No Boards',
              subtitle: 'Group your pins into boards.',
              actionTitle: 'New Board',
              onAction: () => showBoardEditor(context),
            )
          : LayoutBuilder(
              builder: (context, constraints) => GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: AppConstants.columnsForWidth(
                    constraints.maxWidth,
                  ),
                  mainAxisSpacing: AppConstants.cardSpacing,
                  crossAxisSpacing: AppConstants.cardSpacing,
                  childAspectRatio: 0.85,
                ),
                itemCount: boards.length,
                itemBuilder: (context, i) => _BoardCard(board: boards[i]),
              ),
            ),
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
    final cover = store.coverImageFor(board);
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
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardCornerRadius),
        ),
        child: InkWell(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => PinGridPage(board: board))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: cover != null
                    ? StoredImage(cover)
                    : ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          board.iconData,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant,
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
                    Text(
                      '$count ${count == 1 ? 'pin' : 'pins'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
