import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/app_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = AppRepository();
  await repository.load();
  runApp(
    ChangeNotifierProvider<AppRepository>.value(
      value: repository,
      child: const XiaoyierApp(),
    ),
  );
}
