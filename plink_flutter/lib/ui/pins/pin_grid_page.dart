import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../data/library_store.dart';
import '../../models/board.dart';
import '../../models/pin.dart';
import '../../theme.dart';
import '../boards/board_picker_dialog.dart';
import '../settings/sync_page.dart';
import '../widgets/common.dart';
import 'add_pin_sheet.dart';
import 'pin_card.dart';
import 'pin_detail_page.dart';

/// Masonry grid of pins: every pin, or one board's pins when [board] is set.
class PinGridPage extends StatefulWidget {
  const PinGridPage({super.key, this.board});

  final Board? board;

  @override
  State<PinGridPage> createState() => _PinGridPageState();
}

class _PinGridPageState extends State<PinGridPage> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _reordering = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Pin> _filtered(LibraryStore store) {
    final board = widget.board;
    var pins = board == null ? store.pins : store.pinsIn(board);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      pins = pins
          .where(
            (p) =>
                p.title.toLowerCase().contains(q) ||
                p.domain.toLowerCase().contains(q) ||
                p.urlString.toLowerCase().contains(q) ||
                p.notes.toLowerCase().contains(q),
          )
          .toList();
    }
    return pins;
  }

  void _addPin() =>
      showAdaptiveSheet(context, (_) => AddPinSheet(board: widget.board));

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    final board = widget.board;
    final pins = _filtered(store);
    final canReorder = board != null && _query.isEmpty && pins.length > 1;
    final p = PlinkPalette.of(context);

    return LargeTitlePage(
      title: board?.name ?? 'All Pins',
      actions: [
        if (canReorder)
          _reordering
              ? TextButton(
                  onPressed: () => setState(() => _reordering = false),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                )
              : IconButton(
                  tooltip: 'Reorder',
                  icon: const Icon(Icons.swap_vert),
                  onPressed: () => setState(() => _reordering = true),
                ),
        if (board == null) const SyncButton(),
        IconButton(
          tooltip: 'Add Pin',
          icon: const Icon(Icons.add),
          onPressed: _addPin,
        ),
      ],
      header: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SearchBar(
          controller: _searchController,
          hintText: 'Search pins',
          leading: Icon(Icons.search, color: p.secondaryLabel),
          trailing: [
            if (_query.isNotEmpty)
              IconButton(
                icon: Icon(Icons.cancel, color: p.secondaryLabel, size: 18),
                onPressed: () => setState(() {
                  _searchController.clear();
                  _query = '';
                }),
              ),
          ],
          onChanged: (v) => setState(() {
            _query = v.trim();
            _reordering = false;
          }),
        ),
      ),
      slivers: _body(store, pins),
    );
  }

  List<Widget> _body(LibraryStore store, List<Pin> pins) {
    if (pins.isEmpty) {
      final Widget empty;
      if (_query.isNotEmpty) {
        empty = EmptyState(
          icon: Icons.search,
          title: 'No Results',
          subtitle: 'No pins match "$_query".',
        );
      } else if (widget.board == null) {
        empty = EmptyState(
          icon: Icons.push_pin,
          title: 'No Pins Yet',
          subtitle: 'Save links from the web to see them here.',
          actionTitle: 'Add a Link',
          onAction: _addPin,
        );
      } else {
        empty = EmptyState(
          icon: Icons.push_pin,
          title: 'No Pins',
          subtitle: 'This board is empty.',
          actionTitle: 'Add a Link',
          onAction: _addPin,
        );
      }
      return [SliverFillRemaining(hasScrollBody: false, child: empty)];
    }

    if (_reordering && widget.board != null) {
      final p = PlinkPalette.of(context);
      return [
        SliverReorderableList(
          itemCount: pins.length,
          onReorderItem: (from, to) =>
              store.reorderInBoard(widget.board!, from, to),
          itemBuilder: (context, i) {
            final pin = pins[i];
            return Material(
              key: ValueKey(pin.id),
              color: p.background,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: SizedBox.square(
                  dimension: 44,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: pin.imagePath != null
                        ? StoredImage(pin.imagePath!)
                        : ColoredBox(color: p.fill),
                  ),
                ),
                title: Text(
                  pin.title.isEmpty ? pin.urlString : pin.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: Text(
                  pin.domain,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: ReorderableDragStartListener(
                  index: i,
                  child: Icon(Icons.drag_handle, color: p.tertiaryLabel),
                ),
              ),
            );
          },
        ),
      ];
    }

    return [
      SliverLayoutBuilder(
        builder: (context, constraints) => SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: AppConstants.columnsForWidth(
              constraints.crossAxisExtent,
            ),
            mainAxisSpacing: AppConstants.cardSpacing,
            crossAxisSpacing: AppConstants.cardSpacing,
            childCount: pins.length,
            itemBuilder: (context, i) {
              final pin = pins[i];
              return ContextMenuRegion(
                key: ValueKey(pin.id),
                itemsBuilder: (menuContext) => pinMenuItems(menuContext, pin),
                child: PinCard(
                  pin: pin,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PinDetailPage(pinId: pin.id),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ];
  }
}

/// Context-menu actions shared by the grid and detail page.
List<PopupMenuEntry<void>> pinMenuItems(BuildContext context, Pin pin) {
  final store = context.read<LibraryStore>();
  final origin = originRect(context);
  PopupMenuItem<void> item(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) => PopupMenuItem(
    onTap: onTap,
    height: 44,
    // iOS menu row: label first, icon at the trailing edge.
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: color)),
        ),
        const SizedBox(width: 24),
        Icon(icon, size: 20, color: color ?? PlinkPalette.of(context).label),
      ],
    ),
  );

  return [
    item(
      Icons.open_in_browser,
      'Open in Browser',
      () => openLink(context, pin.urlString),
    ),
    item(
      Icons.ios_share,
      'Share',
      () => shareLink(context, pin.urlString, origin: origin),
    ),
    const PopupMenuDivider(),
    item(
      Icons.create_new_folder_outlined,
      'Add to Board',
      () => showBoardPicker(context, pin),
    ),
    item(Icons.copy, 'Copy Link', () => copyLink(context, pin.urlString)),
    const PopupMenuDivider(),
    item(
      Icons.delete_outline,
      'Delete',
      () => store.deletePin(pin),
      color: Theme.of(context).colorScheme.error,
    ),
  ];
}
