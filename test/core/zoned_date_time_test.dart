import 'package:driver_diary/core/time/zoned_date_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('время и день — по часам водителя, независимо от пояса устройства', () {
    // в UTC это 2 октября, 19:30
    final t = ZonedDateTime.parse('2026-10-03T00:30:00+05:00');

    expect((t.wall.hour, t.wall.minute), (0, 30));
    expect(t.day, DateTime(2026, 10, 3));
    expect(t.instant, DateTime.utc(2026, 10, 2, 19, 30));
  });

  test('toIso — обратно к той же строке', () {
    for (final s in [
      '2026-10-01T08:10:00+05:00',
      '2026-10-01T08:10:00-03:30',
      '2026-10-01T08:10:00+00:00',
    ]) {
      expect(ZonedDateTime.parse(s).toIso(), s);
    }
    expect(
      ZonedDateTime.parse('2026-10-01T08:10:00Z').toIso(),
      '2026-10-01T08:10:00+00:00',
    );
  });

  test('без смещения — ошибка, а не молчаливый пояс устройства', () {
    expect(
      () => ZonedDateTime.parse('2026-10-01T08:10:00'),
      throwsFormatException,
    );
  });

  test('fromLocal сохраняет смещение устройства', () {
    final local = DateTime(2026, 10, 1, 8, 10);
    final t = ZonedDateTime.fromLocal(local);

    expect(t.instant, local.toUtc());
    expect(t.offset, local.timeZoneOffset);
  });

  test('dayKey / parseDayKey', () {
    expect(dayKey(DateTime(2026, 1, 5)), '2026-01-05');
    expect(parseDayKey('2026-10-01'), DateTime(2026, 10, 1));
    expect(parseDayKey('2026-02-30'), isNull);
    expect(parseDayKey('вчера'), isNull);
  });
}
