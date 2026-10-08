import 'package:driver_diary/core/time/zoned_date_time.dart';
import 'package:driver_diary/features/trips/presentation/pages/add_trip_page.dart';
import 'package:driver_diary/features/trips/presentation/pages/day_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

String _today() => '/day/${dayKey(DateTime.now())}';

/// Выбранный день живёт в URL (`/day/2026-10-01`), а не в провайдере:
/// работает «назад», deep link и адресная строка в вебе.
///
/// Провайдер, а не глобальная переменная: у каждого ProviderScope (и у
/// каждого теста) свой роутер со своим стеком.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: _today(),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => _today()),
      GoRoute(
        path: '/day/:date',
        redirect: (_, state) =>
            parseDayKey(state.pathParameters['date']!) == null
            ? _today()
            : null,
        builder: (_, state) =>
            DayPage(day: parseDayKey(state.pathParameters['date']!)!),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, state) =>
                AddTripPage(day: parseDayKey(state.pathParameters['date']!)!),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
