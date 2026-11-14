import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nas_sync/nas_sync.dart';
import 'package:path/path.dart' as p;

import '../data/library_store.dart';
import '../models/board.dart';
import '../models/pin.dart';

/// Sync items: each pin is one item (its fields as data, its image as the
/// blob, its favicon inline); each board is one more.
const pinKind = LibraryStore.pinKind;
const boardKind = LibraryStore.boardKind;

/// Favicons bigger than this aren't synced; the other device fetches its own.
const _maxSyncedFavicon = 256 * 1024;

// ---- Settings ------------------------------------------------------------------

/// Where sync keeps its settings and state (a file) and login (secure storage).
abstract class SyncSettingsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
  Future<String?> readSecret(String key);
  Future<void> writeSecret(String key, String? value);
}

/// A JSON file in app support, plus the login in the Keychain / Keystore /
/// system keyring.
class DeviceSyncSettingsStore implements SyncSettingsStore {
  DeviceSyncSettingsStore(String supportDirectory)
    : _file = File(p.join(supportDirectory, 'sync_settings.json'));

  final File _file;
  Map<String, String>? _values;
  static const _secure = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  Future<Map<String, String>> _load() async {
    if (_values != null) return _values!;
    try {
      final json = jsonDecode(await _file.readAsString()) as Map;
      return _values = json.cast<String, String>();
    } catch (_) {
      return _values = {};
    }
  }

  @override
  Future<String?> read(String key) async => (await _load())[key];

  @override
  Future<void> write(String key, String? value) async {
    final values = await _load();
    value == null ? values.remove(key) : values[key] = value;
    await _file.parent.create(recursive: true);
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode(values), flush: true);
    await tmp.rename(_file.path);
  }

  @override
  Future<String?> readSecret(String key) => _secure.read(key: key);

  @override
  Future<void> writeSecret(String key, String? value) => value == null
      ? _secure.delete(key: key)
      : _secure.write(key: key, value: value);
}

/// For tests.
class MemorySyncSettingsStore implements SyncSettingsStore {
  final Map<String, String> values = {};
  final Map<String, String> secrets = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async =>
      value == null ? values.remove(key) : values[key] = value;

  @override
  Future<String?> readSecret(String key) async => secrets[key];

  @override
  Future<void> writeSecret(String key, String? value) async =>
      value == null ? secrets.remove(key) : secrets[key] = value;
}

class _StateStorage implements SyncStateStorage {
  _StateStorage(this.settings);
  final SyncSettingsStore settings;

  @override
  Future<String?> read() => settings.read('sync.state');

  @override
  Future<void> write(String text) => settings.write('sync.state', text);
}

// ---- The library as a sync source --------------------------------------------------

class LibrarySyncSource extends SyncSource {
  LibrarySyncSource(this.library);

  final LibraryStore library;

  @override
  Future<SyncItem?> read(String kind, String key) async {
    switch (kind) {
      case pinKind:
        final pin = library.pinById(key);
        if (pin == null) return null;
        final favicon = await library.images.read(pin.faviconPath);
        return SyncItem(
          kind: kind,
          key: key,
          modified: pin.dateModified.millisecondsSinceEpoch,
          data: {
            'urlString': pin.urlString,
            'title': pin.title,
            'pageDescription': pin.pageDescription,
            'domain': pin.domain,
            'dateAdded': pin.dateAdded.millisecondsSinceEpoch,
            'notes': pin.notes,
            'boardIds': pin.boardIds,
            'sortOrder': pin.sortOrder,
            'isCustomImage': pin.isCustomImage,
            'metadataFetched': pin.metadataFetched,
            'imageAspectRatio': pin.imageAspectRatio,
            if (favicon != null && favicon.length <= _maxSyncedFavicon)
              'favicon': base64Encode(favicon),
          },
          blob: await library.images.read(pin.imagePath),
        );
      case boardKind:
        final board = library.boardById(key);
        if (board == null) return null;
        return SyncItem(
          kind: kind,
          key: key,
          modified: board.dateModified.millisecondsSinceEpoch,
          data: {
            'name': board.name,
            'icon': board.icon,
            'sortOrder': board.sortOrder,
            'dateCreated': board.dateCreated.millisecondsSinceEpoch,
          },
        );
    }
    return null;
  }

  @override
  Future<void> apply(SyncItem item) async {
    switch (item.kind) {
      case pinKind:
        if (item.deleted || item.data == null) {
          return library.removeRemotePin(item.key);
        }
        await library.putRemotePin(await _pinFrom(item));
      case boardKind:
        if (item.deleted || item.data == null) {
          return library.removeRemoteBoard(item.key);
        }
        final d = item.data!;
        library.putRemoteBoard(
          Board(
            id: item.key,
            name: d['name'] as String? ?? '',
            icon: d['icon'] as String? ?? 'folder',
            sortOrder: (d['sortOrder'] as num?)?.toInt() ?? 0,
            dateCreated: _date(d['dateCreated']),
            dateModified: DateTime.fromMillisecondsSinceEpoch(item.modified),
          ),
        );
    }
  }

