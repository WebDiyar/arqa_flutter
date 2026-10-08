import 'dart:io';

import 'package:driver_diary_server/src/api.dart';
import 'package:driver_diary_server/src/trip_store.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

Future<void> main() async {
  final env = Platform.environment;
  final port = int.parse(env['PORT'] ?? '8080');
  final file = File(env['DATA_FILE'] ?? 'data/trips.json');
  final webDir = env['WEB_DIR'];

  final store = await TripStore.open(file, seed: File('data/seed.json'));

  // На хостинге тот же процесс раздаёт собранный Flutter-веб: один адрес,
  // клиент ходит в API на свой же origin, CORS и API_URL не нужны.
  // Cascade: сначала API, на 404 — статика.
  var app = buildApi(store);
  if (webDir != null && Directory(webDir).existsSync()) {
    app = Cascade()
        .add(app)
        .add(createStaticHandler(webDir, defaultDocument: 'index.html'))
        .handler;
  }

  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(app);

  final server = await _serve(handler, port);
  stdout.writeln(
    'API: http://localhost:${server.port}  (данные: ${file.path}'
    '${webDir != null ? ', веб: $webDir' : ''})',
  );
}

/// anyIPv6 — dual-stack: localhost, 10.0.2.2 из эмулятора Android и телефон
/// в той же Wi-Fi сети. В контейнере без IPv6 — откат на IPv4.
Future<HttpServer> _serve(Handler handler, int port) async {
  try {
    return await io.serve(handler, InternetAddress.anyIPv6, port);
  } on SocketException {
    return io.serve(handler, InternetAddress.anyIPv4, port);
  }
}
