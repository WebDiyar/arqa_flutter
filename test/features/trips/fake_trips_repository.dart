import 'dart:async';

import 'package:driver_diary/core/error/app_exception.dart';
import 'package:driver_diary/core/time/zoned_date_time.dart';
import 'package:driver_diary/features/trips/domain/entities/day_report.dart';
import 'package:driver_diary/features/trips/domain/entities/day_summary.dart';
import 'package:driver_diary/features/trips/domain/entities/pending_trip.dart';
import 'package:driver_diary/features/trips/domain/entities/trip.dart';
import 'package:driver_diary/features/trips/domain/repositories/trips_repository.dart';

Trip sampleTrip(
  String id,
  String start,
  String end,
  int amount,
  PaymentMethod payment,
  int commission,
) => Trip(
  id: id,
  start: ZonedDateTime.parse('2026-10-01T$start:00+05:00'),
  end: ZonedDateTime.parse('2026-10-01T$end:00+05:00'),
  amount: amount,
  payment: payment,
  commission: commission,
);

/// Отчёт из примера задания.
final sampleReport = DayReport(
  syncedAt: DateTime(2026, 10, 1, 19, 5),
  trips: [
    sampleTrip('t1', '08:10', '08:32', 2400, PaymentMethod.card, 360),
    sampleTrip('t2', '09:05', '09:20', 1500, PaymentMethod.cash, 225),
  ],
  summary: const DaySummary(
    tripsCount: 2,
    revenue: 3900,
    commission: 585,
    net: 3315,
    cash: PaymentTotals(count: 1, amount: 1500),
    card: PaymentTotals(count: 1, amount: 2400),
  ),
);

const offline = AppException('Нет связи с сервером', retryable: true);

/// Настраиваемый фейк: что в кэше, что ответит «сервер», что в очереди.
class FakeTripsRepository implements TripsRepository {
  DayReport? cached;

  /// null → отвечает [sampleReport]; AppException → бросает.
  Object? server;

  /// Если задан — fetchDay ждёт его (для тестов загрузки).
  Completer<void>? gate;

  final requestedDays = <DateTime>[];
  final added = <Trip>[];
  var pending = <PendingTrip>[];
  var syncCalls = 0;

  @override
  Future<DayReport?> cachedDay(DateTime day) async => cached;

  @override
  Future<DayReport> fetchDay(DateTime day) async {
    requestedDays.add(day);
    await gate?.future;
    if (server case final AppException e) throw e;
    return sampleReport;
  }

  @override
  Future<List<PendingTrip>> pendingFor(DateTime day) async => pending;

  @override
  Future<AddOutcome> addTrip(Trip trip) async {
    if (server case final AppException e) {
      if (!e.retryable) throw e;
      pending = [...pending, PendingTrip(trip)];
      return AddOutcome.queued;
    }
    added.add(trip);
    return AddOutcome.sent;
  }

  @override
  Future<void> syncPending() async => syncCalls++;

  @override
  Future<void> discardPending(String id) async =>
      pending = [...pending.where((p) => p.trip.id != id)];
}