  Future<Pin> _pinFrom(SyncItem item) async {
    final d = item.data!;
    final images = library.images;
    final favicon = d['favicon'] as String?;
    final hasImage = item.blob != null && item.blob!.isNotEmpty;
    return Pin(
      id: item.key,
      urlString: d['urlString'] as String? ?? '',
      title: d['title'] as String? ?? '',
      pageDescription: d['pageDescription'] as String? ?? '',
      domain: d['domain'] as String? ?? '',
      dateAdded: _date(d['dateAdded']),
      dateModified: DateTime.fromMillisecondsSinceEpoch(item.modified),
      notes: d['notes'] as String? ?? '',
      boardIds: (d['boardIds'] as List? ?? []).cast<String>().toList(),
      sortOrder: (d['sortOrder'] as num?)?.toInt() ?? 0,
      isCustomImage: d['isCustomImage'] as bool? ?? false,
      metadataFetched: d['metadataFetched'] as bool? ?? false,
      imageAspectRatio: (d['imageAspectRatio'] as num?)?.toDouble() ?? 1.5,
      imagePath: hasImage
          ? await images.writeFile(item.blob!, item.key, 'image')
          : null,
      faviconPath: favicon == null
          ? null
          : await images.writeFile(base64Decode(favicon), item.key, 'favicon'),
    );
  }

  static DateTime _date(Object? ms) => ms is num
      ? DateTime.fromMillisecondsSinceEpoch(ms.toInt())
      : DateTime.now();

  /// A pin edited on two devices: the newer edit wins, but notes from both
  /// are kept, and an image is kept if only the older version had one.
  /// Boards use plain newest-wins.
  @override
  Future<SyncItem?> merge(SyncItem local, SyncItem remote) async {
    if (local.kind != pinKind) return null;
    final (winner, loser) = remote.modified >= local.modified
        ? (remote, local)
        : (local, remote);
    final data = {...winner.data!};
    final winnerNotes = (winner.data!['notes'] as String? ?? '').trim();
    final loserNotes = (loser.data!['notes'] as String? ?? '').trim();
    if (loserNotes.isNotEmpty && !winnerNotes.contains(loserNotes)) {
      final from = loser.device == null ? '' : ' (from ${loser.device})';
      data['notes'] = winnerNotes.isEmpty
          ? loserNotes
          : '$winnerNotes\n\n--- Conflicting notes$from ---\n$loserNotes';
    }
    var blob = winner.blob;
    if ((blob == null || blob.isEmpty) && loser.blob != null) {
      blob = loser.blob;
      data['imageAspectRatio'] = loser.data!['imageAspectRatio'];
      data['isCustomImage'] = loser.data!['isCustomImage'];
    }
    data['favicon'] ??= loser.data!['favicon'];
    return SyncItem(
      kind: pinKind,
      key: winner.key,
      modified: winner.modified,
      data: data,
      blob: blob,
    );
  }
}

// ---- The controller the UI talks to ------------------------------------------------

enum SyncStatus {
  /// Not signed in.
  off,
  idle,
  syncing,

  /// The server couldn't be reached (no Tailscale, no network...).
  offline,
  error,
}

/// Plink's sync with the NAS: sign-in, status, and when to sync.
class PlinkSync extends ChangeNotifier {
  PlinkSync({
    required this.library,
    required this.settings,
    String? device,
    this.debounce = const Duration(seconds: 5),
    this.period = const Duration(minutes: 5),
    this.retryDelay = const Duration(seconds: 2),
    this.appName = app,
    PbClient Function(String url, {PbAuth? auth})? clientFactory,
  }) : _newClient = clientFactory ?? _defaultClient {
    engine = NasSync(
      client: _newClient('http://localhost/'),
      app: appName,
      device: device ?? _deviceName(),
      source: LibrarySyncSource(library),
      storage: _StateStorage(settings),
    );
    library.onLocalChange = (c) => changed(
      c.kind,
      c.id,
      deleted: c.deleted,
      modified: c.modified.millisecondsSinceEpoch,
    );
  }

  /// The app name the server files Plink's items under. Never change it.
  static const app = 'plink';

  final LibraryStore library;
  final SyncSettingsStore settings;
  final Duration debounce;
  final Duration period;
  final Duration retryDelay;
  final String appName;
  final PbClient Function(String url, {PbAuth? auth}) _newClient;
  late final NasSync engine;

