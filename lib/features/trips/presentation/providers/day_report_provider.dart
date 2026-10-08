import 'package:driver_diary/features/trips/di.dart';
import 'package:driver_diary/features/trips/domain/entities/day_report.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Отчёт за день: сначала кэш, потом сервер (см. WatchDayReport).
/// Ключ — дата без времени (`DateTime(y, m, d)`).
/// autoDispose: ушёл с дня — подписка закрыта, вернулся — свежий запрос.
final dayReportProvider = StreamProvider.autoDispose
    .family<DayReport, DateTime>(
      (ref, day) => ref.watch(watchDayReportProvider)(day),
    );
