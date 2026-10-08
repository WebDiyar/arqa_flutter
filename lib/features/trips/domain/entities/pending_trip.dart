import 'package:driver_diary/features/trips/domain/entities/trip.dart';

/// Поездка в очереди на отправку (добавлена без связи).
class PendingTrip {
  const PendingTrip(this.trip, {this.error});

  final Trip trip;

  /// Почему сервер отказал (например, пересечение по времени). Такая
  /// поездка больше не отправляется: водитель исправляет или удаляет её.
  final String? error;

  bool get rejected => error != null;
}
