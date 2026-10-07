# Архитектура: Feature-first + Clean Architecture

Как устроен `lib/` в этом проекте и по каким правилам писать новый код. Живой пример — фича [`posts`](../lib/features/posts/): в ней есть каждый слой, и её можно копировать как шаблон.

Стек: Flutter 3.41 / Dart 3.11, **Riverpod 3** (state + DI), **go_router** (навигация), **dio** (HTTP). Кодогенерации (freezed, riverpod_generator, json_serializable) нет специально: меньше магии, проще разобраться. Когда она понадобится, см. [§10](#10-что-добавлять-и-когда).

---

## 0. TL;DR

- **Feature-first** — горизонтальное деление: `lib/features/<фича>/`. Всё, что относится к фиче, лежит в одной папке.
- **Clean Architecture** — вертикальное деление *внутри* фичи: `domain/` ← `data/`, `domain/` ← `presentation/`.
- **Правило зависимостей:** `domain` не импортирует ничего, кроме `core/error` и самого Dart. Ни Flutter, ни dio, ни Riverpod.
- **Фича не импортирует другую фичу.** Общее поднимается в `core/`.
- Связывание (DI) лежит в одном файле `features/<фича>/di.dart`. В тестах подменяется `<x>RepositoryProvider`.
- Из data-слоя наружу выходит только `AppException`, никаких `DioException`.

---

## 1. Ментальная модель

Есть две оси, и их нельзя путать:

```
                 features/auth    features/posts    features/cart     ← ось 1: фичи (feature-first)
presentation  │      ...              pages/           ...
              │                       providers/
              ▼                       widgets/
domain        │      ...              entities/        ...            ← ось 2: слои (clean)
              ▲                       repositories/  (контракт)
              │                       usecases/
data          │      ...              models/          ...
                                      datasources/
                                      repositories/  (реализация)
─────────────────────────────────────────────────────────────────
core/   (сеть, ошибки, общие виджеты)   app/   (точка сборки: роутер, тема)
```

**Зачем feature-first.** Если раскладывать по типам (`lib/screens`, `lib/models`, `lib/services`), одна фича размазывается по пяти папкам и удалить её целиком невозможно. С feature-first удаление фичи сводится к `rm -rf features/x` плюс одна строка в роутере.

**Зачем clean-слои.** Бэк поменял JSON? Правишь `data/models`, UI не трогаешь. Переехали с REST на GraphQL? Меняешь `data/datasources`, а domain и UI остаются как были. Нужен тест экрана без сети? Подменяешь репозиторий, потому что UI зависит от *контракта*, а не от dio.

**Правило зависимостей.** Стрелки импорта смотрят внутрь, к `domain`:

```
presentation ──► domain ◄── data
```

`domain` — центр, он ничего не знает о внешнем мире. `data` реализует контракты domain. `presentation` пользуется domain. Ни presentation, ни data не знают друг о друге, кроме одного места — `di.dart` ([§5](#5-di-через-riverpod)).

---

## 2. Карта папок

```
lib/
├── main.dart                     # runApp(ProviderScope(App())) — и всё
├── app/                          # сборка приложения
│   ├── app.dart                  # MaterialApp.router, тема
│   └── router.dart               # go_router: все маршруты всех фич
├── core/                         # общее, без бизнес-логики конкретной фичи
│   ├── error/app_exception.dart  # единый тип ошибки
│   ├── network/dio_provider.dart # настроенный Dio (baseUrl, таймауты, логи)
│   └── widgets/error_view.dart   # переиспользуемый UI
└── features/
    └── posts/
        ├── di.dart               # composition root фичи
        ├── domain/
        │   ├── entities/post.dart
        │   ├── repositories/posts_repository.dart   # abstract interface
        │   └── usecases/get_posts.dart
        ├── data/
        │   ├── models/post_model.dart               # DTO + fromJson + toEntity
        │   ├── datasources/posts_remote_data_source.dart
        │   └── repositories/posts_repository_impl.dart
        └── presentation/
            ├── providers/posts_provider.dart        # состояние экрана
            ├── pages/posts_page.dart
            ├── pages/post_details_page.dart
            └── widgets/post_tile.dart

test/                             # повторяет структуру lib/
└── features/posts/posts_test.dart
```

---

## 3. Слои: что где лежит и что кому можно

| Слой | Что лежит | Можно импортировать | Нельзя |
|---|---|---|---|
| `domain/entities` | Чистые классы предметной области (`Post`) | Dart | Flutter, dio, Riverpod, `data/` |
| `domain/repositories` | `abstract interface class` — контракт | entities | реализацию |
| `domain/usecases` | Один сценарий = один класс с `call()` | entities, контракты репозиториев, `core/error` | Flutter, dio |
| `data/models` | DTO: форма JSON, `fromJson`/`toJson`, `toEntity()` | entities | presentation |
| `data/datasources` | Сырые запросы: dio, локальная БД, SharedPreferences | models, dio | entities (работают с моделями) |
| `data/repositories` | `implements` контракта: зовёт datasource, мапит model → entity, ловит `DioException` → `AppException` | всё из data, domain, `core/error` | presentation |
| `presentation/providers` | Состояние экрана (Riverpod) | usecases, entities, `di.dart` | `data/` напрямую |
| `presentation/pages`, `widgets` | UI | providers, entities, `core/widgets` | `data/`, usecases напрямую |

### Почему entity и model — разные классы

Сейчас поля `Post` и `PostModel` совпадают, и выглядит это как дублирование. Окупается оно в первый же день, когда бэк:
- переименует поле (`userId` → `author_id`). Правишь `fromJson`, UI не меняется;
- начнёт присылать дату строкой. Парсишь её в `DateTime` в модели, entity сразу получает `DateTime`;
- добавит 30 служебных полей. В модели они есть, в entity их нет.

Entity описывает то, *как приложение думает о данных*. Model описывает то, *что прислал сервер*.

### Usecase: когда он нужен

`GetPosts` сейчас просто проксирует вызов в репозиторий. Он всё равно есть, ради единообразия: каждая операция идёт по одному и тому же пути. Настоящую работу usecase делает, когда в нём появляется логика: собрать данные из двух репозиториев, отфильтровать, проверить права, посчитать что-то. Такой код не должен жить ни в UI, ни в репозитории.

> Прагматичное правило: если в маленькой фиче все usecase'ы оказываются проксями, их можно опустить, и тогда провайдер зовёт репозиторий напрямую. Решение принимается **на всю фичу целиком**, смешивать подходы внутри одной фичи нельзя.

---

## 4. Поток данных и ошибок

```
PostsPage ──ref.watch──► postsProvider (FutureProvider)
                              │ ref.watch(getPostsProvider)()
                              ▼
                          GetPosts.call()
                              │ PostsRepository (контракт)
                              ▼
                     PostsRepositoryImpl.getPosts()
                              │ try { ... } on DioException → throw AppException
                              ▼
                     PostsRemoteDataSource.getPosts()
                              │ dio.get('/posts') → List<PostModel>
                              ▼
                          HTTP / JSON
```

Обратно возвращается `List<Post>` (entities). Модели не выходят за пределы `data/`.

**Ошибки.** Datasource ничего не ловит и отдаёт `DioException` как есть. Репозиторий переводит её в `AppException` с понятным текстом ([`core/error/app_exception.dart`](../lib/core/error/app_exception.dart)). `FutureProvider` превращает исключение в `AsyncValue.error`, а UI показывает `ErrorView` с кнопкой «Повторить» (`ref.invalidate`).

Отсюда правило: **в presentation никогда не пишется `on DioException`.** Если такая строка там появилась, значит протёк слой.

---

## 5. DI через Riverpod

Отдельного DI-контейнера (get_it и т.п.) нет: Riverpod-провайдеры уже им являются. Каждая фича связывает свои зависимости в одном файле [`di.dart`](../lib/features/posts/di.dart):

```dart
final postsRemoteDataSourceProvider = Provider(
  (ref) => PostsRemoteDataSource(ref.watch(dioProvider)),
);

final postsRepositoryProvider = Provider<PostsRepository>(   // ← тип контракта!
  (ref) => PostsRepositoryImpl(ref.watch(postsRemoteDataSourceProvider)),
);

final getPostsProvider = Provider(
  (ref) => GetPosts(ref.watch(postsRepositoryProvider)),
);
```

- `di.dart` — единственный файл фичи, который знает и про `data`, и про `domain`.
- `postsRepositoryProvider` объявлен с типом **контракта** `Provider<PostsRepository>`. Без этого override в тестах не примет фейк.
- В тестах подменяется одна точка:

```dart
ProviderScope(
  overrides: [postsRepositoryProvider.overrideWithValue(FakePostsRepository())],
  child: const App(),
)
```

---

## 6. Состояние (Riverpod 3)

| Нужно | Чем |
|---|---|
| Загрузить данные и показать | `FutureProvider` (как `postsProvider`) |
| Данные + действия (добавить, удалить, лайкнуть) | `AsyncNotifierProvider` с методами |
| Синхронное локальное состояние (фильтр, вкладка) | `NotifierProvider` |
| Одно значение-зависимость (сервис, репозиторий) | `Provider` |
| Параметр (пост по id) | `.family` |

Правила:
- `ref.watch` используется в `build` и внутри провайдеров. `ref.read` используется в колбэках (`onPressed`), и никогда в `build`.
- Перезагрузить данные: `ref.invalidate(p)`. Перезагрузить и дождаться результата (pull-to-refresh): `await ref.refresh(p.future)`.
- **Гоча Riverpod 3:** упавший провайдер по умолчанию **сам повторяет запрос** с нарастающей задержкой. В логах при выключенной сети это выглядит как серия запросов, и это нормальное поведение. Отключить можно через `retry: (_, _) => null` у провайдера или `ProviderScope(retry: ...)`.
- **Гоча Riverpod 3:** провайдеры, объявленные без кодогенерации, **не** autoDispose по умолчанию: данные кэшируются на всё время жизни приложения. Для экранных данных, которые нужно сбрасывать при уходе с экрана, используй `FutureProvider.autoDispose`.

---

## 7. Навигация (go_router)

Все маршруты описаны в [`app/router.dart`](../lib/app/router.dart), потому что роутер — это сборка приложения, а не часть фичи. Фича экспортирует только страницы.

- Параметры передаются **через путь** (`/posts/:id`), а не через `extra`. Тогда работают deep links, веб-URL и восстановление состояния.
- Страница по `id` берёт данные из провайдера сама (см. `PostDetailsPage`) и не ждёт объект в конструкторе.
- `context.go` заменяет стек по иерархии маршрутов, `context.push` кладёт экран поверх.

---

## 8. Границы между фичами

Как cross-imports в FSD: **`features/a` не импортирует `features/b`.**

Что делать, когда фичам нужно общее:

| Ситуация | Решение |
|---|---|
| Общий UI без бизнес-смысла (кнопка, `ErrorView`) | `core/widgets/` |
| Общая сущность (`User` нужен и в `auth`, и в `profile`) | `core/domain/entities/` (или выдели фичу-владельца и договорись, что импорт её `domain/` разрешён, но зафиксируй это здесь) |
| Экран A открывает экран B | Только через роутер: `context.go('/b/1')`, без импорта страницы |
| Фича A реагирует на событие фичи B (logout → очистить корзину) | Общий провайдер в `core/`, обе фичи его `watch`'ат |

---

## 9. Соответствие FSD

| FSD | Здесь |
|---|---|
| `app` | `lib/app/` |
| `pages` | `features/*/presentation/pages/` |
| `widgets` / `features` | `features/*/presentation/` (+ провайдеры) |
| `entities` | `features/*/domain/entities/` (общие лежат в `core/`) |
| `shared` | `lib/core/` |
| сегмент `api` | `data/datasources/` |
| сегмент `model` | `presentation/providers/` + `domain/` |
| сегмент `ui` | `presentation/pages/`, `presentation/widgets/` |
| публичный API (`index.ts`) | не используется: импорт идёт по полному пути `package:my_app/...`, границы держатся правилами из [§3](#3-слои-что-где-лежит-и-что-кому-можно) |

Главное отличие от FSD в том, что FSD режет по слоям *поверх* слайсов, а здесь сначала фича, потом слои внутри неё.

---

## 10. Что добавлять и когда

Не добавляй это заранее. Ставь только тогда, когда появилась боль:

| Когда | Что |
|---|---|
| Моделей больше 5–10 и надоело писать `fromJson`/`==`/`copyWith` руками | `freezed` + `json_serializable` + `build_runner` |
| Нужно хранить токен / настройки | `shared_preferences` / `flutter_secure_storage` → `data/datasources/*_local_data_source.dart` |
| Авторизация | Interceptor в `core/network/` (подставить токен, обработать 401) |
| Нужны строгие проверки границ слоёв | `custom_lint` / `import_lint` с правилами из [§3](#3-слои-что-где-лежит-и-что-кому-можно) |
| Несколько окружений (dev/prod) | `--dart-define-from-file=env/dev.json` |
| Мультиязычность | `flutter_localizations` + `intl` (`l10n.yaml`) |

---

## 11. Чек-лист: новая фича

На примере `comments`:

1. `lib/features/comments/domain/entities/comment.dart` — entity.
2. `domain/repositories/comments_repository.dart` — `abstract interface class CommentsRepository`.
3. `domain/usecases/get_comments.dart` — класс с `call()`.
4. `data/models/comment_model.dart` — `fromJson` + `toEntity()`.
5. `data/datasources/comments_remote_data_source.dart` — `dio.get(...)`.
6. `data/repositories/comments_repository_impl.dart` — `implements`, ловит `DioException` → `AppException`.
7. `di.dart` — три провайдера: datasource → repository (тип контракта!) → usecase.
8. `presentation/providers/comments_provider.dart` — `FutureProvider` / `AsyncNotifierProvider`.
9. `presentation/pages/comments_page.dart` — `ConsumerWidget`, `.when(data/error/loading)`.
10. Маршрут в `lib/app/router.dart`.
11. Тест `test/features/comments/comments_test.dart` с фейковым репозиторием.
12. Прогнать `flutter analyze && flutter test`.

Порядок «снизу вверх» (domain → data → presentation) выбран не случайно: сначала описываешь, *что* нужно, потом *откуда* это берётся, потом *как* показывается.

---

## 12. Тесты

- **Widget-тест экрана** с `overrideWithValue` на репозиторий ([пример](../test/features/posts/posts_test.dart)). Это самая выгодная проверка: она проходит через UI, провайдеры и usecase без сети.
- **Unit-тест модели**: `fromJson` → `toEntity`. Ловит изменения в API.
- Usecase с логикой тестируется unit-тестом с фейковым репозиторием.
- Фейки пишутся руками (`implements PostsRepository`). Mock-библиотеку (`mocktail`) подключай, когда понадобится проверять *вызовы* (`verify`), а не только результат.
