import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tgfm_music_library/core/providers.dart';
import 'package:tgfm_music_library/my_app.dart';

import 'core/local_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final localDb = createLocalDb();
  await localDb.init();

  runApp(
    ProviderScope(
      overrides: [localDbProvider.overrideWithValue(localDb)],
      child: const MyApp(),
    ),
  );
}
