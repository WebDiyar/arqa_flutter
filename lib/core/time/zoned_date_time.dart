/// Время «как на часах водителя» + смещение его пояса.
///
/// `DateTime.parse('2026-10-03T00:30:00+05:00')` возвращает UTC (2 октября,
/// 19:30) и теряет смещение: время на экране стало бы зависеть от пояса
/// устройства, а сервер считает день по часам водителя. Поэтому держим оба.
class ZonedDateTime {
  const ZonedDateTime(this.wall, this.offset);

  /// Из локального времени устройства (форма добавления поездки).
  factory ZonedDateTime.fromLocal(DateTime local) => ZonedDateTime(
    DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
    ),
    local.timeZoneOffset,
  );

  /// `2026-10-01T08:10:00+05:00`, `...Z`. Без смещения — FormatException.
  factory ZonedDateTime.parse(String iso) {
    final m = _iso.firstMatch(iso);
    if (m == null) throw FormatException('Ожидается время со смещением', iso);
    final zone = m[2]!;
    final offset = zone == 'Z'
        ? Duration.zero
        : Duration(
            hours: int.parse(zone.substring(1, 3)),
            minutes: int.parse(zone.substring(4, 6)),
          );
    return ZonedDateTime(
      DateTime.parse('${m[1]}Z'),
      zone.startsWith('-') ? -offset : offset,
    );
  }

  /// Поля year…minute — то, что видит водитель. Помечено как UTC только чтобы
  /// пояс и переход на летнее время устройства ни на что не влияли.
  final DateTime wall;
  final Duration offset;

  DateTime get instant => wall.subtract(offset);

  /// Дата без времени — день, к которому относится поездка.
  DateTime get day => DateTime(wall.year, wall.month, wall.day);

  String toIso() {
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final zone = '$sign${_pad2(abs.inHours)}:${_pad2(abs.inMinutes % 60)}';
    return '${wall.toIso8601String().substring(0, 19)}$zone';
  }

  static final _iso = RegExp(
    r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2})?)(?:\.\d+)?(Z|[+-]\d{2}:\d{2})$',
  );
}

String _pad2(int n) => n.toString().padLeft(2, '0');

/// `2026-10-01` — ключ дня в URL и API.
String dayKey(DateTime day) =>
    '${day.year}-${_pad2(day.month)}-${_pad2(day.day)}';

/// Обратное к [dayKey]; `null`, если строка — не реальная дата.
DateTime? parseDayKey(String key) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) return null;
  final day = DateTime.parse(key);
  return dayKey(day) == key ? day : null; // 2026-02-30 → null, а не 2 марта
}
