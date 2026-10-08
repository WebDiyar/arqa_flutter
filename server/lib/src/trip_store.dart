import 'dart:convert';
import 'dart:io';

import 'package:driver_diary_server/src/trip.dart';

/// HTTP 409: поездку нельзя принять, но это не ошибка формата.
class ConflictException implements Exception {
  ConflictException(this.message);

  final String message;

  @override
  String toString() => 'ConflictException($message)';
}

/// Хранилище поездок: всё в памяти, каждое добавление сразу пишется в JSON-файл.
// ponytail: один файл и один процесс; при нескольких инстансах сервера —
// БД с UNIQUE(id) и проверкой пересечений в транзакции.
class TripStore {
  TripStore.memory([List<Trip>? trips]) : _file = null, _trips = trips ?? [];

  TripStore._(this._file, this._trips);

  /// Открывает [file]; если его нет — копирует [seed] (если передан).
  static Future<TripStore> open(File file, {File? seed}) async {
    if (!file.existsSync() && seed != null && seed.existsSync()) {
      await seed.copy(file.path);
    }
    if (!file.existsSync()) return TripStore._(file, []);
    final json = jsonDecode(await file.readAsString()) as List<dynamic>;
    return TripStore._(file, json.map(Trip.fromJson).toList());
  }

  final File? _file;
  final List<Trip> _trips;
  Future<void> _queue = Future.value();

  List<Trip> byDay(String day) =>
      _trips.where((t) => t.day == day).toList()
        ..sort((a, b) => a.startAt.compareTo(b.startAt));

  /// Добавляет поездку. Возвращает сохранённую поездку и `created`:
  /// `false` — это повтор уже принятой поездки, дубль не создан.
  ///
  /// Добавления выполняются строго по очереди (проверка → вставка → запись
  /// на диск), иначе при сбое записи откат мог бы задеть чужой запрос.
  Future<(Trip, bool created)> add(Trip trip) {
    final result = _queue.then((_) => _add(trip));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<(Trip, bool)> _add(Trip trip) async {
    // 1. Тот же id — повторная отправка (ретрай клиента, двойной тап).
    final sameId = _trips.where((t) => t.id == trip.id).firstOrNull;
    if (sameId != null) {
      if (sameId.sameAs(trip)) return (sameId, false);
      throw ConflictException(
        'Поездка ${trip.id} уже есть, но с другими данными',
      );
    }

    // 2. Те же данные под другим id — клиент без идемпотентного id.
    final same = _trips.where((t) => t.sameAs(trip)).firstOrNull;
    if (same != null) return (same, false);

    // 3. Пересечение по времени — две поездки одновременно невозможны.
    final overlap = _trips.where((t) => t.overlaps(trip)).firstOrNull;
    if (overlap != null) {
      throw ConflictException(
        'Пересекается с поездкой ${overlap.id} '
        '(${overlap.start} – ${overlap.end})',
      );
    }

    _trips.add(trip);
    try {
      await _save();
    } catch (_) {
      _trips.remove(trip);
      rethrow;
    }
    return (trip, true);
  }

  /// Атомарная запись: пишем во временный файл и переименовываем,
  /// чтобы падение посреди записи не оставило битый JSON.
  Future<void> _save() async {
    final file = _file;
    if (file == null) return;
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(_trips),
      flush: true,
    );
    await tmp.rename(file.path);
  }
}
