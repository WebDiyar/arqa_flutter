class PaymentTotals {
  const PaymentTotals({required this.count, required this.amount});

  final int count;
  final int amount;
}

/// Считается на сервере — клиент только показывает.
class DaySummary {
  const DaySummary({
    required this.tripsCount,
    required this.revenue,
    required this.commission,
    required this.net,
    required this.cash,
    required this.card,
  });

  final int tripsCount;
  final int revenue;
  final int commission;

  /// «На руки» = выручка − комиссия.
  final int net;
  final PaymentTotals cash;
  final PaymentTotals card;
}
