import 'package:dio/dio.dart';

/// Единственный тип ошибки, который видят domain и presentation.
/// data-слой переводит в него всё «чужое» (DioException и т.п.).
class AppException implements Exception {
  const AppException(this.message);

  factory AppException.fromDio(DioException e) => AppException(switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => 'Сервер не отвечает',
    DioExceptionType.connectionError => 'Нет соединения с интернетом',
    DioExceptionType.badResponse => 'Ошибка сервера: ${e.response?.statusCode}',
    _ => 'Ошибка сети',
  });

  final String message;

  @override
  String toString() => message;
}
