import 'dart:async';

import 'package:driver_diary/app/app.dart';
import 'package:driver_diary/core/utils/format.dart';
import 'package:driver_diary/features/trips/di.dart';
import 'package:driver_diary/features/trips/domain/entities/pending_trip.dart';
import 'package:driver_diary/features/trips/domain/entities/trip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_trips_repository.dart';

void main() {
  late FakeTripsRepository repo;

  setUp(() => repo = FakeTripsRepository());

  Future<void> pumpApp(WidgetTester tester, {bool settle = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tripsRepositoryProvider.overrideWithValue(repo)],
        retry: (_, _) => null,
        child: const App(),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  double hintOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(
          of: find.textContaining('просыпается'),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  testWidgets('чек: поездки и сводка за день', (tester) async {
    await pumpApp(tester);

    expect(find.text('Сегодня'), findsOneWidget);
    expect(find.text(formatMoney(3315)), findsOneWidget); // на руки
    expect(find.text('08:10–08:32 карта'), findsOneWidget);
    expect(find.text('09:05–09:20 нал.'), findsOneWidget);
    expect(find.text('−${formatMoney(585)}'), findsOneWidget);
    expect(
      find.text('${formatNumber(1500)} / ${formatNumber(2400)}'),
      findsOneWidget,
    );
  });

  testWidgets('тап по поездке — детали с «на руки» за поездку', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('08:10–08:32 карта'));
    await tester.pumpAndSettle();

    expect(find.textContaining('22 мин'), findsOneWidget);
    expect(find.text(formatMoney(2040)), findsOneWidget); // 2400 − 360
  });

  testWidgets('переключение на предыдущий день', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Предыдущий день'));
    await tester.pumpAndSettle();

    final today = DateUtils.dateOnly(DateTime.now());
    expect(
      repo.requestedDays.last,
      DateTime(today.year, today.month, today.day - 1),
    );
    expect(find.text('Выбрать дату'), findsOneWidget);
  });

  testWidgets('долгая загрузка — объясняем, что сервер просыпается', (
    tester,
  ) async {
    repo.gate = Completer();
    await pumpApp(tester, settle: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(hintOpacity(tester), 0, reason: 'первые секунды — просто спиннер');

    await tester.pump(const Duration(seconds: 4));
    expect(hintOpacity(tester), 1);

    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text(formatMoney(3315)), findsOneWidget);
  });

  testWidgets('нет связи — чек из кэша и плашка, а не экран ошибки', (
    tester,
  ) async {
    repo
      ..cached = sampleReport
      ..server = offline;
    await pumpApp(tester);

    expect(find.textContaining('Нет связи с сервером'), findsOneWidget);
    expect(find.text(formatMoney(3315)), findsOneWidget);
  });

  testWidgets('неотправленная поездка видна в чеке и удаляется', (
    tester,
  ) async {
    repo.pending = [
      PendingTrip(
        sampleTrip('q1', '10:00', '10:20', 1200, PaymentMethod.card, 180),
      ),
    ];
    await pumpApp(tester);

    expect(find.text('Не отправлено (1)'), findsOneWidget);
    await tester.tap(find.text('⏳ 10:00–10:20 карта'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить с устройства'));
    await tester.pumpAndSettle();

    expect(repo.pending, isEmpty);
    expect(find.text('Не отправлено (1)'), findsNothing);
  });

  group('форма', () {
    Future<void> openForm(WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Поездка'));
      await tester.pumpAndSettle();
    }

    Future<void> pickSameTimes(WidgetTester tester) async {
      final ok = MaterialLocalizations.of(
        tester.element(find.text('Сохранить')),
      ).okButtonLabel;
      for (final field in ['Начало', 'Окончание']) {
        await tester.tap(find.widgetWithText(InputDecorator, field));
        await tester.pumpAndSettle();
        await tester.tap(find.text(ok));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('не отправляет пустую и некорректную поездку', (tester) async {
      await openForm(tester);

      await tester.tap(find.text('Сохранить'));
      await tester.pump();
      expect(find.text('Укажите время начала'), findsOneWidget);
      expect(find.text('Укажите сумму'), findsOneWidget);

      await pickSameTimes(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Сумма'), '1000');
      await tester.tap(find.text('Сохранить'));
      await tester.pump();

      expect(find.text('Окончание должно быть позже начала'), findsOneWidget);
      expect(repo.added, isEmpty);
    });

    testWidgets('комиссия подставляется (15%), пока её не трогали', (
      tester,
    ) async {
      await openForm(tester);
      final amount = find.widgetWithText(TextField, 'Сумма');
      final commission = find.widgetWithText(TextField, 'Комиссия');
      String commissionText() =>
          tester.widget<TextField>(commission).controller!.text;

      await tester.enterText(amount, '2400');
      await tester.pump();
      expect(commissionText(), '360');

      await tester.enterText(commission, '100');
      await tester.enterText(amount, '5000');
      await tester.pump();
      expect(commissionText(), '100');
    });
  });
}
