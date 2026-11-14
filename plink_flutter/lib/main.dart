import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'constants.dart';
import 'data/library_store.dart';
import 'sync/plink_sync.dart';
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
  // In the background: the app works from its local copy while offline.
  unawaited(sync.init());
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
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: const AppShell(),
      ),
    );
  }

  static ThemeData _theme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppConstants.accentColor,
      brightness: brightness,
    ),
    useMaterial3: true,
  );
}
