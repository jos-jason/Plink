# Plink (Flutter)

Cross-platform port of the SwiftUI Plink app (`../Plink`). Targets iOS, Android, macOS and Linux.

## Run

```bash
flutter run -d macos     # or: ios, android, linux
```

Linux needs `zenity` or `kdialog` installed for the import/export file dialogs.

## Layout

| Path | Swift counterpart |
| --- | --- |
| `lib/models/` | `Plink/Models/` (board icons keep their SF Symbol names, mapped to Material icons) |
| `lib/data/library_store.dart` | SwiftData container + `@Query` (one JSON file in app support) |
| `lib/services/metadata_service.dart` | `MetadataService` (HTML parsing instead of LinkPresentation) |
| `lib/services/image_storage.dart` | `ImageStorageService` |
| `lib/services/backup_service.dart` | `ExportService` (same v1 JSON format) |
| `lib/ui/` | `Plink/Views/` (bottom tabs under 600px wide, sidebar above) |

## Moving data from the Swift app

Export from Settings in the Swift app, then import in Settings here. Backups work both ways.
The format doesn't carry images, so each pin fetches its image again after import.

## Not ported yet

- Share extension (saving from other apps' share sheets)
- Drag-to-reorder inside the masonry grid. Board views have a Reorder button that switches to a list instead.
- Searching the full SF Symbols catalog in the board icon picker

## Tests

```bash
flutter test
```

`flutter test` currently fails to load when the project path contains an apostrophe
(e.g. `jj's files`). That's a Flutter tooling bug. Run it from a copy at a path without one.
