import 'package:driver_diary/core/theme/app_theme.dart';
import 'package:driver_diary/core/utils/format.dart';
import 'package:driver_diary/features/trips/domain/entities/day_report.dart';
import 'package:driver_diary/features/trips/domain/entities/pending_trip.dart';
import 'package:driver_diary/features/trips/domain/entities/trip.dart';
import 'package:driver_diary/features/trips/presentation/widgets/trip_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _mono = TextStyle(
  fontFamily: AppFonts.mono,
  fontFamilyFallback: AppFonts.monoFallback,
  fontSize: 14,
  height: 1.7,
  color: AppColors.paperInk,
);

/// День как кассовый чек — один в один с макетом задания:
/// поездки → итоги → «На руки». Тап по строке — детали поездки.
class DayReceipt extends StatelessWidget {
  const DayReceipt({
    super.key,
    required this.day,
    required this.report,
    required this.onDiscardPending,
  });

  final DateTime day;
  final DayReport report;
  final void Function(String id) onDiscardPending;

  @override
  Widget build(BuildContext context) {
    final s = report.summary;

    return PhysicalShape(
      clipper: const _ZigzagClipper(),
      color: AppColors.paper,
      elevation: 2,
      shadowColor: AppColors.ink.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: DefaultTextStyle(
          style: _mono,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Дневник смен',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                DateFormat('dd.MM.yyyy').format(day),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.paperMuted),
              ),
              const SizedBox(height: 16),
              if (report.trips.isEmpty)
                const Text(
                  'Поездок нет',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.paperMuted),
                )
              else
                for (final t in report.trips)
                  _TripLine(trip: t, onTap: () => showTripDetails(context, t)),
              if (report.pending.isNotEmpty) ...[
                const _DashedRule(),
                _Padded(
                  Text(
                    'Не отправлено (${report.pending.length})',
                    style: const TextStyle(color: AppColors.paperMuted),
                  ),
                ),
                for (final p in report.pending)
                  _TripLine(
                    trip: p.trip,
                    pending: p,
                    onTap: () => showTripDetails(
                      context,
                      p.trip,
                      pending: p,
                      onDiscard: () => onDiscardPending(p.trip.id),
                    ),
                  ),
              ],
              const _DashedRule(),
              _Line('Поездок', '${s.tripsCount}'),
              _Line('Выручка', formatMoney(s.revenue)),
              // U+2212 — настоящий минус, как в макете, а не дефис
              _Line(
                'Комиссия',
                s.commission == 0
                    ? formatMoney(0)
                    : '−${formatMoney(s.commission)}',
              ),
              _Line(
                'Наличные / карта',
                '${formatNumber(s.cash.amount)} / ${formatNumber(s.card.amount)}',
              ),
              const _DashedRule(),
              _Padded(
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Expanded(child: Text('На руки')),
                    Text(
                      formatMoney(s.net),
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        letterSpacing: -0.56,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripLine extends StatelessWidget {
  const _TripLine({required this.trip, required this.onTap, this.pending});

  final Trip trip;
  final VoidCallback onTap;
  final PendingTrip? pending;

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final isCash = t.payment == PaymentMethod.cash;
    final nextDay = t.end.day != t.start.day;
    final mark = switch (pending) {
      null => '',
      PendingTrip(rejected: true) => '! ',
      _ => '⏳ ',
    };

    return Semantics(
      button: true,
      label:
          '${pending == null ? '' : 'Не отправлено. '}'
          'Поездка ${formatTime(t.start.wall)}–${formatTime(t.end.wall)}, '
          '${isCash ? 'наличные' : 'карта'}, ${formatMoney(t.amount)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: _Line(
          '$mark${formatTime(t.start.wall)}–${formatTime(t.end.wall)}'
          '${nextDay ? '⁺¹' : ''} ${isCash ? 'нал.' : 'карта'}',
          formatMoney(t.amount),
          color: pending?.rejected ?? false ? AppColors.danger : null,
          muted: pending != null && !pending!.rejected,
        ),
      ),
    );
  }
}

/// Горизонтальные поля чека. Строки с InkWell тянутся на всю ширину, чтобы
/// подсветка тапа доходила до края бумаги, поэтому поля — у каждой строки.
class _Padded extends StatelessWidget {
  const _Padded(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: child,
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.color, this.muted = false});

  final String label;
  final String value;
  final Color? color;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return _Padded(
      DefaultTextStyle.merge(
        style: TextStyle(color: color ?? (muted ? AppColors.paperMuted : null)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Text(value),
          ],
        ),
      ),
    );
  }
}

class _DashedRule extends StatelessWidget {
  const _DashedRule();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 14, 24, 14),
      child: CustomPaint(
        size: Size(double.infinity, 1),
        painter: _DashPainter(),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.paperRule
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + 4, 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => false;
}

/// Рваный край чека сверху и снизу.
class _ZigzagClipper extends CustomClipper<Path> {
  const _ZigzagClipper();

  static const _tooth = 10.0;
  static const _depth = 5.0;

  @override
  Path getClip(Size size) {
    final teeth = (size.width / _tooth).ceil();
    final step = size.width / teeth;
    final path = Path()..moveTo(0, _depth);
    for (var i = 0; i < teeth; i++) {
      path
        ..lineTo(step * i + step / 2, 0)
        ..lineTo(step * (i + 1), _depth);
    }
    path.lineTo(size.width, size.height - _depth);
    for (var i = teeth; i > 0; i--) {
      path
        ..lineTo(step * i - step / 2, size.height)
        ..lineTo(step * (i - 1), size.height - _depth);
    }
    return path..close();
  }

  @override
  bool shouldReclip(_ZigzagClipper oldClipper) => false;
}
