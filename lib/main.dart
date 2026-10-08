import 'package:driver_diary/app/app.dart';
import 'package:driver_diary/core/storage/prefs_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      // Riverpod 3 по умолчанию сам перезапрашивает упавший провайдер.
      // Здесь у ошибки есть кнопка «Повторить» — авторетраи только мешают.
      retry: (_, _) => null,
      child: const App(),
    ),
  );
}
