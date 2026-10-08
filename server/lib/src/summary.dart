import 'package:driver_diary_server/src/trip.dart';

class PaymentTotals {
  const PaymentTotals({this.count = 0, this.amount = 0});

  final int count;
  final int amount;

  PaymentTotals operator +(Trip t) =>
      PaymentTotals(count: count + 1, amount: amount + t.amount);

  Map<String, int> toJson() => {'count': count, 'amount': amount};
}

/// Сводка за день. Деньги — целые числа в основной единице валюты.
class DaySummary {
  const DaySummary({
    required this.date,
    this.tripsCount = 0,
    this.revenue = 0,
    this.commission = 0,
    this.cash = const PaymentTotals(),
    this.card = const PaymentTotals(),
  });

  factory DaySummary.of(String date, Iterable<Trip> trips) => trips.fold(
    DaySummary(date: date),
    (s, t) => DaySummary(
      date: date,
      tripsCount: s.tripsCount + 1,
      revenue: s.revenue + t.amount,
      commission: s.commission + t.commission,
      cash: t.payment == Payment.cash ? s.cash + t : s.cash,
      card: t.payment == Payment.card ? s.card + t : s.card,
    ),
  );

  final String date;
  final int tripsCount;

  /// Сумма всех поездок.
  final int revenue;
  final int commission;
  final PaymentTotals cash;
  final PaymentTotals card;

  /// «На руки» = выручка − комиссия.
  int get net => revenue - commission;

  Map<String, Object> toJson() => {
    'date': date,
    'tripsCount': tripsCount,
    'revenue': revenue,
    'commission': commission,
    'net': net,
    'cash': cash.toJson(),
    'card': card.toJson(),
  };
}
