# Архитектура: Feature-first + Clean Architecture

Как устроены `lib/` (Flutter-клиент) и `server/` и по каким правилам писать новый код. Живой пример — фича [`trips`](../lib/features/trips/): в ней есть каждый слой, и её можно копировать как шаблон.

Стек клиента: Flutter 3.41 / Dart 3.11, **Riverpod 3** (state + DI), **go_router** (навигация), **dio** (HTTP), **intl**. Кодогенерации (freezed, riverpod_generator, json_serializable) нет специально: меньше магии, проще разобраться. Когда она понадобится, см. [§10](#10-что-добавлять-и-когда).

---

## 0. TL;DR

- **Feature-first** — горизонтальное деление: `lib/features/<фича>/`. Всё, что относится к фиче, лежит в одной папке.
- **Clean Architecture** — вертикальное деление *внутри* фичи: `domain/` ← `data/`, `domain/` ← `presentation/`.
- **Правило зависимостей:** `domain` импортирует только `core/` (ошибки, время) и Dart. Ни Flutter-виджетов, ни dio, ни Riverpod.
- **Фича не импортирует другую фичу.** Общее поднимается в `core/`.
- Связывание (DI) лежит в одном файле `features/<фича>/di.dart`. В тестах подменяется `<x>RepositoryProvider`.
- Из data-слоя наружу выходит только `AppException`, никаких `DioException`.
- **Бизнес-расчёты (сводка) делает сервер.** Клиент их показывает, но не пересчитывает.

---

## 1. Ментальная модель

Есть две оси, и их нельзя путать:

```
                 features/trips        features/<следующая>     ← ось 1: фичи (feature-first)
presentation  │      pages/ widgets/ providers/
              ▼
domain        │      entities/ repositories/ usecases/          ← ось 2: слои (clean)
              ▲
data          │      models/ datasources/ repositories/
──────────────────────────────────────────────────────────
core/   (сеть, ошибки, время, форматирование, тема, общие виджеты)
app/    (точка сборки: MaterialApp, роутер)
```

**Зачем feature-first.** Если раскладывать по типам (`lib/screens`, `lib/models`, `lib/services`), одна фича размазывается по пяти папкам и удалить её целиком невозможно. С feature-first удаление фичи сводится к `rm -rf features/x` плюс одна строка в роутере.

**Зачем clean-слои.** Бэк поменял JSON? Правишь `data/models`, UI не трогаешь. Нужен тест экрана без сервера? Подменяешь репозиторий, потому что UI зависит от *контракта*, а не от dio.

**Правило зависимостей.** Стрелки импорта смотрят внутрь, к `domain`:

```
presentation ──► domain ◄── data
```

Ни presentation, ни data не знают друг о друге, кроме одного места — `di.dart` ([§5](#5-di-через-riverpod)).

---

## 2. Карта папок

```
lib/
├── main.dart                      # ProviderScope(retry: off) + App
├── app/
│   ├── app.dart                   # MaterialApp.router, локаль ru
│   └── router.dart                # /day/:date, /day/:date/new
├── core/
│   ├── error/app_exception.dart   # единый тип ошибки (+ ошибки по полям)
│   ├── network/dio_provider.dart  # Dio: baseUrl (API_URL / свой origin / localhost / 10.0.2.2)
│   ├── storage/prefs_provider.dart # SharedPreferences (override в main)
│   ├── time/zoned_date_time.dart  # время «по часам водителя» + смещение
│   ├── theme/app_theme.dart       # токены макета, ThemeData
│   ├── utils/format.dart          # деньги, время, дата
│   ├── utils/id.dart              # клиентский id = ключ идемпотентности
│   └── widgets/                   # ErrorView, ContentWidth, SlowLoading
└── features/trips/
    ├── di.dart
    ├── domain/
    │   ├── entities/              # Trip (+validate), DaySummary, DayReport (+Freshness), PendingTrip
    │   ├── repositories/trips_repository.dart     # abstract interface
    │   └── usecases/              # WatchDayReport, AddTrip, DiscardPendingTrip
    ├── data/
    │   ├── models/                # TripModel (DTO), daySummaryFromJson
    │   ├── datasources/           # remote (dio), local (кэш дней + очередь)
    │   └── repositories/trips_repository_impl.dart
    └── presentation/
        ├── providers/day_report_provider.dart     # StreamProvider.autoDispose.family
        ├── pages/                 # DayPage, AddTripPage
        └── widgets/               # DayReceipt (чек), DaySwitcher, TripDetailsSheet

test/                              # повторяет структуру lib/
server/                            # см. §13
```

---

## 3. Слои: что где лежит и что кому можно

| Слой | Что лежит | Можно импортировать | Нельзя |
|---|---|---|---|
| `domain/entities` | Чистые классы предметной области и их инварианты (`Trip.validate`) | Dart, `core/time` | Flutter, dio, Riverpod, `data/` |
| `domain/repositories` | `abstract interface class` — контракт | entities | реализацию |
| `domain/usecases` | Один сценарий = один класс с `call()` | entities, контракты, `core/error` | Flutter, dio |
| `data/models` | DTO: форма JSON, `fromJson`/`toJson`, `toEntity()` | entities, `core/time` | presentation |
| `data/datasources` | Сырые запросы: dio, локальная БД | models, dio | entities |
| `data/repositories` | `implements` контракта: зовёт datasource, мапит model → entity, ловит всё → `AppException` | data, domain, `core/` | presentation |
| `presentation/providers` | Состояние экрана (Riverpod) | usecases, entities, `di.dart` | `data/` напрямую |
| `presentation/pages`, `widgets` | UI | providers, entities, `core/` | `data/`, usecases напрямую¹ |

¹ Исключение: команда (`addTripProvider`) вызывается из обработчика формы через `ref.read`. Это usecase, взятый из `di.dart`, а не `data/`.

### Почему entity и model — разные классы

`TripModel` хранит время ISO-строками, как они пришли по проводу, а `Trip` хранит `ZonedDateTime`. Бэк переименует поле? Правишь `fromJson`, UI не меняется. Когда формы совпадают полностью (`DaySummary`), отдельный DTO-класс не заводится: функция `daySummaryFromJson` разбирает JSON прямо в entity.

### Usecase: когда он нужен

`WatchDayReport` — сценарий экрана дня: сначала кэш, затем отправка очереди, затем свежие данные, а без сети откат на кэш с пометкой. `AddTrip` **не пускает невалидную поездку в сеть**. Такая логика не должна жить ни в UI, ни в репозитории.

---

## 4. Поток данных и ошибок

```
DayPage ──ref.watch──► dayReportProvider(day)          StreamProvider.autoDispose.family
                            │
                       WatchDayReport (stale-while-revalidate)
                            ├─ 1. repo.cachedDay(day)   ──► local: SharedPreferences  → yield (cached)
                            ├─ 2. repo.syncPending()    ──► очередь → POST /trips (тот же id)
                            └─ 3. repo.fetchDay(day)    ──► remote: GET /trips + /trips/summary
                                     ├─ ok             → в кэш, yield (fresh)
                                     └─ AppException
                                          retryable && есть кэш → yield (offline)
                                          иначе                 → ошибка на экран
```

**Офлайн.** `AppException.retryable` отличает временные ошибки (нет сети, таймаут, 5xx) от осознанного отказа (400/409). При временной ошибке `addTrip` кладёт поездку в очередь и возвращает `AddOutcome.queued`. Очередь уходит при следующей загрузке любого дня. Если сервер ответил 400/409, поездка помечается ошибкой и больше не отправляется, пока водитель её не удалит. Дублей очередь не создаёт: у поездки клиентский `id`, а сервер идемпотентен по нему.

**Ошибки.** Datasource ничего не ловит. Репозиторий в `_guard` переводит `DioException` в `AppException` с текстом сервера и ошибками по полям (`{fields: {amount: …}}`), а любой сбой разбора ответа — в «Неожиданный ответ сервера». Форма раскладывает `fields` по своим полям, экран показывает `ErrorView` с «Повторить».

Отсюда правило: **в presentation никогда не пишется `on DioException`.** Если такая строка там появилась, значит протёк слой.

---

## 5. DI через Riverpod

Отдельного DI-контейнера нет: Riverpod-провайдеры уже им являются. [`di.dart`](../lib/features/trips/di.dart):

```dart
final tripsRemoteDataSourceProvider = Provider(
  (ref) => TripsRemoteDataSource(ref.watch(dioProvider)),
);

final tripsRepositoryProvider = Provider<TripsRepository>(   // ← тип контракта!
  (ref) => TripsRepositoryImpl(ref.watch(tripsRemoteDataSourceProvider)),
);

final getDayReportProvider = Provider((ref) => GetDayReport(ref.watch(tripsRepositoryProvider)));
final addTripProvider      = Provider((ref) => AddTrip(ref.watch(tripsRepositoryProvider)));
```

- `tripsRepositoryProvider` объявлен с типом **контракта**. Без этого override в тестах не примет фейк.
- В тестах подменяется одна точка:

```dart
ProviderScope(
  overrides: [tripsRepositoryProvider.overrideWithValue(FakeTripsRepository())],
  child: const App(),
)
```

---

## 6. Состояние (Riverpod 3)

| Нужно | Чем |
|---|---|
| Загрузить данные и показать | `FutureProvider` (`.autoDispose`, `.family` по параметру) |
| Данные + действия | `AsyncNotifierProvider` с методами |
| Синхронное локальное состояние | `NotifierProvider`; состояние формы — обычный `State` |
| Сервис / репозиторий / usecase | `Provider` |

Правила:
- `ref.watch` используется в `build` и внутри провайдеров, `ref.read` — в колбэках (`onPressed`), и никогда в `build`.
- Перезагрузить данные: `ref.invalidate(p)`. Перезагрузить и дождаться результата (pull-to-refresh): `await ref.refresh(p.future)`.
- После `await` виджет мог размонтироваться, и тогда `ref` становится недоступен. Если после запроса нужно инвалидировать провайдер, возьми `ProviderScope.containerOf(context)` **до** `await` (см. `AddTripPage._submit`).
- **Гоча Riverpod 3:** упавший провайдер по умолчанию **сам повторяет запрос**. Здесь это отключено глобально (`ProviderScope(retry: (_, _) => null)` в `main.dart`): у ошибки есть кнопка «Повторить», а авторетраи только сбивают с толку.
- **Гоча Riverpod 3:** провайдеры без кодогенерации **не** autoDispose по умолчанию. `dayReportProvider` объявлен `.autoDispose`: ушёл с дня — подписка закрыта, вернулся — свежий запрос (а кэш с диска покажется мгновенно).
- `report.when(skipLoadingOnReload: true, …)` — при обновлении экран не мигает спиннером.
- **Гоча StreamProvider:** `provider.future` завершается на **первом** значении, то есть на кэше. Pull-to-refresh поэтому ждёт через `listenManual` первого состояния, которое не `cached` (см. `_refresh` в `day_page.dart`).
- Синхронные зависимости, которые инициализируются асинхронно (`SharedPreferences`), создаются в `main()` до `runApp` и подставляются через `overrideWithValue`. Провайдер по умолчанию бросает `UnimplementedError`.

---

## 7. Навигация (go_router)

Маршруты лежат в [`app/router.dart`](../lib/app/router.dart), роутер создаётся в `routerProvider`, а не в глобальной переменной: у каждого `ProviderScope` (и у каждого теста) свой стек.

- **Выбранный день живёт в URL** (`/day/2026-10-01`), а не в провайдере. Тогда работают «назад», deep links и адресная строка в вебе. Невалидная дата в URL редиректит на сегодня.
- Переключение дня: `context.go('/day/…')`. Форма: вложенный маршрут `/day/:date/new`, закрывается через `context.pop()`.
- Соседний день считается как `DateTime(y, m, d ± 1)`, а **не** `add(Duration(days: 1))`: в день перевода часов сутки длятся 23 или 25 часов.

---

## 8. Время и пояса

Поездки приходят как `2026-10-03T00:30:00+05:00`. Подводные камни:

- `DateTime.parse` переводит строку в UTC и **теряет смещение**: получается 2 октября, 19:30. День и время на экране зависели бы от пояса телефона.
- Поэтому в `core/time` есть `ZonedDateTime`: `wall` (время на часах водителя) + `offset`. Показывается `wall`, длительность и сравнения считаются по `instant`.
- Новая поездка из формы создаётся через `ZonedDateTime.fromLocal`: берётся время устройства с его смещением.
- Сервер устроен так же: хранит исходные строки, а день поездки определяет по `start.substring(0, 10)`.

---

## 9. Границы между фичами

Как cross-imports в FSD: **`features/a` не импортирует `features/b`.**

| Ситуация | Решение |
|---|---|
| Общий UI без бизнес-смысла (кнопка, `ErrorView`) | `core/widgets/` |
| Общая сущность | `core/domain/entities/` |
| Экран A открывает экран B | Только через роутер: `context.go('/b/1')` |
| Фича A реагирует на событие фичи B | Общий провайдер в `core/`, обе фичи его `watch`'ат |

Соответствие FSD: `app` → `lib/app/`, `shared` → `lib/core/`, `pages`/`features`/`entities` → `features/*/presentation`/`domain`, сегмент `api` → `data/datasources`, `ui` → `presentation/pages|widgets`.

---

## 10. Что добавлять и когда

| Когда | Что |
|---|---|
| Моделей больше 5–10 и надоело писать `fromJson`/`==`/`copyWith` | `freezed` + `json_serializable` |
| История на месяцы, поиск, фильтры | заменить SharedPreferences в `TripsLocalDataSource` на drift/sqlite (контракт не меняется) |
| Отправка очереди в фоне, без открытия приложения | `workmanager` (Android) / BGTaskScheduler (iOS) вызывает `syncPending` |
| Авторизация | Interceptor в `core/network/` |
| Тёмная тема | второй набор `AppColors` + `darkTheme` |
| Несколько окружений | `--dart-define-from-file=env/dev.json` |

---

## 11. Чек-лист: новая фича

1. `domain/entities/` — entity (+ инварианты, если есть).
2. `domain/repositories/` — `abstract interface class`.
3. `domain/usecases/` — классы с `call()`.
4. `data/models/` — `fromJson` + `toEntity()`.
5. `data/datasources/` — запросы.
6. `data/repositories/` — `implements`, `_guard` → `AppException`.
7. `di.dart` — datasource → repository (**тип контракта**) → usecases.
8. `presentation/providers/` — `FutureProvider.autoDispose` / `AsyncNotifierProvider`.
9. `presentation/pages/` — `ConsumerWidget`, `.when(data/error/loading)`.
10. Маршрут в `lib/app/router.dart`.
11. Тесты с фейковым репозиторием в `test/features/<фича>/`.
12. `flutter analyze && flutter test`.

---

## 12. Тесты клиента

- **Widget-тесты экрана** с `overrideWithValue` на репозиторий ([day_page_test.dart](../test/features/trips/day_page_test.dart)): чек, детали, переключение дня, долгая загрузка, офлайн-плашка, неотправленные поездки, валидация и автокомиссия в форме. Сети при этом нет.
- **Домен** ([domain_test.dart](../test/features/trips/domain_test.dart)): `Trip.validate`, `AddTrip`, все ветки `WatchDayReport` (кэш → свежие, офлайн, нет кэша).
- **Репозиторий** ([trips_repository_impl_test.dart](../test/features/trips/trips_repository_impl_test.dart)): кэш, очередь, синхронизация, отказ сервера, параллельные синхронизации. Используются настоящий `SharedPreferences` (mock-хранилище) и фейковый remote с идемпотентным «сервером».
- **Время** ([zoned_date_time_test.dart](../test/core/zoned_date_time_test.dart)): день по часам водителя, round-trip ISO, отказ от времени без смещения.
- Фейки пишутся руками (`implements TripsRepository`), без mock-библиотек.

---

## 13. Сервер

Плоская структура без слоёв: в нём четыре файла, и Clean Architecture там была бы церемонией.

| Файл | Ответственность |
|---|---|
| [trip.dart](../server/lib/src/trip.dart) | Модель, парсинг + валидация (все ошибки сразу), `sameAs`, `overlaps` |
| [summary.dart](../server/lib/src/summary.dart) | `DaySummary.of(date, trips)` — чистая функция, легко тестируется |
| [trip_store.dart](../server/lib/src/trip_store.dart) | Хранилище: дубли, пересечения, очередь записей, атомарная запись файла |
| [api.dart](../server/lib/src/api.dart) | Маршруты, исключения → HTTP-коды (400/409/500), CORS |

Подробности про дубли описаны в [README](../README.md#защита-от-дублей).
