import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../constants.dart';
import '../models/board.dart';
import '../models/pin.dart';
import 'library_store.dart';

/// The app's side of the iOS share extension ("Save to Plink").
///
/// Both live in the `group.Babymechanical.Plink` App Group. The app keeps
/// `share/boards.json` current so the extension can offer boards, and the
/// extension drops one `share/inbox/*.json` file per saved link, which the
/// app turns into pins on launch and whenever it returns to the foreground.
class ShareInbox {
  ShareInbox(this.store, {Future<String?> Function()? containerPath})
    : _containerPath = containerPath ?? _iosAppGroupPath;

  final LibraryStore store;
  final Future<String?> Function() _containerPath;

  Directory? _folder;
  String? _lastSnapshot;
  AppLifecycleListener? _lifecycle;
  bool _importing = false;

  static const _channel = MethodChannel('plink/app_group');

  static Future<String?> _iosAppGroupPath() async {
    if (kIsWeb || !Platform.isIOS) return null;
    try {
      return await _channel.invokeMethod<String>('containerPath');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Finds the shared folder, then keeps it in step. Does nothing where
  /// there is no share extension.
  Future<void> start({bool listen = true}) async {
    final path = await _containerPath();
    if (path == null) return;
    _folder = Directory(p.join(path, 'share'));
    await writeBoards();
    await importPending();
    if (!listen) return;
    store.addListener(_onLibraryChanged);
    _lifecycle = AppLifecycleListener(onResume: importPending);
  }

  void _onLibraryChanged() => unawaited(writeBoards());

  /// SF Symbols for icons drawn only in Plink (and a few where Plink's
  /// glyph says something more specific than the stored key).
  static const _symbolFor = {
    'custom.baselit': 'circle.hexagongrid.fill',
    'custom.3dprinter': 'printer.fill',
    'custom.tinyhouse': 'house.lodge',
    'figure.2.and.child.holdinghands': 'figure.run',
    'dumbbell.fill': 'figure.strengthtraining.functional',
  };

  static String symbolFor(Board board) {
    final key = board.boardIcon.key;
    return _symbolFor[key] ?? key;
  }

  /// Writes the board list the extension shows, when it has changed.
  Future<void> writeBoards() async {
    final folder = _folder;
    if (folder == null) return;
    final json = jsonEncode({
      'boards': [
        for (final b in store.boards)
          {'id': b.id, 'name': b.name, 'symbol': symbolFor(b)},
      ],
    });
    if (json == _lastSnapshot) return;
    _lastSnapshot = json;
    await folder.create(recursive: true);
    final tmp = File(p.join(folder.path, 'boards.json.tmp'));
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(p.join(folder.path, 'boards.json'));
  }

  /// Turns every saved share into a pin, oldest first. Returns how many.
  Future<int> importPending() async {
    final folder = _folder;
    if (folder == null || _importing) return 0;
    _importing = true;
    try {
      final inbox = Directory(p.join(folder.path, 'inbox'));
      if (!await inbox.exists()) return 0;
      final files = await inbox
          .list()
          .where((e) => e is File && e.path.endsWith('.json'))
          .cast<File>()
          .toList();
      final items = <({File file, Map<String, dynamic> data})>[];
      for (final file in files) {
        try {
          final data = jsonDecode(await file.readAsString());
          if (data is Map<String, dynamic>) items.add((file: file, data: data));
        } catch (e) {
          debugPrint('Skipping unreadable share ${file.path}: $e');
        }
      }
      items.sort(
        (a, b) => (a.data['sharedAt'] as num? ?? 0).compareTo(
          b.data['sharedAt'] as num? ?? 0,
        ),
      );
      var added = 0;
      for (final item in items) {
        final pin = pinFromShare(item.data, store);
        if (pin != null) {
          store.addPin(pin);
          added++;
        }
        await item.file.delete();
      }
      return added;
    } finally {
      _importing = false;
    }
  }

  /// A new pin for one shared item, or null if it has no usable link.
  @visibleForTesting
  static Pin? pinFromShare(Map<String, dynamic> data, LibraryStore store) {
    final url = (data['url'] as String? ?? '').trim();
    if (!url.isValidUrl) return null;
    final at = (data['sharedAt'] as num?)?.toInt();
    final when = at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
    final boardIds = [
      for (final id in (data['boardIds'] as List? ?? []).cast<String>())
        if (store.boardById(id) != null) id,
    ];
    return Pin(
      urlString: url,
      title: data['title'] as String? ?? '',
      domain: Uri.parse(url).displayDomain,
      boardIds: boardIds,
      dateAdded: when,
      dateModified: when,
      sortOrder: boardIds.isEmpty
          ? 0
          : store.pinsIn(store.boardById(boardIds.first)!).length,
    );
  }

  void dispose() {
    store.removeListener(_onLibraryChanged);
    _lifecycle?.dispose();
  }
}

/// Android's "Share to Plink": the share arrives in the app itself
/// (MainActivity.kt), and is saved straight away as a pin.
class AndroidShares {
  AndroidShares(this.store, {required this.onSaved});

  final LibraryStore store;

  /// Called with each pin saved from a share, e.g. to offer "Add to Board".
  final void Function(Pin pin) onSaved;

  static const _channel = MethodChannel('plink/share');

  Future<void> start() async {
    if (kIsWeb || !Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') _save(call.arguments as String?);
    });
    try {
      _save(await _channel.invokeMethod<String>('takeShared'));
    } on MissingPluginException {
      // Not running in the Android app (e.g. tests).
    }
  }

  void _save(String? text) {
    final url = firstLink(text);
    if (url == null) return;
    final pin = ShareInbox.pinFromShare({
      'url': url,
      'sharedAt': DateTime.now().millisecondsSinceEpoch,
    }, store);
    if (pin == null) return;
    store.addPin(pin);
    onSaved(pin);
  }

  /// The first web link in shared text ("Look at this https://…").
  static String? firstLink(String? text) {
    if (text == null) return null;
    final match = RegExp(r'https?://[^\s<>"]+').firstMatch(text);
    return match?.group(0)?.replaceFirst(RegExp(r'[).,!?;:]+$'), '');
  }
}
