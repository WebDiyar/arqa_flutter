import 'package:driver_diary/core/network/dio_provider.dart';
import 'package:driver_diary/core/storage/prefs_provider.dart';
import 'package:driver_diary/features/trips/data/datasources/trips_local_data_source.dart';
import 'package:driver_diary/features/trips/data/datasources/trips_remote_data_source.dart';
import 'package:driver_diary/features/trips/data/repositories/trips_repository_impl.dart';
import 'package:driver_diary/features/trips/domain/repositories/trips_repository.dart';
import 'package:driver_diary/features/trips/domain/usecases/add_trip.dart';
import 'package:driver_diary/features/trips/domain/usecases/discard_pending_trip.dart';
import 'package:driver_diary/features/trips/domain/usecases/watch_day_report.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Composition root фичи: единственное место, где data встречается с domain.
// В тестах подменяется tripsRepositoryProvider.

final tripsRemoteDataSourceProvider = Provider(
  (ref) => TripsRemoteDataSource(ref.watch(dioProvider)),
);

final tripsLocalDataSourceProvider = Provider(
  (ref) => TripsLocalDataSource(ref.watch(prefsProvider)),
);

final tripsRepositoryProvider = Provider<TripsRepository>(
  (ref) => TripsRepositoryImpl(
    ref.watch(tripsRemoteDataSourceProvider),
    ref.watch(tripsLocalDataSourceProvider),
  ),
);

final watchDayReportProvider = Provider(
  (ref) => WatchDayReport(ref.watch(tripsRepositoryProvider)),
);

final addTripProvider = Provider(
  (ref) => AddTrip(ref.watch(tripsRepositoryProvider)),
);

final discardPendingTripProvider = Provider(
  (ref) => DiscardPendingTrip(ref.watch(tripsRepositoryProvider)),
);
