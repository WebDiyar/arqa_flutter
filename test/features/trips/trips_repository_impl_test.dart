import 'package:dio/dio.dart';
import 'package:driver_diary/core/error/app_exception.dart';
import 'package:driver_diary/features/trips/data/datasources/trips_local_data_source.dart';
import 'package:driver_diary/features/trips/data/datasources/trips_remote_data_source.dart';
import 'package:driver_diary/features/trips/data/models/trip_model.dart';
import 'package:driver_diary/features/trips/data/repositories/trips_repository_impl.dart';
import 'package:driver_diary/features/trips/domain/repositories/trips_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_trips_repository.dart';

/// «Сервер»: хранит принятые поездки по id (идемпотентно, как настоящий),
/// умеет «падать» и отказывать.
class FakeRemote implements TripsRemoteDataSource {
  final accepted = <String, TripModel>{};
  var posts = 0;
  var down = false;
  String? rejectWith;

  DioException _error({int? status, Object? data}) => DioException(
    requestOptions: RequestOptions(),
    type: status == null
        ? DioExceptionType.connectionError
        : DioExceptionType.badResponse,
    response: status == null
        ? null
        : Response(
            requestOptions: RequestOptions(),
            statusCode: status,
            data: data,
          ),
  );

  @override
  Future<TripModel> addTrip(TripModel trip) async {
    posts++;
    if (down) throw _error();
    if (rejectWith != null) {
      throw _error(
        status: 409,
        data: {'error': 'conflict', 'message': rejectWith},
      );
    }
    return accepted[trip.id] ??= trip;
  }

  @override
  Future<List<TripModel>> getTrips(String date) async {
    if (down) throw _error();
    return accepted.values.toList();
  }

  @override
  Future<Map<String, dynamic>> getSummary(String date) async {
    if (down) throw _error();
    return {
      'tripsCount': accepted.length,
      'revenue': 0,
      'commission': 0,
      'net': 0,
      'cash': {'count': 0, 'amount': 0},
      'card': {'count': 0, 'amount': 0},
    };
  }
}

void main() {
  late FakeRemote remote;
  late TripsRepositoryImpl repo;
  final day = DateTime(2026, 10, 1);
  final t1 = sampleReport.trips[0];
  final t2 = sampleReport.trips[1];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    remote = FakeRemote();
    repo = TripsRepositoryImpl(
      remote,
      TripsLocalDataSource(await SharedPreferences.getInstance()),
    );
  });

  test('fetchDay кладёт отчёт в кэш, cachedDay его отдаёт', () async {
    await repo.addTrip(t1);
    expect(await repo.cachedDay(day), isNull);

    await repo.fetchDay(day);
    remote.down = true;

    final cached = await repo.cachedDay(day);
    expect(cached!.trips.single.id, 't1');
  });

  group('офлайн-очередь', () {
    test('нет связи → поездка в очереди, а не ошибка', () async {
      remote.down = true;

      expect(await repo.addTrip(t1), AddOutcome.queued);
      expect((await repo.pendingFor(day)).single.trip.id, 't1');
    });

    test('связь вернулась → syncPending отправляет и чистит очередь', () async {
      remote.down = true;
      await repo.addTrip(t1);
      await repo.addTrip(t2);

      remote.down = false;
      await repo.syncPending();

      expect(remote.accepted.keys, {'t1', 't2'});
      expect(await repo.pendingFor(day), isEmpty);
    });

    test('параллельные синхронизации не создают дублей', () async {
      remote.down = true;
      await repo.addTrip(t1);

      remote.down = false;
      await Future.wait([repo.syncPending(), repo.syncPending()]);

      expect(remote.accepted, hasLength(1));
    });

    test('сервер отказал → поездка помечена, больше не отправляется', () async {
      remote.down = true;
      await repo.addTrip(t1);
      remote
        ..down = false
        ..rejectWith = 'Пересекается с поездкой t9';

      await repo.syncPending();
      final postsAfterFirstSync = remote.posts;
      await repo.syncPending();

      final pending = (await repo.pendingFor(day)).single;
      expect(pending.error, 'Пересекается с поездкой t9');
      expect(remote.posts, postsAfterFirstSync);
    });

    test('отказ сервера при обычной отправке — ошибка, не очередь', () {
      remote.rejectWith = 'Пересекается';

      expect(repo.addTrip(t1), throwsA(isA<AppException>()));
    });

    test('discardPending удаляет из очереди', () async {
      remote.down = true;
      await repo.addTrip(t1);

      await repo.discardPending('t1');

      expect(await repo.pendingFor(day), isEmpty);
    });
  });
}
