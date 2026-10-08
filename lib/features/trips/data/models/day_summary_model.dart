import 'package:driver_diary/features/trips/domain/entities/day_summary.dart';

/// `GET /trips/summary` ↔ DaySummary. Отдельный класс-DTO не нужен:
/// формы совпадают, разбираем JSON прямо в entity.
DaySummary daySummaryFromJson(Map<String, dynamic> json) {
  PaymentTotals totals(Object? j) {
    final m = j! as Map<String, dynamic>;
    return PaymentTotals(count: m['count'] as int, amount: m['amount'] as int);
  }

  return DaySummary(
    tripsCount: json['tripsCount'] as int,
    revenue: json['revenue'] as int,
    commission: json['commission'] as int,
    net: json['net'] as int,
    cash: totals(json['cash']),
    card: totals(json['card']),
  );
}

/// Для кэша на устройстве.
Map<String, Object> daySummaryToJson(DaySummary s) => {
  'tripsCount': s.tripsCount,
  'revenue': s.revenue,
  'commission': s.commission,
  'net': s.net,
  'cash': {'count': s.cash.count, 'amount': s.cash.amount},
  'card': {'count': s.card.count, 'amount': s.card.amount},
};
