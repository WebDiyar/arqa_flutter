import 'dart:convert';
import 'dart:io';

import 'package:driver_diary_server/src/summary.dart';
import 'package:driver_diary_server/src/trip.dart';
import 'package:driver_diary_server/src/trip_store.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// GET  /trips?date=YYYY-MM-DD          → [Trip]
/// GET  /trips/summary?date=YYYY-MM-DD  → DaySummary
/// POST /trips                          → 201 создана | 200 повтор (дубль не создан)
///                                        400 валидация | 409 конфликт
Handler buildApi(TripStore store) {
  final router = Router()
    ..get('/health', (Request _) => _json(200, {'status': 'ok'}))
    ..get('/trips', (Request req) => _json(200, store.byDay(_date(req))))
    ..get('/trips/summary', (Request req) {
      final date = _date(req);
      return _json(200, DaySummary.of(date, store.byDay(date)));
    })
    ..post('/trips', (Request req) async {
      final Object? body;
      try {
        body = jsonDecode(await req.readAsString());
      } on FormatException {
        throw ValidationException({'body': 'Тело запроса — не JSON'});
      }
      final (trip, created) = await store.add(Trip.fromJson(body));
      return _json(created ? 201 : 200, trip);
    });

  return const Pipeline()
      .addMiddleware(_cors)
      .addMiddleware(_errors)
      .addHandler(router.call);
}

String _date(Request req) {
  final date = req.url.queryParameters['date'];
  if (date == null || !isDay(date)) {
    throw ValidationException({'date': 'Нужен параметр date=YYYY-MM-DD'});
  }
  return date;
}

Response _json(int status, Object? body) => Response(
  status,
  body: jsonEncode(body),
  headers: {HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8'},
);

Response _error(int status, String code, String message, [Object? fields]) =>
    _json(status, {'error': code, 'message': message, 'fields': ?fields});

Handler _errors(Handler inner) => (req) async {
  try {
    return await inner(req);
  } on ValidationException catch (e) {
    return _error(400, 'validation', 'Проверьте данные', e.fields);
  } on ConflictException catch (e) {
    return _error(409, 'conflict', e.message);
  } catch (e, st) {
    stderr.writeln('$e\n$st');
    return _error(500, 'internal', 'Внутренняя ошибка сервера');
  }
};

// Нужен для клиента в браузере (flutter run -d chrome): другой порт = другой origin.
const _corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
  'access-control-allow-headers': 'content-type',
};

Handler _cors(Handler inner) => (req) async {
  if (req.method == 'OPTIONS') return Response.ok(null, headers: _corsHeaders);
  return (await inner(req)).change(headers: _corsHeaders);
};
