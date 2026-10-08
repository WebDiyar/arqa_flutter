import 'dart:math';

final _random = Random.secure();

/// 128-битный случайный id в hex. Генерируется на клиенте до отправки —
/// он же ключ идемпотентности: повторный POST с ним не создаёт дубль.
String newId() => List.generate(
  16,
  (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
