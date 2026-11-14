import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../data/library_store.dart';
import '../../models/board.dart';
import '../../models/pin.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(board?.name ?? 'All Pins'),
        actions: [
          if (canReorder)
            IconButton(
              tooltip: _reordering ? 'Done' : 'Reorder',
              icon: Icon(_reordering ? Icons.check : Icons.swap_vert),
              onPressed: () => setState(() => _reordering = !_reordering),
            ),
          if (board == null) const SyncButton(),
          IconButton(
            tooltip: 'Add Pin',
            icon: const Icon(Icons.add),
            onPressed: _addPin,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search pins',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close),
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
        ),
      ),
      body: _body(store, pins),
    );
  }

  Widget _body(LibraryStore store, List<Pin> pins) {
    if (pins.isEmpty) {
      if (_query.isNotEmpty) {
        return EmptyState(
          icon: Icons.search,
          title: 'No Results',
          subtitle: 'No pins match "$_query".',
        );
      }
      return widget.board == null
          ? EmptyState(
              icon: Icons.push_pin_outlined,
              title: 'No Pins Yet',
              subtitle: 'Save links from the web to see them here.',
              actionTitle: 'Add a Link',
              onAction: _addPin,
            )
          : EmptyState(
              icon: Icons.push_pin_outlined,
              title: 'No Pins',
              subtitle: 'This board is empty.',
              actionTitle: 'Add a Link',
              onAction: _addPin,
            );
    }

    if (_reordering && widget.board != null) {
      return ReorderableListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: pins.length,
        onReorderItem: (from, to) =>
            store.reorderInBoard(widget.board!, from, to),
        itemBuilder: (context, i) {
          final pin = pins[i];
          return ListTile(
            key: ValueKey(pin.id),
            leading: SizedBox.square(
              dimension: 44,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: pin.imagePath != null
                    ? StoredImage(pin.imagePath!)
                    : const ColoredBox(color: Colors.black12),
              ),
            ),
            title: Text(
              pin.title.isEmpty ? pin.urlString : pin.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(pin.domain),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => MasonryGridView.count(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        crossAxisCount: AppConstants.columnsForWidth(constraints.maxWidth),
        mainAxisSpacing: AppConstants.cardSpacing,
        crossAxisSpacing: AppConstants.cardSpacing,
        itemCount: pins.length,
        itemBuilder: (context, i) {
          final pin = pins[i];
          return ContextMenuRegion(
            key: ValueKey(pin.id),
            itemsBuilder: (menuContext) => pinMenuItems(menuContext, pin),
            child: PinCard(
              pin: pin,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PinDetailPage(pinId: pin.id)),
              ),
            ),
          );
        },
      ),
    );
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
    child: ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
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
