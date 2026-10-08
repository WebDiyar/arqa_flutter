import 'package:driver_diary/features/trips/domain/repositories/trips_repository.dart';

class DiscardPendingTrip {
  const DiscardPendingTrip(this._repository);

  final TripsRepository _repository;

  Future<void> call(String id) => _repository.discardPending(id);
}
