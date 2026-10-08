import 'package:driver_diary/core/error/app_exception.dart';
import 'package:driver_diary/features/trips/domain/entities/trip.dart';
import 'package:driver_diary/features/trips/domain/repositories/trips_repository.dart';

class AddTrip {
  const AddTrip(this._repository);

  final TripsRepository _repository;

  /// Невалидная поездка до сети не доходит. Сервер проверяет всё повторно.
  /// `async` обязателен: иначе throw вылетит синхронно, мимо `.catchError`
  /// и `expectLater` у вызывающего.
  Future<AddOutcome> call(Trip trip) async {
    final errors = trip.validate();
    if (errors.isNotEmpty) {
      throw AppException('Проверьте данные', fields: errors);
    }
    return _repository.addTrip(trip);
  }
}
