import 'package:dio/dio.dart';
import 'package:driver_diary/core/error/app_exception.dart';
import 'package:driver_diary/core/time/zoned_date_time.dart';
import 'package:driver_diary/features/trips/data/datasources/trips_local_data_source.dart';
import 'package:driver_diary/features/trips/data/datasources/trips_remote_data_source.dart';
import 'package:driver_diary/features/trips/data/models/day_summary_model.dart';
import 'package:driver_diary/features/trips/data/models/trip_model.dart';
import 'package:driver_diary/features/trips/domain/entities/day_report.dart';
import 'package:driver_diary/features/trips/domain/entities/pending_trip.dart';
import 'package:driver_diary/features/trips/domain/entities/trip.dart';
import 'package:driver_diary/features/trips/domain/repositories/trips_repository.dart';
import 'package:flutter/foundation.dart';

class TripsRepositoryImpl implements TripsRepository {
  TripsRepositoryImpl(this._remote, this._local);

  final TripsRemoteDataSource _remote;
  final TripsLocalDataSource _local;

  /// Одна синхронизация за раз в пределах приложения: второй вызов ждёт
  /// первый. Даже без этого дублей не было бы (id идемпотентен), но лишние
  /// запросы ни к чему.
  Future<void>? _syncing;

  @override
  Future<DayReport?> cachedDay(DateTime day) async {
    final json = _local.readDay(dayKey(day));
    if (json == null) return null;
    try {
      return _reportFromJson(json);
    } catch (e) {
      debugPrint('Битый кэш за ${dayKey(day)}, игнорируем: $e');
      return null;
    }
  }

  @override
  Future<DayReport> fetchDay(DateTime day) => _guard(() async {
    final date = dayKey(day);
    // Именно Future.wait, а не `(a, b).wait`: рекорд-версия бросает
    // ParallelWaitError вместо исходной DioException.
    final [trips, summary] = await Future.wait([
      _remote.getTrips(date),
      _remote.getSummary(date),
    ]);
    final json = <String, Object>{
      'syncedAt': DateTime.now().toUtc().toIso8601String(),
      'trips': [for (final t in trips as List<TripModel>) t.toJson()],
      'summary': summary,
    };
    final report = _reportFromJson(json); // сначала разбор: битое не кэшируем
    await _local.writeDay(date, json);
    return report;
  });

  @override
  Future<List<PendingTrip>> pendingFor(DateTime day) async {
    final key = dayKey(day);
    return _outbox().where((p) => dayKey(p.trip.start.day) == key).toList()
      ..sort((a, b) => a.trip.start.instant.compareTo(b.trip.start.instant));
  }

  @override
  Future<AddOutcome> addTrip(Trip trip) async {
    try {
      await _guard(() => _remote.addTrip(TripModel.fromEntity(trip)));
      return AddOutcome.sent;
    } on AppException catch (e) {
      if (!e.retryable) rethrow;
      await _saveOutbox([
        ..._outbox().where((p) => p.trip.id != trip.id),
        PendingTrip(trip),
      ]);
      return AddOutcome.queued;
    }
  }

  @override
  Future<void> syncPending() =>
      _syncing ??= _sync().whenComplete(() => _syncing = null);

  Future<void> _sync() async {
    for (final item in _outbox().where((p) => !p.rejected)) {
      try {
        await _guard(() => _remote.addTrip(TripModel.fromEntity(item.trip)));
        await _replace(item.trip.id, null);
      } on AppException catch (e) {
        if (e.retryable) return; // связи нет — остальные тоже не уйдут
        await _replace(item.trip.id, PendingTrip(item.trip, error: e.message));
      }
    }
  }

  @override
  Future<void> discardPending(String id) => _replace(id, null);

  // ── очередь ──

  List<PendingTrip> _outbox() => [
    for (final j in _local.readOutbox())
      PendingTrip(
        TripModel.fromJson(j['trip'] as Map<String, dynamic>).toEntity(),
        error: j['error'] as String?,
      ),
  ];

  Future<void> _saveOutbox(List<PendingTrip> items) => _local.writeOutbox([
    for (final p in items)
      {'trip': TripModel.fromEntity(p.trip).toJson(), 'error': p.error},
  ]);

  /// Заменить элемент очереди с [id] на [item]; null — удалить.
  Future<void> _replace(String id, PendingTrip? item) => _saveOutbox([
    for (final p in _outbox())
      if (p.trip.id != id) p else ?item,
  ]);

  // ── маппинг и ошибки ──

  DayReport _reportFromJson(Map<String, dynamic> json) => DayReport(
    syncedAt: DateTime.parse(json['syncedAt'] as String).toLocal(),
    trips: [
      for (final t in json['trips'] as List<dynamic>)
        TripModel.fromJson(t as Map<String, dynamic>).toEntity(),
    ],
    summary: daySummaryFromJson(json['summary'] as Map<String, dynamic>),
  );

  /// Наружу — только AppException. Остальное здесь — ошибки разбора ответа
  /// (TypeError, FormatException, ArgumentError из byName): сервер прислал
  /// не то, и понятное сообщение лучше красного экрана.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    } catch (e) {
      debugPrint('Неожиданный ответ сервера: $e');
      throw const AppException('Неожиданный ответ сервера');
    }
  }
}
