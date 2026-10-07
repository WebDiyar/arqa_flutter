# my_app

Flutter-приложение на **Feature-first + Clean Architecture**: Riverpod 3 · go_router · dio.
Пример фичи — список постов с [JSONPlaceholder](https://jsonplaceholder.typicode.com).

📐 Архитектура и правила кода: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

---

## Запуск на MacBook

### 1. Что должно быть установлено

| Что | Зачем | Проверка |
|---|---|---|
| Flutter 3.41+ | SDK | `flutter --version` |
| Xcode 26+ | запуск на macOS и iPhone-симуляторе | `xcodebuild -version` |
| CocoaPods | нативные зависимости iOS/macOS | `pod --version` (`brew install cocoapods`) |
| Google Chrome | запуск в вебе | — |
| Android Studio | *только для Android*, сейчас не установлен | `flutter doctor` |

Проверить всё одной командой:

```bash
flutter doctor
```

Если Xcode установлен только что:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

### 2. Первый запуск

```bash
cd ~/Desktop/flutter
flutter pub get          # поставить зависимости
flutter run -d macos     # запустить как приложение для Mac
```

### 3. Куда ещё можно запустить

```bash
flutter devices                                   # список доступных устройств

flutter run -d macos                              # приложение для Mac (самое быстрое)
flutter run -d chrome                             # в браузере

open -a Simulator                                 # открыть iPhone-симулятор…
flutter run -d iphone                             # …и запустить на нём
                                                  # (или -d "iPhone 17 Pro")
```

### 4. Во время работы `flutter run`

| Клавиша | Действие |
|---|---|
| `r` | hot reload: подхватить изменения, состояние сохраняется |
| `R` | hot restart: перезапуск, состояние сбрасывается |
| `d` | открыть DevTools |
| `q` | выйти |

### 5. Через VS Code

1. Открыть папку проекта. VS Code предложит поставить рекомендованные расширения (**Flutter**, **Dart**), согласиться.
2. Устройство выбирается внизу справа в статус-баре (macOS / iPhone / Chrome).
3. **F5** запускает в debug с брейкпоинтами. При сохранении файла срабатывает hot reload.

Конфиги лежат в [.vscode/](.vscode/): `settings.json` (форматирование при сохранении, сортировка импортов, `.md` открываются в превью), `launch.json` (debug/release), `extensions.json`.

---

## Команды

```bash
flutter pub get                  # зависимости
flutter pub add <пакет>          # добавить пакет
flutter pub outdated             # что можно обновить

flutter analyze                  # линтер
dart format lib test             # форматирование
dart fix --apply                 # автофиксы линтера
flutter test                     # тесты

flutter clean && flutter pub get # «всё сломалось, начать с чистого»

flutter build macos              # .app  → build/macos/Build/Products/Release/
flutter build ios                # для App Store (нужен Apple Developer аккаунт)
flutter build web                # → build/web/
```

Перед коммитом:

```bash
flutter analyze && flutter test
```

---

## Свой бэкенд

По умолчанию запросы идут на `https://jsonplaceholder.typicode.com`. Подставить свой сервер:

```bash
flutter run -d macos --dart-define=API_URL=http://localhost:3000
```

Адрес читается в [lib/core/network/dio_provider.dart](lib/core/network/dio_provider.dart).

> На macOS приложению нужен доступ в сеть. Он уже включён (`com.apple.security.network.client` в `macos/Runner/*.entitlements`). Если сеть отвалилась после пересоздания платформы, проверь в первую очередь это.

---

## Структура

```
lib/
├── main.dart
├── app/            # MaterialApp, роутер, тема
├── core/           # сеть, ошибки, общие виджеты
└── features/
    └── posts/
        ├── di.dart          # связывание зависимостей фичи
        ├── domain/          # entities, контракты репозиториев, usecases
        ├── data/            # models (JSON), datasources (dio), реализации репозиториев
        └── presentation/    # providers, pages, widgets
```

Новая фича делается по чек-листу из [docs/ARCHITECTURE.md §11](docs/ARCHITECTURE.md#11-чек-лист-новая-фича).

---

## Частые проблемы

| Симптом | Что делать |
|---|---|
| `CocoaPods not installed` | `brew install cocoapods` |
| Ошибки Pod'ов при сборке iOS/macOS | `cd ios && pod install --repo-update && cd ..` (то же для `macos`) |
| На macOS «Нет соединения с интернетом» | проверить entitlements (см. выше) |
| Симулятор не виден в `flutter devices` | сначала `open -a Simulator` |
| Что-то странное после обновления пакетов | `flutter clean && flutter pub get` |
| Нужен Android | установить Android Studio → `flutter doctor --android-licenses` |
