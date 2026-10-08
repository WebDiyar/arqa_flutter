import 'dart:async';

import 'package:driver_diary/core/theme/app_theme.dart';
import 'package:driver_diary/core/time/zoned_date_time.dart';
import 'package:driver_diary/core/utils/format.dart';
import 'package:driver_diary/core/widgets/content_width.dart';
import 'package:driver_diary/core/widgets/error_view.dart';
import 'package:driver_diary/core/widgets/slow_loading.dart';
import 'package:driver_diary/features/trips/di.dart';
import 'package:driver_diary/features/trips/domain/entities/day_report.dart';
import 'package:driver_diary/features/trips/presentation/providers/day_report_provider.dart';
import 'package:driver_diary/features/trips/presentation/widgets/day_receipt.dart';
import 'package:driver_diary/features/trips/presentation/widgets/day_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DayPage extends ConsumerWidget {
  const DayPage({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = dayReportProvider(day);
    final report = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(title: const Text('Дневник смен')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/day/${dayKey(day)}/new'),
        icon: const Icon(Icons.add),
        label: const Text('Поездка'),
      ),
      body: ContentWidth(
        child: Column(
          children: [
            DaySwitcher(day: day),
            Expanded(
              child: report.when(
                skipLoadingOnReload: true,
                data: (r) => _DayView(
                  day: day,
                  report: r,
                  onRefresh: () => _refresh(ref, provider),
                  onRetry: () => ref.invalidate(provider),
                  onDiscardPending: (id) async {
                    await ref.read(discardPendingTripProvider)(id);
                    ref.invalidate(provider);
                  },
                ),
                error: (e, _) => ErrorView(
                  message: '$e',
                  onRetry: () => ref.invalidate(provider),
                ),
                loading: () => const SlowLoading(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pull-to-refresh ждёт ответа сервера (или ошибки), а не мгновенного кэша:
/// `provider.future` завершился бы на первом же значении — кэше.
Future<void> _refresh(WidgetRef ref, StreamProvider<DayReport> provider) {
  final done = Completer<void>();
  final sub = ref.listenManual(provider, (_, next) {
    final settled =
        !next.isLoading &&
        (next.hasError || next.value?.freshness != Freshness.cached);
    if (settled && !done.isCompleted) done.complete();
  });
  ref.invalidate(provider);
  return done.future.whenComplete(sub.close);
}

class _DayView extends StatelessWidget {
  const _DayView({
    required this.day,
    required this.report,
    required this.onRefresh,
    required this.onRetry,
    required this.onDiscardPending,
  });

  final DateTime day;
  final DayReport report;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final void Function(String id) onDiscardPending;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            // снизу место под FAB, чтобы он не закрывал «На руки»
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
            children: [
              if (report.freshness == Freshness.offline) ...[
                _OfflineBanner(syncedAt: report.syncedAt, onRetry: onRetry),
                const SizedBox(height: 12),
              ],
              DayReceipt(
                day: day,
                report: report,
                onDiscardPending: onDiscardPending,
              ),
            ],
          ),
        ),
        // Показан кэш, свежие данные ещё в пути — тонкая полоска сверху.
        if (report.freshness == Freshness.cached)
          const Positioned(
            top: 0,
            left: 16,
            right: 16,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.syncedAt, required this.onRetry});

  final DateTime syncedAt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.isSameDay(syncedAt, DateTime.now());
    final when = today
        ? 'в ${formatTime(syncedAt)}'
        : '${formatDay(syncedAt)}, ${formatTime(syncedAt)}';

    return Material(
      color: AppColors.warning,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: AppColors.onWarning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Нет связи с сервером. Данные сохранены $when',
                style: const TextStyle(color: AppColors.onWarning),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}
