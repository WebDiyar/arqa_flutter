import 'package:driver_diary/features/trips/domain/entities/day_report.dart';
import 'package:driver_diary/features/trips/domain/entities/pending_trip.dart';
import 'package:driver_diary/features/trips/domain/entities/trip.dart';

enum AddOutcome {
  /// Сервер принял (или это повтор уже принятой — дубль не создан).
  sent,

  /// Сервер недоступен: поездка сохранена на устройстве и уйдёт позже.
  queued,
}

/// Контракт. Реализация — в data/. Бросает только AppException.
abstract interface class TripsRepository {
  /// Последний отчёт за [day], сохранённый на устройстве.
  Future<DayReport?> cachedDay(DateTime day);

  /// Отчёт с сервера (поездки + сводка); заодно обновляет кэш.
  Future<DayReport> fetchDay(DateTime day);

  /// Неотправленные поездки, начавшиеся в [day].
  Future<List<PendingTrip>> pendingFor(DateTime day);

  /// Идемпотентно по [Trip.id]. Нет связи → в очередь.
  Future<AddOutcome> addTrip(Trip trip);

  /// Отправляет очередь. Нет связи — тихо останавливается до следующего раза;
  /// отказ сервера помечается в поездке. Безопасно вызывать параллельно:
  /// повторная отправка того же id на сервере дубля не создаёт.
  Future<void> syncPending();

  Future<void> discardPending(String id);
}
