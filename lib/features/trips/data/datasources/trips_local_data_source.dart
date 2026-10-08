import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Кэш отчётов по дням и очередь неотправленных поездок.
/// Хранит сырой JSON — тот же, что ходит по сети; в entity мапит репозиторий.
// ponytail: SharedPreferences держит всё в памяти и пишет целиком — для
// десятков дней и пары поездок в очереди это нормально. Месяцы истории —
// sqlite/drift.
class TripsLocalDataSource {
  const TripsLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  static const _outboxKey = 'trips.outbox';
  static String _dayKey(String date) => 'trips.day.$date';

  /// `{syncedAt, trips: [...], summary: {...}}` или null.
  Map<String, dynamic>? readDay(String date) {
    final raw = _prefs.getString(_dayKey(date));
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> writeDay(String date, Map<String, Object> json) =>
      _prefs.setString(_dayKey(date), jsonEncode(json));

  /// Элементы очереди: `{trip: {...}, error: String?}`.
  List<Map<String, dynamic>> readOutbox() {
    final raw = _prefs.getString(_outboxKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> writeOutbox(List<Map<String, dynamic>> items) =>
      _prefs.setString(_outboxKey, jsonEncode(items));
}
