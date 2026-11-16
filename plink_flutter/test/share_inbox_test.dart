import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plink/data/library_store.dart';
import 'package:plink/data/share_inbox.dart';

void main() {
  late Directory dir;
  late LibraryStore store;
  late ShareInbox inbox;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('plink_share');
    store = await LibraryStore.open('${dir.path}/app');
    inbox = ShareInbox(store, containerPath: () async => '${dir.path}/group');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  void share(String name, Map<String, Object?> item) {
    final folder = Directory('${dir.path}/group/share/inbox')
      ..createSync(recursive: true);
    File('${folder.path}/$name.json').writeAsStringSync(jsonEncode(item));
  }

  test('writes boards for the extension, with SF Symbols', () async {
    store.createBoard('Recipes');
    store.createBoard('3D Printing');
    await inbox.start(listen: false);
    final json = jsonDecode(
      File('${dir.path}/group/share/boards.json').readAsStringSync(),
    );
    expect(
      [for (final b in json['boards']) '${b['name']}: ${b['symbol']}'],
      ['Recipes: fork.knife', '3D Printing: printer.fill'],
    );
  });

  test(
    'imports shared links as pins, oldest first, then empties the inbox',
    () async {
      final board = store.createBoard('Boats');
      share('b', {
        'url': 'https://example.com/second',
        'title': 'Second',
        'boardIds': [board.id, 'deleted-board'],
        'sharedAt': 2000,
      });
      share('a', {'url': 'https://example.com/first', 'sharedAt': 1000});
      share('c', {'url': 'not a link', 'sharedAt': 3000});

      await inbox.start(listen: false);

      expect(store.pins.map((p) => p.urlString), [
        'https://example.com/second',
        'https://example.com/first',
      ]);
      final second = store.pins.first;
      expect(second.title, 'Second');
      expect(second.domain, 'example.com');
      expect(second.boardIds, [board.id]);
      expect(second.metadataFetched, isFalse);
      expect(Directory('${dir.path}/group/share/inbox').listSync(), isEmpty);
    },
  );

  test('does nothing where there is no App Group', () async {
    final none = ShareInbox(store, containerPath: () async => null);
    await none.start(listen: false);
    expect(await none.importPending(), 0);
  });

  test('Android shares: finds the link in shared text', () {
    expect(
      AndroidShares.firstLink('Look at this! https://a.co/d/abc123.'),
      'https://a.co/d/abc123',
    );
    expect(
      AndroidShares.firstLink('https://www.instagram.com/p/XYZ/?igsh=1'),
      'https://www.instagram.com/p/XYZ/?igsh=1',
    );
    expect(AndroidShares.firstLink('no link here'), isNull);
  });
}
