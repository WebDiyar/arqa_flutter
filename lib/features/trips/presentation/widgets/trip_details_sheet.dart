import 'package:driver_diary/core/theme/app_theme.dart';
import 'package:driver_diary/core/utils/format.dart';
import 'package:driver_diary/features/trips/domain/entities/pending_trip.dart';
import 'package:driver_diary/features/trips/domain/entities/trip.dart';
import 'package:flutter/material.dart';

/// Детали поездки снизу экрана. Для неотправленной — статус и «Удалить».
Future<void> showTripDetails(
  BuildContext context,
  Trip trip, {
  PendingTrip? pending,
  VoidCallback? onDiscard,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // По умолчанию лист не выше 9/16 экрана — на невысоком телефоне кнопка
    // «Удалить» обрезалась. Пусть берёт высоту по содержимому и скроллится.
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (context) {
      final t = trip;
      final isCash = t.payment == PaymentMethod.cash;
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${formatTime(t.start.wall)}–${formatTime(t.end.wall)}',
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
                Text(
                  '${formatDay(t.start.day)} · ${formatDuration(t.duration)}',
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
                if (pending != null) ...[
                  const SizedBox(height: 12),
                  _Status(pending: pending),
                ],
                const SizedBox(height: 16),
                _Row('Оплата', isCash ? 'Наличные' : 'Карта'),
                _Row('Сумма', formatMoney(t.amount)),
                _Row('Комиссия', '−${formatMoney(t.commission)}'),
                _Row('На руки', formatMoney(t.net), bold: true),
                if (onDiscard != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onDiscard();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Удалить с устройства'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.pending});

  final PendingTrip pending;

  @override
  Widget build(BuildContext context) {
    final rejected = pending.rejected;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: rejected
            ? AppColors.danger.withValues(alpha: 0.1)
            : AppColors.warning,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          rejected
              ? 'Сервер отклонил: ${pending.error}'
              : 'Ещё не отправлена — уйдёт автоматически, когда появится связь. '
                    'В сводку войдёт после отправки.',
          style: TextStyle(
            color: rejected ? AppColors.danger : AppColors.onWarning,
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.inkMuted),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              fontSize: bold ? 18 : 15,
            ),
          ),
        ],
      ),
    );
  }
}
