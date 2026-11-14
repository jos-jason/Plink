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

## Sync

Pins and boards sync between devices through the PocketBase server on the NAS, using
[nas_sync](https://github.com/jos-jason/nas-sync) (`lib/sync/plink_sync.dart`).
Sign in under Settings → Sync, or with the cloud button on All Pins. The server only
answers on the tailnet, so Tailscale has to be on. Enter the server as
`https://<nas-name>.<tailnet>.ts.net:8443`.

- App name `plink`. Kinds: `pin` (fields as data, image as the blob, favicon inline) and
  `board`. Keys are the pin and board UUIDs.
- The app works from its local copy and syncs on start, 5 seconds after an edit, every
  5 minutes, and when it comes back to the foreground.
- If a pin is edited on two devices, the newer edit wins but notes from both are kept.
  For boards, the newer edit wins.
- The login is stored in the system keychain or keyring, never the password.
  Linux builds need `libsecret-1-dev` and `libjsoncpp-dev`.

## Not ported yet

- Share extension (saving from other apps' share sheets)
- Drag-to-reorder inside the masonry grid. Board views have a Reorder button that switches to a list instead.
- Searching the full SF Symbols catalog in the board icon picker

## Tests

```bash
flutter test
```

The sync tests use an in-memory fake of the server by default. To run them against a local
PocketBase built from the nas-sync repo's `server/` (users `alice` and `bob`), run
`NAS_SYNC_TEST_URL=http://127.0.0.1:18090 flutter test test/sync_test.dart`.

`flutter test` currently fails to load when the project path contains an apostrophe
(e.g. `jj's files`). That's a Flutter tooling bug. Run it from a copy at a path without one.
