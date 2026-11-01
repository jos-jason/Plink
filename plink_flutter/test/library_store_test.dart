import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plink/data/library_store.dart';
import 'package:plink/models/pin.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('plink_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('persists pins and boards across reopen', () async {
    final store = await LibraryStore.open(dir.path);
    final board = store.createBoard('Travel', icon: 'airplane');
    store.addPin(
      Pin(
        urlString: 'https://a.com',
        title: 'A',
        boardIds: [board.id],
        metadataFetched: true,
      ),
    );
    await store.save();

    final reopened = await LibraryStore.open(dir.path);
    expect(reopened.boards.single.icon, 'airplane');
    expect(reopened.pinsIn(reopened.boards.single).single.title, 'A');
  });

  test('deleting a board keeps its pins', () async {
    final store = await LibraryStore.open(dir.path);
    final board = store.createBoard('X');
    store.addPin(
      Pin(
        urlString: 'https://a.com',
        boardIds: [board.id],
        metadataFetched: true,
      ),
    );
    store.deleteBoard(board);
    expect(store.pins.single.boardIds, isEmpty);
  });

  test('import skips IDs already in the library', () async {
    final store = await LibraryStore.open(dir.path);
    store.addPin(Pin(urlString: 'https://a.com', metadataFetched: true));
    final backup = store.exportBackup();
    expect(store.importBackup(backup), 0);
    expect(store.pins, hasLength(1));
  });

  test('reorders pins within a board', () async {
    final store = await LibraryStore.open(dir.path);
    final board = store.createBoard('X');
    for (final (i, u) in ['a', 'b', 'c'].indexed) {
      store.addPin(
        Pin(
          urlString: 'https://$u.com',
          boardIds: [board.id],
          sortOrder: i,
          metadataFetched: true,
        ),
      );
    }
    store.reorderInBoard(board, 2, 0);
    expect(store.pinsIn(board).map((p) => p.urlString), [
      'https://c.com',
      'https://a.com',
      'https://b.com',
    ]);
  });
}
