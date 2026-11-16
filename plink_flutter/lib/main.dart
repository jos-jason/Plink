import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'data/library_store.dart';
import 'data/share_inbox.dart';
import 'models/pin.dart';
import 'sync/plink_sync.dart';
import 'theme.dart';
import 'ui/boards/board_picker_dialog.dart';
import 'ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supportDir = await getApplicationSupportDirectory();
  final store = await LibraryStore.open(supportDir.path);
  final sync = PlinkSync(
    library: store,
    settings: DeviceSyncSettingsStore(supportDir.path),
  );
  runApp(PlinkApp(store: store, sync: sync));
  // Pins saved from other apps' share sheets: the iOS share extension's
  // inbox, and Android share intents.
  unawaited(ShareInbox(store).start());
  unawaited(AndroidShares(store, onSaved: _offerBoard).start());
  // In the background: the app works from its local copy while offline.
  unawaited(sync.init());
}

final _navigatorKey = GlobalKey<NavigatorState>();
final _messengerKey = GlobalKey<ScaffoldMessengerState>();

/// After a share is saved: confirm it, with a shortcut to file it.
void _offerBoard(Pin pin) {
  _messengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: const Text('Saved to Plink'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Add to Board',
          onPressed: () {
            final context = _navigatorKey.currentContext;
            if (context != null) showBoardPicker(context, pin);
          },
        ),
      ),
    );
}

class PlinkApp extends StatelessWidget {
  const PlinkApp({super.key, required this.store, required this.sync});

  final LibraryStore store;
  final PlinkSync sync;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: sync),
      ],
      child: MaterialApp(
        title: 'Plink',
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _messengerKey,
        debugShowCheckedModeBanner: false,
        theme: plinkTheme(Brightness.light),
        darkTheme: plinkTheme(Brightness.dark),
        home: const AppShell(),
      ),
    );
  }
}
