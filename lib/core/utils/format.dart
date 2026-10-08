import 'package:intl/intl.dart';

// ponytail: валюта зашита — данные с +05:00, значит тенге. Мультивалютность —
// поле currency в API и NumberFormat.currency.
const currencySymbol = '₸';

final _number = NumberFormat.decimalPattern('ru');

/// `2 400` (разделитель разрядов — неразрывный пробел).
String formatNumber(int n) => _number.format(n);

/// `2 400 ₸`
String formatMoney(int amount) => '${formatNumber(amount)} $currencySymbol';

String formatTime(DateTime t) => DateFormat('HH:mm').format(t);

/// `22 мин`, `1 ч 05 мин`.
String formatDuration(Duration d) {
  final m = d.inMinutes;
  if (m < 60) return '$m мин';
  return '${m ~/ 60} ч ${(m % 60).toString().padLeft(2, '0')} мин';
}

/// `Среда, 1 октября`. Нужны данные локали `ru` — их грузит
/// GlobalMaterialLocalizations, т.е. вызывать внутри MaterialApp.
String formatDay(DateTime day) {
  final s = DateFormat('EEEE, d MMMM', 'ru').format(day);
  return s[0].toUpperCase() + s.substring(1);
}
