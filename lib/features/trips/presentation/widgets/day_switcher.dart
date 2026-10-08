import 'package:driver_diary/core/theme/app_theme.dart';
import 'package:driver_diary/core/time/zoned_date_time.dart';
import 'package:driver_diary/core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// ‹ Среда, 1 октября › — стрелки листают дни, тап по дате открывает календарь.
class DaySwitcher extends StatelessWidget {
  const DaySwitcher({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final isToday = DateUtils.isSameDay(day, today);
    // DateTime(y, m, d ± 1), а не add(Duration(days: 1)): в день перевода
    // часов сутки длятся 23 или 25 часов.
    void goTo(DateTime d) => context.go('/day/${dayKey(d)}');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Предыдущий день',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => goTo(DateTime(day.year, day.month, day.day - 1)),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: day,
                    firstDate: DateTime(2020),
                    lastDate: today,
                  );
                  if (picked != null) goTo(picked);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Text(
                        formatDay(day),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        isToday ? 'Сегодня' : 'Выбрать дату',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Следующий день',
              icon: const Icon(Icons.chevron_right),
              // в будущем поездок быть не может
              onPressed: isToday
                  ? null
                  : () => goTo(DateTime(day.year, day.month, day.day + 1)),
            ),
          ],
        ),
      ),
    );
  }
}
