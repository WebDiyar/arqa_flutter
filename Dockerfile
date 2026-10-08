# Один образ: Flutter-веб + Dart-сервер, который его раздаёт и отдаёт API.
# Локально: docker build -t driver-diary . && docker run -p 8080:8080 driver-diary

# 1. Веб-клиент
FROM ghcr.io/cirruslabs/flutter:3.41.9 AS web
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

# 2. Сервер → нативный бинарник
FROM dart:3.11 AS server
WORKDIR /server
COPY server/pubspec.yaml server/pubspec.lock ./
RUN dart pub get
COPY server/ .
RUN dart compile exe bin/server.dart -o bin/server

# 3. Минимальный образ: рантайм dart-образа + бинарник + данные + веб
FROM scratch
COPY --from=server /runtime/ /
COPY --from=server /server/bin/server /app/bin/server
COPY --from=server /server/data/seed.json /app/data/seed.json
COPY --from=web /app/build/web /app/web
WORKDIR /app
ENV WEB_DIR=web
EXPOSE 8080
CMD ["/app/bin/server"]
