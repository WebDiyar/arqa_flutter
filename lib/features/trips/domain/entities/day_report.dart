import 'package:driver_diary/features/trips/domain/entities/day_summary.dart';
import 'package:driver_diary/features/trips/domain/entities/pending_trip.dart';
import 'package:driver_diary/features/trips/domain/entities/trip.dart';

/// Откуда данные на экране.
enum Freshness {
  /// Из кэша на устройстве; запрос к серверу ещё идёт.
  cached,

  /// Только что с сервера.
  fresh,

  /// Из кэша; сервер недоступен.
  offline,
}

/// Всё, что нужно экрану дня.
class DayReport {
  const DayReport({
    required this.summary,
    required this.trips,
    required this.syncedAt,
    this.pending = const [],
    this.freshness = Freshness.fresh,
  });

  final DaySummary summary;
  final List<Trip> trips;

  /// Когда данные получены с сервера.
  final DateTime syncedAt;

  /// Добавлены без связи и ждут отправки. В сводку не входят:
  /// её считает сервер, клиент не пересчитывает.
  final List<PendingTrip> pending;
  final Freshness freshness;

  DayReport copyWith({List<PendingTrip>? pending, Freshness? freshness}) =>
      DayReport(
        summary: summary,
        trips: trips,
        syncedAt: syncedAt,
        pending: pending ?? this.pending,
        freshness: freshness ?? this.freshness,
      );
}
