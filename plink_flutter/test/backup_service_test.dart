import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plink/models/board.dart';
import 'package:plink/models/pin.dart';
import 'package:plink/services/backup_service.dart';

void main() {
  // Shape produced by the Swift app's ExportService (JSONEncoder, .iso8601, .sortedKeys).
  const swiftBackup = '''
{
  "boards" : [
    { "dateCreated" : "2026-07-22T10:00:00Z", "id" : "B1B1B1B1-0000-0000-0000-000000000001", "name" : "Recipes", "sortOrder" : 0 }
  ],
  "exportDate" : "2026-07-30T12:00:00Z",
  "pins" : [
    {
      "boardIDs" : [ "B1B1B1B1-0000-0000-0000-000000000001" ],
      "dateAdded" : "2026-07-23T09:30:00Z",
      "dateModified" : "2026-07-23T09:31:00Z",
      "domain" : "example.com",
      "id" : "A1A1A1A1-0000-0000-0000-000000000001",
      "isCustomImage" : false,
      "notes" : "try this",
      "pageDescription" : "",
      "title" : "Soup",
      "urlString" : "https://example.com/soup"
    }
  ],
  "version" : 1
}''';

  test('imports a Swift app backup', () {
    final result = BackupService.importJson(swiftBackup);
    expect(result.boards.single.name, 'Recipes');
    final pin = result.pins.single;
    expect(pin.title, 'Soup');
    expect(pin.notes, 'try this');
    expect(pin.boardIds, ['B1B1B1B1-0000-0000-0000-000000000001']);
    expect(pin.dateAdded.toUtc(), DateTime.utc(2026, 7, 23, 9, 30));
    expect(pin.metadataFetched, isFalse);
  });

  test('exports dates without fractional seconds, which Swift requires', () {
    final board = Board(
      name: 'B',
      dateCreated: DateTime.utc(2026, 1, 2, 3, 4, 5, 678),
    );
    final pin = Pin(
      urlString: 'https://a.com',
      boardIds: [board.id],
      dateAdded: DateTime.utc(2026, 1, 2, 3, 4, 5, 678),
    );
    final json = jsonDecode(
      BackupService.exportJson(pins: [pin], boards: [board]),
    );
    expect(json['version'], 1);
    expect(json['pins'][0]['dateAdded'], '2026-01-02T03:04:05Z');
    expect(json['pins'][0]['boardIDs'], [board.id]);
    expect(json['boards'][0]['dateCreated'], '2026-01-02T03:04:05Z');
  });

  test('round-trips', () {
    final again = BackupService.importJson(
      BackupService.exportJson(
        pins: BackupService.importJson(swiftBackup).pins,
        boards: BackupService.importJson(swiftBackup).boards,
      ),
    );
    expect(again.pins.single.urlString, 'https://example.com/soup');
    expect(again.boards.single.id, 'B1B1B1B1-0000-0000-0000-000000000001');
  });

  test('rejects non-backup JSON', () {
    expect(() => BackupService.importJson('{"foo": 1}'), throwsFormatException);
  });
}
