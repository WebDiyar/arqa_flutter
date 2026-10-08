import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Переопределяется при запуске: --dart-define=API_URL=https://…onrender.com
const _apiUrlOverride = String.fromEnvironment('API_URL');

String get apiUrl {
  if (_apiUrlOverride.isNotEmpty) return _apiUrlOverride;
  // Релизный веб раздаёт тот же сервер, что отдаёт API (Docker / Render).
  if (kIsWeb && kReleaseMode) return Uri.base.origin;
  // Эмулятор Android видит компьютер как 10.0.2.2, а не localhost.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080';
  }
  return 'http://localhost:8080';
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiUrl,
      connectTimeout: const Duration(seconds: 10),
      // Бесплатный хостинг усыпляет сервер: первый ответ после сна идёт
      // до минуты. Короткий таймаут превратил бы это в ошибку.
      receiveTimeout: const Duration(seconds: 70),
    ),
  );
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        request: false,
        requestHeader: false,
        responseHeader: false,
        logPrint: (o) => debugPrint('$o'),
      ),
    );
  }
  ref.onDispose(dio.close);
  return dio;
});
