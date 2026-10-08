import 'dart:io';

import 'package:driver_diary_server/src/trip.dart';
import 'package:driver_diary_server/src/trip_store.dart';
import 'package:test/test.dart';

Trip trip({
  String id = 't1',
  String start = '2026-10-01T08:10:00+05:00',
  String end = '2026-10-01T08:32:00+05:00',
  int amount = 2400,
}) => Trip(
  id: id,
  start: start,
  end: end,
  amount: amount,
  payment: Payment.card,
  commission: 360,
);

void main() {
  group('защита от дублей', () {
    test('повторная отправка той же поездки не создаёт дубль', () async {
      final store = TripStore.memory();

      final (_, first) = await store.add(trip());
      final (saved, second) = await store.add(trip());

      expect(first, isTrue);
      expect(second, isFalse);
      expect(saved.id, 't1');
      expect(store.byDay('2026-10-01'), hasLength(1));
    });

    test('те же данные под другим id — тоже дубль', () async {
      final store = TripStore.memory();
      await store.add(trip(id: 'a'));

      final (saved, created) = await store.add(trip(id: 'b'));

      expect(created, isFalse);
      expect(saved.id, 'a');
      expect(store.byDay('2026-10-01'), hasLength(1));
    });

    test('то же время в другом поясе — тот же момент, дубль', () async {
      final store = TripStore.memory();
      await store.add(trip());

      final (_, created) = await store.add(
        trip(
          id: 'x',
          start: '2026-10-01T03:10:00Z',
          end: '2026-10-01T03:32:00Z',
        ),
      );

      expect(created, isFalse);
    });

    test('параллельные одинаковые запросы — одна запись', () async {
      final store = TripStore.memory();

      final results = await Future.wait([
        for (var i = 0; i < 5; i++) store.add(trip()),
      ]);

      expect(results.where((r) => r.$2), hasLength(1));
      expect(store.byDay('2026-10-01'), hasLength(1));
    });

    test('тот же id с другими данными — конфликт, а не перезапись', () async {
      final store = TripStore.memory();
      await store.add(trip());

      expect(store.add(trip(amount: 9999)), throwsA(isA<ConflictException>()));
      expect(store.byDay('2026-10-01').single.amount, 2400);
    });

    test('пересечение по времени — конфликт', () async {
      final store = TripStore.memory();
      await store.add(trip());

      expect(
        store.add(
          trip(
            id: 't2',
            start: '2026-10-01T08:30:00+05:00',
            end: '2026-10-01T08:50:00+05:00',
          ),
        ),
        throwsA(isA<ConflictException>()),
      );
    });

    test('поездка встык с предыдущей — не пересечение', () async {
      final store = TripStore.memory();
      await store.add(trip());

      final (_, created) = await store.add(
        trip(
          id: 't2',
          start: '2026-10-01T08:32:00+05:00',
          end: '2026-10-01T08:50:00+05:00',
        ),
      );

      expect(created, isTrue);
    });
  });

  test('дубль не попадает и в файл после перезапуска', () async {
    final dir = await Directory.systemTemp.createTemp('trips');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/trips.json');

    final store = await TripStore.open(file);
    await store.add(trip());
    await store.add(trip());

    final reopened = await TripStore.open(file);
    expect(reopened.byDay('2026-10-01'), hasLength(1));
  });

  test('день поездки — дата на часах водителя, а не в UTC', () {
    final store = TripStore.memory([
      // 00:30 по +05:00 — в UTC это ещё 2 октября
      trip(
        start: '2026-10-03T00:30:00+05:00',
        end: '2026-10-03T00:55:00+05:00',
      ),
    ]);

    expect(store.byDay('2026-10-03'), hasLength(1));
    expect(store.byDay('2026-10-02'), isEmpty);
  });
}
