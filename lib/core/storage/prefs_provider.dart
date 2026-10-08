import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Инициализируется в main() (getInstance асинхронный) и подставляется
/// через override, чтобы остальной код получал его синхронно.
final prefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('prefsProvider переопределяется в main()'),
);
