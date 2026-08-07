# pos_294_flutter

Flutter **Windows desktop** migration of the existing Electron POS app
(`pos-294`). This repository holds the Phase 1 foundation described in
`../pos-294/specs/flutter-windows-migration-plan.md`.

## Locked decisions

- **Data access:** API bridge over HTTP; the bridge connects **directly to the
  database**. The backend is chosen by configuration — **Postgres by default**,
  SQLite as an alternative (mirrors the Electron `DB_CLIENT` setup).
- **State management:** Riverpod.
- **Migration style:** phase-by-phase with parity gates.
- **Printing:** WebView-backed receipt preview/print (Phase 7).

## Project layout

```
lib/
  main.dart                     App entrypoint; builds AppConfig + ProviderScope
  app/
    app.dart                    Root MaterialApp.router + global shortcuts
    router.dart                 go_router config (ShellRoute wraps all modules)
    app_routes.dart             Central module route registry
    app_shell.dart              Persistent top navigation + content area
    module_scaffold.dart        Standard page layout + parity placeholder
  core/
    config/                     Environment variants + AppConfig bootstrap
    theme/                      Design tokens + ThemeData (from ux-guidelines.md)
    api/                        Typed API bridge client, endpoints, error mapper
    logging/                    Diagnostics facade
    shortcuts/                  Keyboard-first shortcut infrastructure
  features/
    billing/  bills/  items/  inventory/  reports/  bulk/  settings/
                                One presentation folder per migrated module
```

## Configuration

Runtime config resolves from `--dart-define` values (see
`core/config/app_config.dart`):

```
flutter run -d windows \
  --dart-define=POS_ENV=staging \
  --dart-define=POS_API_BASE_URL=http://10.0.0.5:8788 \
  --dart-define=POS_DB_CLIENT=postgres \
  --dart-define=POS_DATABASE_URL=postgres://user:pass@host:5432/pos294
```

| Define               | Default                          | Purpose                          |
| -------------------- | -------------------------------- | -------------------------------- |
| `POS_ENV`            | `development`                    | Environment variant              |
| `POS_API_BASE_URL`   | per-environment default          | API bridge base URL              |
| `POS_APP_VERSION`    | `0.1.0`                          | Reported app version             |
| `POS_DB_CLIENT`      | `postgres`                       | Bridge DB backend (`postgres`/`sqlite`) |
| `POS_DATABASE_URL`   | `postgres://…@localhost/pos294`  | Postgres connection string       |
| `POS_SQLITE_DB_PATH` | `data/pos-294.sqlite`            | SQLite file path                 |

The DB selection mirrors the Electron app's `DB_CLIENT` / `DATABASE_URL` /
`SQLITE_DB_PATH` environment variables. Postgres is the default backend.

## API bridge contract

`core/api/api_endpoints.dart` freezes the endpoint map that mirrors the
operations previously exposed over Electron IPC (`src/preload/preload.js`).
All failures are normalized to `ApiException` with a stable `ApiErrorCode`
(`core/api/error_mapper.dart`) so user-facing error messaging stays consistent.

## Migration status

| Phase | Scope                          | Status         |
| ----- | ------------------------------ | -------------- |
| 1     | Windows foundation / shell     | Implemented    |
| 2     | Core billing (Sales Desk)      | Placeholder    |
| 3     | Bills & hold/resume            | Placeholder    |
| 4     | Items & inventory              | Placeholder    |
| 5     | Reports & settings             | Placeholder    |
| 6     | Bulk operations                | Placeholder    |
| 7     | WebView-backed printing        | Placeholder    |

## Development

```
flutter pub get
flutter analyze
flutter test
flutter run -d windows        # requires the Visual Studio C++ desktop toolchain
```