  static PbClient _defaultClient(String url, {PbAuth? auth}) =>
      PbClient(url, auth: auth);

  String? url;
  SyncStatus status = SyncStatus.off;

  /// What went wrong, or a problem from the last sync.
  String? message;
  DateTime? lastSynced;

  Timer? _debounceTimer;
  Timer? _periodic;
  AppLifecycleListener? _lifecycle;

  static String _deviceName() {
    try {
      final host = Platform.localHostname.split('.').first;
      if (host.isNotEmpty) return host;
    } catch (_) {}
    return defaultTargetPlatform.name;
  }

  bool get signedIn => engine.client.auth != null;
  String? get email => engine.client.auth?.email;

  /// Restores a saved login and starts syncing. Call once at startup.
  Future<void> init({bool background = true}) async {
    url = await settings.read('sync.url');
    final saved = await settings.readSecret('sync.auth');
    if (url != null && saved != null) {
      engine.client = _newClient(
        url!,
        auth: PbAuth.fromJson(jsonDecode(saved) as Map<String, dynamic>),
      );
      status = SyncStatus.idle;
      notifyListeners();
    }
    if (background) {
      _periodic = Timer.periodic(period, (_) => syncNow());
      _lifecycle = AppLifecycleListener(onResume: syncNow);
    }
    if (!signedIn) return;
    try {
      await _retryOnce(engine.client.refresh).then(_remember);
    } on PbException catch (e) {
      if (e.isAuth) return _lostLogin();
    } catch (_) {
      // Offline: keep the saved login and try again on the next sync.
    }
    await syncNow();
  }

  Future<void> _remember(PbAuth auth) =>
      settings.writeSecret('sync.auth', jsonEncode(auth.toJson()));

  /// The first request often times out while the Tailscale path comes up,
  /// so network errors get one retry. Server errors don't.
  Future<T> _retryOnce<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PbException {
      rethrow;
    } catch (_) {
      await Future<void>.delayed(retryDelay);
      return run();
    }
  }

  /// Signs in with an account from the NAS admin page. Throws [PbException]
  /// (wrong password) or a network error (server not reachable).
  Future<void> signIn(String serverUrl, String email, String password) async {
    final cleaned = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final client = _newClient(cleaned);
    await _remember(
      await _retryOnce(() => client.signIn(email.trim(), password)),
    );
    await settings.write('sync.url', cleaned);
    url = cleaned;
    engine.client = client;
    status = SyncStatus.idle;
    message = null;
    notifyListeners();
    await syncNow();
  }

  /// Stops syncing on this device. Pins stay here, and on the server.
  Future<void> signOut() async {
    engine.client.auth = null;
    await settings.writeSecret('sync.auth', null);
    status = SyncStatus.off;
    message = null;
    notifyListeners();
  }

  Future<void> _lostLogin() async {
    await signOut();
    status = SyncStatus.error;
    message =
        'Your sign-in expired or was removed. Sign in again to keep syncing.';
    notifyListeners();
  }

  /// Notes a local change and syncs soon after.
  Future<void> changed(
    String kind,
    String key, {
    bool deleted = false,
    int? modified,
  }) async {
    await engine.markChanged(kind, key, deleted: deleted, modified: modified);
    if (!signedIn) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, syncNow);
  }

  /// Syncs now (no-op when signed out).
  Future<void> syncNow() async {
    if (!signedIn) return;
    _debounceTimer?.cancel();
    status = SyncStatus.syncing;
    notifyListeners();
    try {
      await engine.adopt([
        for (final pin in library.pins)
          (
            kind: pinKind,
            key: pin.id,
            modified: pin.dateModified.millisecondsSinceEpoch,
          ),
        for (final board in library.boards)
          (
            kind: boardKind,
            key: board.id,
            modified: board.dateModified.millisecondsSinceEpoch,
          ),
      ]);
      final report = await _retryOnce(engine.sync);
      status = SyncStatus.idle;
      lastSynced = DateTime.now();
      message = report.problems.isEmpty
          ? null
          : 'Some pins could not be sent: ${report.problems.join('; ')}';
    } on PbException catch (e) {
      if (e.isAuth) return _lostLogin();
      status = SyncStatus.error;
      message = e.message;
    } on StateError {
      status = SyncStatus.off;
    } catch (e) {
      // Socket, TLS and timeout errors: most likely Tailscale is off or the NAS is down.
      status = SyncStatus.offline;
      message = 'Could not reach the server. Is Tailscale on?';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _periodic?.cancel();
    _lifecycle?.dispose();
    library.onLocalChange = null;
    super.dispose();
  }
}
