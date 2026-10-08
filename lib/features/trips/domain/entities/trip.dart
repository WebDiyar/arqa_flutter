import 'package:driver_diary/core/time/zoned_date_time.dart';

enum PaymentMethod { cash, card }

class Trip {
  const Trip({
    required this.id,
    required this.start,
    required this.end,
    required this.amount,
    required this.payment,
    required this.commission,
  });

  final String id;
  final ZonedDateTime start;
  final ZonedDateTime end;
  final int amount;
  final PaymentMethod payment;
  final int commission;

  Duration get duration => end.instant.difference(start.instant);

  /// Заработок водителя с этой поездки.
  int get net => amount - commission;

  /// Те же правила, что на сервере. Ключи совпадают с полями API,
  /// поэтому ошибки сервера (400) и локальные показываются одинаково.
  Map<String, String> validate() => {
    if (amount <= 0) 'amount': 'Сумма должна быть больше 0',
    if (commission < 0) 'commission': 'Комиссия не может быть отрицательной',
    if (commission > amount) 'commission': 'Комиссия не может превышать сумму',
    if (!end.instant.isAfter(start.instant))
      'end': 'Окончание должно быть позже начала',
  };
}
