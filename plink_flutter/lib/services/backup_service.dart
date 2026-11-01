import 'dart:convert';

import '../models/board.dart';
import '../models/pin.dart';

/// Reads and writes the Swift app's v1 backup format (`PlinkExport`), so a
/// backup from either app imports into the other.
///
/// Swift's `.iso8601` date strategy rejects fractional seconds, so dates are
/// written as whole-second UTC timestamps.
abstract final class BackupService {
  static const formatVersion = 1;

  static String exportJson({
    required List<Pin> pins,
    required List<Board> boards,
    DateTime? now,
  }) {
    final export = {
      'version': formatVersion,
      'exportDate': _isoDate(now ?? DateTime.now()),
      'boards': [
        for (final b in boards)
          {
            'id': b.id,
            'name': b.name,
            'dateCreated': _isoDate(b.dateCreated),
            'sortOrder': b.sortOrder,
          },
      ],
      'pins': [
        for (final p in pins)
          {
            'id': p.id,
            'urlString': p.urlString,
            'title': p.title,
            'pageDescription': p.pageDescription,
            'domain': p.domain,
            'dateAdded': _isoDate(p.dateAdded),
            'dateModified': _isoDate(p.dateModified),
            'isCustomImage': p.isCustomImage,
            'notes': p.notes,
            'boardIDs': p.boardIds,
          },
      ],
    };
    return _sortedEncoder.convert(_sortKeys(export));
  }

  /// Parses a backup. Pins come back with `metadataFetched == false`, since
  /// the format carries no images; the grid refetches them.
  static ({List<Pin> pins, List<Board> boards}) importJson(String source) {
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic> || json['pins'] is! List) {
      throw const FormatException('Not a Plink backup');
    }
    final boards = [
      for (final b
          in (json['boards'] as List? ?? []).cast<Map<String, dynamic>>())
        Board(
          id: b['id'] as String,
          name: b['name'] as String,
          dateCreated: DateTime.parse(b['dateCreated'] as String).toLocal(),
          sortOrder: b['sortOrder'] as int? ?? 0,
        ),
    ];
    final pins = [
      for (final p in (json['pins'] as List).cast<Map<String, dynamic>>())
        Pin(
          id: p['id'] as String,
          urlString: p['urlString'] as String,
          title: p['title'] as String? ?? '',
          pageDescription: p['pageDescription'] as String? ?? '',
          domain: p['domain'] as String? ?? '',
          dateAdded: DateTime.parse(p['dateAdded'] as String).toLocal(),
          dateModified: DateTime.parse(p['dateModified'] as String).toLocal(),
          isCustomImage: p['isCustomImage'] as bool? ?? false,
          notes: p['notes'] as String? ?? '',
          boardIds: (p['boardIDs'] as List? ?? []).cast<String>().toList(),
        ),
    ];
    return (pins: pins, boards: boards);
  }

  static String _isoDate(DateTime d) {
    final s = d.toUtc().toIso8601String();
    return '${s.substring(0, 19)}Z';
  }

  static const _sortedEncoder = JsonEncoder.withIndent('  ');

  /// Matches Swift's `.sortedKeys` output so diffs between backups stay small.
  static Object? _sortKeys(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final k in keys) k: _sortKeys(value[k])};
    }
    if (value is List) return value.map(_sortKeys).toList();
    return value;
  }
}
