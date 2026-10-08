import 'package:dio/dio.dart';

/// Единственный тип ошибки, который видят domain и presentation.
/// data-слой переводит в него всё «чужое» (DioException и т.п.).
class AppException implements Exception {
  const AppException(
    this.message, {
    this.fields = const {},
    this.retryable = false,
  });

  factory AppException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    // Нет связи, таймаут, 5xx (в т.ч. 502 от хостинга, пока сервер
    // просыпается) — временно: можно повторить с тем же id.
    final retryable =
        e.type != DioExceptionType.badResponse || (status ?? 0) >= 500;

    // Сервер отвечает `{error, message, fields?}` — показываем его текст,
    // а ошибки по полям отдаём форме.
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      final fields = data['fields'];
      return AppException(
        data['message'] as String,
        fields: fields is Map
            ? fields.map((k, v) => MapEntry('$k', '$v'))
            : const {},
        retryable: retryable,
      );
    }
    return AppException(switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'Сервер не отвечает',
      DioExceptionType.connectionError => 'Нет связи с сервером',
      DioExceptionType.badResponse => 'Ошибка сервера: $status',
      _ => 'Ошибка сети',
    }, retryable: retryable);
  }

  final String message;

  /// Ошибки по полям формы: `{'amount': 'Сумма должна быть больше 0'}`.
  final Map<String, String> fields;

  /// Временная проблема (сеть, таймаут, 5xx): повтор может пройти.
  /// `false` — сервер осознанно отказал (400, 409), повтор не поможет.
  final bool retryable;

  @override
  String toString() => message;
}
