import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../data/library_store.dart';
import 'boards/board_editor_dialog.dart';
import 'boards/board_grid_page.dart';
import 'pins/pin_grid_page.dart';
import 'settings/settings_page.dart';

/// Bottom tabs on narrow screens (phones), sidebar on wide ones (tablets,
/// desktop) — the same split the Swift app makes on size class.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth < AppConstants.compactBreakpoint
          ? const _TabShell()
          : const _SidebarShell(),
    );
  }
}

class _TabShell extends StatefulWidget {
  const _TabShell();

  @override
  State<_TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<_TabShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [PinGridPage(), BoardGridPage(), SettingsPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.push_pin_outlined),
            label: 'Pins',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            label: 'Boards',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

sealed class _Destination {
  const _Destination();
}

class _AllPins extends _Destination {
  const _AllPins();
}

class _BoardDest extends _Destination {
  const _BoardDest(this.boardId);
  final String boardId;
}

class _Settings extends _Destination {
  const _Settings();
}

class _SidebarShell extends StatefulWidget {
  const _SidebarShell();

  @override
  State<_SidebarShell> createState() => _SidebarShellState();
}

class _SidebarShellState extends State<_SidebarShell> {
  _Destination _selected = const _AllPins();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    final theme = Theme.of(context);

    Widget content;
    switch (_selected) {
      case _AllPins():
        content = const PinGridPage();
      case _BoardDest(:final boardId):
        final board = store.boardById(boardId);
        content = board == null
            ? const PinGridPage()
            : PinGridPage(key: ValueKey(boardId), board: board);
      case _Settings():
        content = const SettingsPage();
    }

    bool isBoard(String id) =>
        _selected is _BoardDest && (_selected as _BoardDest).boardId == id;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 240,
            child: Material(
              color: theme.colorScheme.surfaceContainerLow,
              child: SafeArea(
                right: false,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Text(
                        'Plink',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _SidebarTile(
                      icon: Icons.push_pin_outlined,
                      label: 'All Pins',
                      selected: _selected is _AllPins,
                      onTap: () => setState(() => _selected = const _AllPins()),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                      child: Text(
                        'Boards',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final board in store.boards)
                      _SidebarTile(
                        icon: board.iconData,
                        label: board.name,
                        selected: isBoard(board.id),
                        onTap: () =>
                            setState(() => _selected = _BoardDest(board.id)),
                        menu: [
                          PopupMenuItem(
                            onTap: () => showBoardEditor(context, board: board),
                            child: const Text('Rename'),
                          ),
                          PopupMenuItem(
                            onTap: () {
                              if (isBoard(board.id)) {
                                _selected = const _AllPins();
                              }
                              confirmDeleteBoard(context, board);
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    _SidebarTile(
                      icon: Icons.add,
                      label: 'New Board',
                      color: theme.colorScheme.primary,
                      onTap: () async {
                        final board = await showBoardEditor(context);
                        if (board != null) {
                          setState(() => _selected = _BoardDest(board.id));
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    _SidebarTile(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      selected: _selected is _Settings,
                      onTap: () =>
                          setState(() => _selected = const _Settings()),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.color,
    this.menu,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color? color;
  final List<PopupMenuEntry<void>>? menu;

  @override
  Widget build(BuildContext context) {
    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 20),
        title: Text(
          label,
          style: TextStyle(color: color),
          overflow: TextOverflow.ellipsis,
        ),
        selected: selected,
        selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: onTap,
      ),
    );
    if (menu == null) return tile;
    return GestureDetector(
      onSecondaryTapDown: (d) => _showMenu(context, d.globalPosition),
      onLongPressStart: (d) => _showMenu(context, d.globalPosition),
      child: tile,
    );
  }

  void _showMenu(BuildContext context, Offset position) {
    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: menu!,
    );
  }
}
