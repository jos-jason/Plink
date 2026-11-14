// Library sync through nas_sync's engine. By default runs against an
// in-memory fake of the server; set NAS_SYNC_TEST_URL to a local PocketBase
// made from the nas-sync repo's server/ (users alice and bob) to run the
// same tests against the real thing:
//   NAS_SYNC_TEST_URL=http://127.0.0.1:18090 flutter test test/sync_test.dart
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nas_sync/nas_sync.dart';
import 'package:plink/data/library_store.dart';
import 'package:plink/models/pin.dart';
import 'package:plink/sync/plink_sync.dart';

import 'sync/fake_pocketbase.dart';

final realUrl = Platform.environment['NAS_SYNC_TEST_URL'];

late FakePocketBase server;
late String app;
final _dirs = <Directory>[];

class Device {
  Device._(this.store, this.sync);

  final LibraryStore store;
  final PlinkSync sync;

  static Future<Device> start(String name, {String? user}) async {
    final dir = Directory.systemTemp.createTempSync('plink_sync_$name');
    _dirs.add(dir);
    final store = await LibraryStore.open(dir.path);
    final sync = PlinkSync(
      library: store,
      settings: MemorySyncSettingsStore(),
      device: name,
      debounce: const Duration(hours: 1),
      retryDelay: Duration.zero,
      appName: app,
      clientFactory: realUrl != null
          ? null
          : (url, {auth}) => FakePbClient(server, auth: auth),
    );
    final d = Device._(store, sync);
    await sync.init(background: false);
    if (user != null) await d.signIn(user);
    return d;
  }

  Future<void> signIn(String user) => sync.signIn(
    realUrl ?? 'http://fake.test',
    '$user@test.local',
    'pw-$user-12345',
  );

  Future<void> syncNow() => sync.syncNow();

  Pin titled(String t) => store.pins.firstWhere((p) => p.title == t);

  List<String> get titles => [for (final p in store.pins) p.title]..sort();
}

/// Distinct edit times on a fast machine.
Future<void> later() => Future.delayed(const Duration(milliseconds: 5));

Pin newPin(String title, {List<String>? boards}) => Pin(
  urlString: 'https://example.com/${title.toLowerCase()}',
  title: title,
  domain: 'example.com',
  metadataFetched: true,
  boardIds: boards,
);

final jpeg = img.encodeJpg(img.Image(width: 40, height: 20));
final png = img.encodePng(img.Image(width: 16, height: 16));

void main() {
  setUp(() {
    server = FakePocketBase();
    app = 'plinktest${Random().nextInt(1 << 32)}';
  });
  tearDownAll(() {
    for (final d in _dirs) {
      d.deleteSync(recursive: true);
    }
  });

  test(
    'pins, boards and images made before signing in reach another device',
    () async {
      final a = await Device.start('A');
      final board = a.store.createBoard('Recipes', icon: 'fork.knife');
      final pin = newPin('Soup', boards: [board.id])..notes = 'add salt';
      a.store.addPin(pin);
      await a.store.setImage(pin, jpeg, custom: true);
      pin.faviconPath = await a.store.images.saveFavicon(png, pin.id);
      a.store.addPin(newPin('Loose'));
      await a.signIn('alice');
      expect(a.sync.status, SyncStatus.idle, reason: a.sync.message);

      final b = await Device.start('B', user: 'alice');
      expect(b.titles, ['Loose', 'Soup']);
      final got = b.titled('Soup');
      expect(got.notes, 'add salt');
      expect(got.boardIds, [board.id]);
      expect(b.store.boardById(board.id)?.icon, 'fork.knife');
      expect(got.imageAspectRatio, closeTo(2.0, 0.01));
      expect(await b.store.images.read(got.imagePath), isNotNull);
      expect(await b.store.images.read(got.faviconPath), png);
      // What B pulled isn't sent back as B's own change.
      expect(await b.sync.engine.hasPending, isFalse);
    },
  );

  test('edits and deletes follow', () async {
    final a = await Device.start('A', user: 'alice');
    final b = await Device.start('B', user: 'alice');
    final board = a.store.createBoard('Travel');
    final keep = newPin('Keep', boards: [board.id]);
    final gone = newPin('Gone');
    a.store
      ..addPin(keep)
      ..addPin(gone);
    await a.syncNow();
    await b.syncNow();
    expect(b.titles, ['Gone', 'Keep']);

    await later();
    b.titled('Keep').title = 'Kept';
    b.store.updatePin(b.titled('Kept'));
    await b.store.deletePin(b.titled('Gone'));
    await b.syncNow();
    await a.syncNow();
    expect(a.titles, ['Kept']);

    await later();
    a.store.deleteBoard(a.store.boardById(board.id)!);
    await a.syncNow();
    await b.syncNow();
    expect(b.store.boards, isEmpty);
    expect(b.titled('Kept').boardIds, isEmpty);
  });

  test('notes edited on two devices are both kept', () async {
    final a = await Device.start('A', user: 'alice');
    final b = await Device.start('B', user: 'alice');
    final pin = newPin('Shared');
    a.store.addPin(pin);
    await a.syncNow();
    await b.syncNow();

    a.titled('Shared').notes = 'from A';
    a.store.updatePin(a.titled('Shared'));
    await later();
    b.titled('Shared').notes = 'from B';
    b.store.updatePin(b.titled('Shared'));

    await a.syncNow();
    await b.syncNow(); // B is newer: B's notes win, A's are appended.
    await a.syncNow();
    for (final d in [a, b]) {
      final notes = d.titled('Shared').notes;
      expect(notes, startsWith('from B'));
      expect(notes, contains('from A'));
    }
  });

  test('accounts are kept apart', () async {
    final a = await Device.start('A', user: 'alice');
    a.store.addPin(newPin('Private'));
    await a.syncNow();
    final b = await Device.start('B', user: 'bob');
    expect(b.store.pins, isEmpty);
  });

  test('a wrong password fails sign-in and leaves sync off', () async {
    final a = await Device.start('A');
    await expectLater(
      a.sync.signIn(realUrl ?? 'http://fake.test', 'alice@test.local', 'nope'),
      throwsA(isA<PbException>()),
    );
    expect(a.sync.signedIn, isFalse);
  });

  group('fake server only', skip: realUrl != null, () {
    test('a timed-out first request is retried', () async {
      final a = await Device.start('A', user: 'alice');
      a.store.addPin(newPin('Retry'));
      server.failNextRequests = 1;
      await a.syncNow();
      expect(a.sync.status, SyncStatus.idle);
      expect(server.records, hasLength(1));
    });

    test('an unreachable server shows offline and keeps the login', () async {
      final a = await Device.start('A', user: 'alice');
      server.failNextRequests = 10;
      await a.syncNow();
      expect(a.sync.status, SyncStatus.offline);
      expect(a.sync.signedIn, isTrue);
    });

    test('a revoked login asks to sign in again', () async {
      final a = await Device.start('A', user: 'alice');
      server.rejectTokens = true;
      await a.syncNow();
      expect(a.sync.signedIn, isFalse);
      expect(a.sync.status, SyncStatus.error);
    });
  });
}
