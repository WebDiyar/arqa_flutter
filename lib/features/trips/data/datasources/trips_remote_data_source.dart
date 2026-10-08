import 'package:dio/dio.dart';
import 'package:driver_diary/features/trips/data/models/trip_model.dart';

class TripsRemoteDataSource {
  const TripsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<TripModel>> getTrips(String date) async {
    final res = await _dio.get<List<dynamic>>(
      '/trips',
      queryParameters: {'date': date},
    );
    return res.data!
        .map((e) => TripModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getSummary(String date) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/trips/summary',
      queryParameters: {'date': date},
    );
    return res.data!;
  }

  /// 201 — создана, 200 — повтор уже принятой. Для клиента разницы нет.
  Future<TripModel> addTrip(TripModel trip) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/trips',
      data: trip.toJson(),
    );
    return TripModel.fromJson(res.data!);
  }
}
