import 'package:driver_diary/core/error/app_exception.dart';
import 'package:driver_diary/features/trips/domain/entities/day_report.dart';
import 'package:driver_diary/features/trips/domain/repositories/trips_repository.dart';

/// Stale-while-revalidate: сразу кэш с устройства, потом свежие данные.
/// Нет связи — остаёмся на кэше с пометкой offline, а не на экране ошибки.
class WatchDayReport {
  const WatchDayReport(this._repository);

  final TripsRepository _repository;

  Stream<DayReport> call(DateTime day) async* {
    final cached = await _repository.cachedDay(day);
    if (cached != null) {
      yield cached.copyWith(
        pending: await _repository.pendingFor(day),
        freshness: Freshness.cached,
      );
    }

    try {
      // Сначала очередь: тогда свежий отчёт уже включает отправленное.
      await _repository.syncPending();
      final fresh = await _repository.fetchDay(day);
      yield fresh.copyWith(pending: await _repository.pendingFor(day));
    } on AppException catch (e) {
      if (cached == null || !e.retryable) rethrow;
      yield cached.copyWith(
        pending: await _repository.pendingFor(day),
        freshness: Freshness.offline,
      );
    }
  }
}
