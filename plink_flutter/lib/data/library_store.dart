import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../constants.dart';
import '../models/board.dart';
import '../models/pin.dart';
import '../services/backup_service.dart';
import '../services/image_storage.dart';
import '../services/metadata_service.dart';

/// The whole library, held in memory and persisted as one JSON file.
///
/// A single file keeps the port dependency-free on every platform; it's fine
/// for thousands of pins. Swap this for SQLite (drift) if libraries get huge.
class LibraryStore extends ChangeNotifier {
  LibraryStore._(this._file, this.images, this._metadata);

  final File _file;
  final ImageStorage images;
  final MetadataService _metadata;

  final List<Pin> _pins = [];
  final List<Board> _boards = [];
  final Set<String> _fetching = {};
  Timer? _saveTimer;

  static Future<LibraryStore> open(
    String supportDirectory, {
    MetadataService? metadata,
  }) async {
    final store = LibraryStore._(
      File(p.join(supportDirectory, AppConstants.libraryFileName)),
      ImageStorage(supportDirectory),
      metadata ?? MetadataService(),
    );
    await store._load();
    return store;
  }

  MetadataService get metadata => _metadata;

  /// All pins, newest first.
  List<Pin> get pins => List.unmodifiable(
    _pins.toList()..sort((a, b) => b.dateAdded.compareTo(a.dateAdded)),
  );

  List<Board> get boards => List.unmodifiable(
    _boards.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
  );

  Board? boardById(String id) => _boards.where((b) => b.id == id).firstOrNull;

  Pin? pinById(String id) => _pins.where((p) => p.id == id).firstOrNull;

  /// Pins in a board, in the user's order.
  List<Pin> pinsIn(Board board) =>
      _pins.where((p) => p.boardIds.contains(board.id)).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// Cover image: the image from the most recently added pin that has one.
  String? coverImageFor(Board board) {
    final withImages =
        _pins
            .where((p) => p.boardIds.contains(board.id) && p.imagePath != null)
            .toList()
          ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return withImages.firstOrNull?.imagePath;
  }

  bool isFetching(Pin pin) => _fetching.contains(pin.id);

  // MARK: Pins

  void addPin(Pin pin) {
    _pins.add(pin);
    _changed();
  }

  void updatePin(Pin pin) {
    pin.dateModified = DateTime.now();
    _changed();
  }

  Future<void> deletePin(Pin pin) async {
    _pins.removeWhere((p) => p.id == pin.id);
    _changed();
    await images.delete(pin.imagePath);
    await images.delete(pin.faviconPath);
  }

  void setBoards(Pin pin, Set<String> boardIds) {
    pin.boardIds = boardIds.toList();
    updatePin(pin);
  }

