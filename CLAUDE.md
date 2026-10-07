# Правила для AI-агентов в этом проекте

Flutter, Feature-first + Clean Architecture. Полные правила: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Прочитай его перед тем, как добавлять фичу или менять слои.

Жёсткие правила:

1. Новая фича кладётся в `lib/features/<name>/{domain,data,presentation}` + `di.dart`, по чек-листу из ARCHITECTURE.md §11. Образец — `features/posts`.
2. `domain/` не импортирует Flutter, dio, Riverpod и `data/`.
3. `presentation/` не импортирует `data/`. Зависимости берутся только через провайдеры из `di.dart`.
4. Фича не импортирует другую фичу. Общее поднимается в `lib/core/`.
5. Из data-слоя наружу выходит только `AppException`, `DioException` ловится в `*_repository_impl.dart`.
6. Провайдер репозитория объявляется с типом контракта: `Provider<XRepository>`.
7. Импорты пишутся только как `package:my_app/...`.
8. Перед тем как сказать «готово», прогнать `flutter analyze && flutter test`.

Документация и комментарии пишутся на русском, код на английском.
