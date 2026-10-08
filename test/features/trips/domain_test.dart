import 'package:driver_diary/core/error/app_exception.dart';
import 'package:driver_diary/core/time/zoned_date_time.dart';
import 'package:driver_diary/features/trips/data/models/trip_model.dart';
import 'package:driver_diary/features/trips/domain/entities/day_report.dart';
import 'package:driver_diary/features/trips/domain/entities/pending_trip.dart';
import 'package:driver_diary/features/trips/domain/entities/trip.dart';
import 'package:driver_diary/features/trips/domain/usecases/add_trip.dart';
import 'package:driver_diary/features/trips/domain/usecases/watch_day_report.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_trips_repository.dart';

Trip trip({int amount = 2400, int commission = 360, String end = '08:32'}) =>
    Trip(
      id: 't1',
      start: ZonedDateTime.parse('2026-10-01T08:10:00+05:00'),
      end: ZonedDateTime.parse('2026-10-01T$end:00+05:00'),
      amount: amount,
      payment: PaymentMethod.card,
      commission: commission,
    );

final day = DateTime(2026, 10, 1);

void main() {
  group('Trip.validate — те же правила, что на сервере', () {
    test('валидная поездка', () => expect(trip().validate(), isEmpty));

    test('сумма должна быть > 0', () {
      expect(trip(amount: 0, commission: 0).validate(), contains('amount'));
    });

    test('окончание позже начала', () {
      expect(trip(end: '08:10').validate(), contains('end'));
      expect(trip(end: '08:00').validate(), contains('end'));
    });

    test('комиссия не больше суммы', () {
      expect(trip(commission: 2401).validate(), contains('commission'));
    });
  });

  test('AddTrip не ходит в сеть с невалидной поездкой', () async {
    final repo = FakeTripsRepository();

    await expectLater(
      AddTrip(repo)(trip(amount: 0, commission: 0)),
      throwsA(isA<AppException>()),
    );
    expect(repo.added, isEmpty);
  });

  group('WatchDayReport — stale-while-revalidate', () {
    test('без кэша: только свежие данные', () async {
      final repo = FakeTripsRepository();

      final states = await WatchDayReport(repo)(day).toList();

      expect(states.map((r) => r.freshness), [Freshness.fresh]);
      expect(states.single.summary.net, 3315);
    });

    test('с кэшем: сначала кэш, потом свежие; очередь до запроса', () async {
      final repo = FakeTripsRepository()..cached = sampleReport;

      final states = await WatchDayReport(repo)(day).toList();

      expect(states.map((r) => r.freshness), [
        Freshness.cached,
        Freshness.fresh,
      ]);
      expect(repo.syncCalls, 1);
    });

    test('нет связи, есть кэш → кэш с пометкой offline, не ошибка', () async {
      final repo = FakeTripsRepository()
        ..cached = sampleReport
        ..server = offline;

      final states = await WatchDayReport(repo)(day).toList();

      expect(states.last.freshness, Freshness.offline);
      expect(states.last.trips, hasLength(2));
    });

    test('нет связи и кэша → ошибка', () {
      final repo = FakeTripsRepository()..server = offline;

      expect(WatchDayReport(repo)(day).toList(), throwsA(isA<AppException>()));
    });

    test('неотправленные поездки прикладываются к отчёту', () async {
      final repo = FakeTripsRepository()..pending = [PendingTrip(trip())];

      final report = await WatchDayReport(repo)(day).last;

      expect(report.pending.single.trip.id, 't1');
      expect(report.summary.tripsCount, 2, reason: 'сводку считает сервер');
    });
  });

  test('TripModel: JSON → entity → JSON без потерь', () {
    const json = {
      'id': 't1',
      'start': '2026-10-01T08:10:00+05:00',
      'end': '2026-10-01T08:32:00+05:00',
      'amount': 2400,
      'payment': 'card',
      'commission': 360,
    };

    final entity = TripModel.fromJson(json).toEntity();

    expect(entity.duration, const Duration(minutes: 22));
    expect(entity.net, 2040);
    expect(TripModel.fromEntity(entity).toJson(), json);
  });
}
