import 'dart:convert';

import 'package:driver_diary_server/src/api.dart';
import 'package:driver_diary_server/src/trip_store.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const base = 'http://localhost';

Map<String, Object?> body({
  Object? amount = 2400,
  String start = '2026-10-01T08:10:00+05:00',
  String end = '2026-10-01T08:32:00+05:00',
}) => {
  'id': 't1',
  'start': start,
  'end': end,
  'amount': amount,
  'payment': 'card',
  'commission': 360,
};

void main() {
  late Handler api;

  setUp(() => api = buildApi(TripStore.memory()));

  Future<(int, dynamic)> send(
    String method,
    String path, [
    Object? json,
  ]) async {
    final res = await api(
      Request(
        method,
        Uri.parse('$base$path'),
        body: json is String ? json : jsonEncode(json),
      ),
    );
    return (res.statusCode, jsonDecode(await res.readAsString()));
  }

  test('POST дважды: 201, затем 200 и та же поездка', () async {
    final (s1, b1) = await send('POST', '/trips', body());
    final (s2, b2) = await send('POST', '/trips', body());

    expect(s1, 201);
    expect(s2, 200);
    expect(b2, b1);

    final (_, trips) = await send('GET', '/trips?date=2026-10-01');
    expect(trips, hasLength(1));
  });

  test('GET сводки после добавления', () async {
    await send('POST', '/trips', body());

    final (status, summary) = await send(
      'GET',
      '/trips/summary?date=2026-10-01',
    );

    expect(status, 200);
    expect(summary, containsPair('net', 2040));
    expect(summary['card'], {'count': 1, 'amount': 2400});
  });

  group('валидация → 400 с ошибками по полям', () {
    Future<Map<String, dynamic>> fields(Object? json) async {
      final (status, res) = await send('POST', '/trips', json);
      expect(status, 400);
      return (res as Map<String, dynamic>)['fields'] as Map<String, dynamic>;
    }

    test('сумма 0', () async {
      expect(await fields(body(amount: 0)), contains('amount'));
    });

    test('сумма не целая', () async {
      expect(await fields(body(amount: 10.5)), contains('amount'));
    });

    test('окончание раньше начала', () async {
      expect(
        await fields(body(end: '2026-10-01T08:00:00+05:00')),
        contains('end'),
      );
    });

    test('окончание равно началу', () async {
      expect(
        await fields(body(end: '2026-10-01T08:10:00+05:00')),
        contains('end'),
      );
    });

    test('время без смещения', () async {
      expect(
        await fields(body(start: '2026-10-01T08:10:00')),
        contains('start'),
      );
    });

    test('несуществующая дата', () async {
      expect(
        await fields(
          body(
            start: '2026-02-30T08:10:00+05:00',
            end: '2026-02-30T08:20:00+05:00',
          ),
        ),
        contains('start'),
      );
    });

    test('все ошибки сразу', () async {
      expect(await fields({'payment': 'crypto'}).then((f) => f.keys), {
        'start',
        'end',
        'amount',
        'commission',
        'payment',
      });
    });

    test('не JSON', () async {
      expect(await fields('{oops'), contains('body'));
    });
  });

  test('GET без date → 400', () async {
    final (status, _) = await send('GET', '/trips?date=2026-13-01');
    expect(status, 400);
  });
}
