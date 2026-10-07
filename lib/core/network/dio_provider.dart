import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Переопределяется при запуске: --dart-define=API_URL=https://...
const _apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://jsonplaceholder.typicode.com',
);

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _apiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(logPrint: (o) => debugPrint('$o')));
  }
  ref.onDispose(dio.close);
  return dio;
});
