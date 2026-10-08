import 'dart:math';

enum Payment { cash, card }

/// Ошибки по полям: `{'amount': 'Сумма должна быть больше 0'}` → HTTP 400.
class ValidationException implements Exception {
  ValidationException(this.fields);

  final Map<String, String> fields;

  @override
  String toString() => 'ValidationException($fields)';
}

class Trip {
  const Trip({
    required this.id,
    required this.start,
    required this.end,
    required this.amount,
    required this.payment,
    required this.commission,
  });

  /// Парсинг + валидация тела запроса. Собирает все ошибки сразу,
  /// а не падает на первой — клиенту удобнее подсветить все поля.
  factory Trip.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw ValidationException({'body': 'Ожидается JSON-объект'});
    }
    final errors = <String, String>{};

    final id = json['id'];
    if (id != null && (id is! String || id.isEmpty || id.length > 64)) {
      errors['id'] = 'Строка от 1 до 64 символов';
    }

    DateTime? time(String key) {
      final value = json[key];
      if (value is String && isZonedDateTime(value)) {
        return DateTime.parse(value);
      }
      errors[key] = 'ISO-8601 со смещением, например 2026-10-01T08:10:00+05:00';
      return null;
    }

    final start = time('start');
    final end = time('end');
    if (start != null && end != null && !end.isAfter(start)) {
      errors['end'] = 'Окончание должно быть позже начала';
    }

    final amount = json['amount'];
    if (amount is! int || amount <= 0) {
      errors['amount'] = 'Сумма должна быть целым числом больше 0';
    }

    final commission = json['commission'];
    if (commission is! int || commission < 0) {
      errors['commission'] = 'Комиссия должна быть целым числом ≥ 0';
    } else if (amount is int && commission > amount) {
      errors['commission'] = 'Комиссия не может превышать сумму';
    }

    final payment = Payment.values.asNameMap()[json['payment']];
    if (payment == null) errors['payment'] = 'Допустимо: cash, card';

    if (errors.isNotEmpty) throw ValidationException(errors);

    return Trip(
      id: id as String? ?? newId(),
      start: json['start'] as String,
      end: json['end'] as String,
      amount: amount as int,
      payment: payment!,
      commission: commission as int,
    );
  }

  final String id;

  /// Храним исходные строки со смещением. `DateTime.parse` переводит в UTC и
  /// теряет смещение, а день поездки — это дата на часах водителя:
  /// `2026-10-03T00:30+05:00` относится к 3 октября, хотя в UTC это 2 октября.
  final String start;
  final String end;
  final int amount;
  final Payment payment;
  final int commission;

  DateTime get startAt => DateTime.parse(start);
  DateTime get endAt => DateTime.parse(end);

  /// Локальная дата начала (YYYY-MM-DD). Поездка через полночь — день начала.
  String get day => start.substring(0, 10);

  /// Та же поездка: совпадает всё, кроме id. Время сравнивается как момент,
  /// поэтому `08:10+05:00` и `03:10Z` — одно и то же.
  bool sameAs(Trip other) =>
      startAt.isAtSameMomentAs(other.startAt) &&
      endAt.isAtSameMomentAs(other.endAt) &&
      amount == other.amount &&
      payment == other.payment &&
      commission == other.commission;

  /// Водитель не может везти два заказа одновременно.
  bool overlaps(Trip other) =>
      startAt.isBefore(other.endAt) && other.startAt.isBefore(endAt);

  Map<String, Object> toJson() => {
    'id': id,
    'start': start,
    'end': end,
    'amount': amount,
    'payment': payment.name,
    'commission': commission,
  };
}

final _zoned = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,6})?)?(Z|[+-]\d{2}:\d{2})$',
);
final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Строгая проверка: `DateTime.parse` молча превращает 2026-02-30 в 2 марта,
/// а 25:00 — в 01:00 следующего дня. Сверяем, что дата-время не «переехало».
bool isZonedDateTime(String value) =>
    _zoned.hasMatch(value) && _isReal(value.substring(0, 16));

bool isDay(String value) => _date.hasMatch(value) && _isReal('${value}T00:00');

bool _isReal(String wallClock) =>
    DateTime.parse('${wallClock}Z').toIso8601String().startsWith(wallClock);

final _random = Random.secure();

String newId() => List.generate(
  16,
  (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