  /// Moves [pin] to [newIndex] within [board]'s ordering.
  void reorderInBoard(Board board, int oldIndex, int newIndex) {
    final ordered = pinsIn(board);
    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);
    for (var i = 0; i < ordered.length; i++) {
      ordered[i].sortOrder = i;
    }
    _changed();
  }

  /// Saves a new main image for [pin] from raw bytes.
  Future<bool> setImage(Pin pin, Uint8List data, {required bool custom}) async {
    final saved = await images.saveImage(data, pin.id);
    if (saved == null) return false;
    final old = pin.imagePath;
    pin
      ..imagePath = saved.filename
      ..imageAspectRatio = saved.aspectRatio
      ..isCustomImage = custom
      ..metadataFetched = true;
    updatePin(pin);
    if (old != saved.filename) await images.delete(old);
    return true;
  }

  /// Fetches title, image and favicon for a pin that hasn't been fetched yet.
  /// Safe to call repeatedly; concurrent calls for one pin are coalesced.
  Future<void> ensureMetadata(Pin pin) async {
    if (pin.metadataFetched || !_fetching.add(pin.id)) return;
    try {
      final url = pin.url;
      if (url == null) return;
      final meta = await _metadata.fetchMetadata(url);
      if (pin.title.isEmpty) pin.title = meta.title;
      if (pin.pageDescription.isEmpty) pin.pageDescription = meta.description;
      if (pin.domain.isEmpty) pin.domain = meta.domain;
      if (meta.imageData != null && !pin.isCustomImage) {
        final saved = await images.saveImage(meta.imageData!, pin.id);
        if (saved != null) {
          pin
            ..imagePath = saved.filename
            ..imageAspectRatio = saved.aspectRatio;
        }
      }
      if (meta.faviconData != null && pin.faviconPath == null) {
        pin.faviconPath = await images.saveFavicon(meta.faviconData!, pin.id);
      }
    } catch (e) {
      debugPrint('Metadata fetch failed for ${pin.urlString}: $e');
    } finally {
      // Mark as fetched even on failure to avoid retry loops.
      pin.metadataFetched = true;
      _fetching.remove(pin.id);
      if (_pins.contains(pin)) updatePin(pin);
    }
  }

  /// Clears fetched (non-custom) images and refetches.
  Future<void> refreshMetadata(Pin pin) async {
    if (!pin.isCustomImage) {
      await images.delete(pin.imagePath);
      pin
        ..imagePath = null
        ..imageAspectRatio = 1.5;
    }
    await images.delete(pin.faviconPath);
    pin
      ..faviconPath = null
      ..metadataFetched = false;
    _changed();
    await ensureMetadata(pin);
  }

  // MARK: Boards

  Board createBoard(String name, {String icon = 'folder'}) {
    final nextOrder = _boards.isEmpty
        ? 0
        : _boards.map((b) => b.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final board = Board(name: name, icon: icon, sortOrder: nextOrder);
    _boards.add(board);
    _changed();
    return board;
  }

  void updateBoard(Board board) {
    board.dateModified = DateTime.now();
    _changed();
  }

  /// Deletes the board; its pins stay in the library.
  void deleteBoard(Board board) {
    _boards.removeWhere((b) => b.id == board.id);
    for (final pin in _pins) {
      pin.boardIds.remove(board.id);
    }
    _changed();
  }

  void reorderBoards(int oldIndex, int newIndex) {
    final ordered = boards.toList();
    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);
    for (var i = 0; i < ordered.length; i++) {
      ordered[i].sortOrder = i;
    }
    _changed();
  }

  // MARK: Backup

  String exportBackup() => BackupService.exportJson(pins: pins, boards: boards);

  /// Adds a backup's pins and boards, skipping any IDs already present.
  /// Returns the number of pins added.
  int importBackup(String json) {
    final data = BackupService.importJson(json);
    final boardIds = _boards.map((b) => b.id).toSet();
    final pinIds = _pins.map((p) => p.id).toSet();
    _boards.addAll(data.boards.where((b) => boardIds.add(b.id)));
    final newPins = data.pins.where((p) => pinIds.add(p.id)).toList();
    for (final pin in newPins) {
      pin.boardIds.removeWhere((id) => !boardIds.contains(id));
    }
    _pins.addAll(newPins);
    _changed();
    return newPins.length;
  }

  // MARK: Persistence

  Future<void> _load() async {
    if (!await _file.exists()) return;
    try {
      final json =
          jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      _boards.addAll((json['boards'] as List).map((b) => Board.fromJson(b)));
      _pins.addAll((json['pins'] as List).map((p) => Pin.fromJson(p)));
    } catch (e) {
      // Keep the unreadable file rather than overwriting it on next save.
      final backup =
          '${_file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}';
      await _file.rename(backup);
      debugPrint('Library file unreadable, moved to $backup: $e');
    }
  }

  void _changed() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), save);
  }

  /// Writes the library atomically (temp file + rename).
  Future<void> save() async {
    _saveTimer?.cancel();
    final json = jsonEncode({
      'version': 1,
      'boards': _boards.map((b) => b.toJson()).toList(),
      'pins': _pins.map((p) => p.toJson()).toList(),
    });
    await _file.parent.create(recursive: true);
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(_file.path);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
