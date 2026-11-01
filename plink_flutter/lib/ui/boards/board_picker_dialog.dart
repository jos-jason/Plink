import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/library_store.dart';
import '../../models/pin.dart';
import 'board_editor_dialog.dart';

Future<void> showBoardPicker(BuildContext context, Pin pin) => showDialog<void>(
  context: context,
  builder: (_) => ChangeNotifierProvider.value(
    value: context.read<LibraryStore>(),
    child: _BoardPicker(pin: pin),
  ),
);

class _BoardPicker extends StatelessWidget {
  const _BoardPicker({required this.pin});

  final Pin pin;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    final boards = store.boards;
    return AlertDialog(
      title: const Text('Add to Board'),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: SizedBox(
        width: 360,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final board in boards)
              CheckboxListTile(
                secondary: Icon(board.iconData),
                title: Text(board.name),
                value: pin.boardIds.contains(board.id),
                onChanged: (checked) {
                  final ids = pin.boardIds.toSet();
                  checked == true ? ids.add(board.id) : ids.remove(board.id);
                  store.setBoards(pin, ids);
                },
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New Board'),
              onTap: () async {
                final board = await showBoardEditor(context);
                if (board != null) {
                  store.setBoards(pin, {...pin.boardIds, board.id});
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
