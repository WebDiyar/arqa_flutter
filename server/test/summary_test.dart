import 'package:driver_diary_server/src/summary.dart';
import 'package:driver_diary_server/src/trip.dart';
import 'package:test/test.dart';

Trip trip(String id, int amount, Payment payment, int commission) => Trip(
  id: id,
  start: '2026-10-01T08:00:00+05:00',
  end: '2026-10-01T08:30:00+05:00',
  amount: amount,
  payment: payment,
  commission: commission,
);

void main() {
  test('сводка по примеру из задания', () {
    final s = DaySummary.of('2026-10-01', [
      trip('t1', 2400, Payment.card, 360),
      trip('t2', 1500, Payment.cash, 225),
    ]);

    expect(s.tripsCount, 2);
    expect(s.revenue, 3900);
    expect(s.commission, 585);
    expect(s.net, 3315);
    expect((s.cash.count, s.cash.amount), (1, 1500));
    expect((s.card.count, s.card.amount), (1, 2400));
  });

  test('разбивка складывает несколько поездок одного типа', () {
    final s = DaySummary.of('2026-10-01', [
      trip('a', 1000, Payment.cash, 100),
      trip('b', 2000, Payment.cash, 300),
      trip('c', 500, Payment.card, 0),
    ]);

    expect((s.cash.count, s.cash.amount), (2, 3000));
    expect((s.card.count, s.card.amount), (1, 500));
    expect(s.net, 3500 - 400);
    expect(s.cash.amount + s.card.amount, s.revenue);
  });

  test('пустой день — нули, а не ошибка', () {
    final s = DaySummary.of('2026-10-05', []);

    expect(s.toJson(), {
      'date': '2026-10-05',
      'tripsCount': 0,
      'revenue': 0,
      'commission': 0,
      'net': 0,
      'cash': {'count': 0, 'amount': 0},
      'card': {'count': 0, 'amount': 0},
    });
  });
}
