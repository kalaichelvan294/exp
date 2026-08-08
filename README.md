# pos_294_flutter

Flutter **Windows desktop** POS app (`pos-294`).

## Recent functionality updates

- Sales Desk search dropdown is now **image-card only** in a **3-column keyboard-navigable grid**.
- Sales Desk search shortcut is now **`/`**.
- Sales Desk add flow: Enter adds selected item, focus moves to qty/wt, next Enter confirms and returns focus to search.
- Search cards now show item image, Tamil/English names, price per qty/kg, stock tag, and brand.
- Reports page and route were removed.
- Items add/edit modal redesigned with image-first layout and grouped fields.
- Item image handling supports JPG only, saved as `<SKU>_master.jpg` to configurable root path from Settings.
- Item images in Sales Desk and Items page now resolve using Settings image root path.
- Brand display with fallback is shown in Sales Desk search cards and Items cards.
- Reusable UI blocks were refactored into `lib/shared/widgets` (common `AppCard` and `SectionCard`).
- Shared controls now include reusable button wrappers (`AppTextButton`, `AppTextIconButton`, `AppIconOnlyButton`) and a generic `AppTabSwitcher`.

## Project structure

```
lib/
  main.dart                     App entrypoint; builds AppConfig + ProviderScope
  app/
    app.dart                    Root MaterialApp.router + global shortcuts
    router.dart                 go_router config (ShellRoute wraps all modules)
    app_routes.dart             Central module route registry
    app_shell.dart              Persistent top navigation + content area
    navigation.dart             Navigation utilities
    appearance.dart             Theme/appearance state (dark mode, font scale)
    module_scaffold.dart        Standard page layout + parity placeholder
  core/
    config/                     Environment variants + AppConfig bootstrap
    database/                   PostgreSQL connection manager
    images/                     Item image path resolution helpers
    theme/                      Design tokens + ThemeData (Material Design)
    logging/                    Logging facade
    shortcuts/                  Keyboard-first shortcut infrastructure
  shared/
    widgets/                    Reusable UI components used across modules
  features/
    auth/                       Admin authentication + PIN protection
    billing/                    Sales desk / POS billing module
    bills/                      Bill history + hold/resume management
    items/                      Item master data + SKU/image management
    inventory/                  Inventory tracking + adjustments
    bulk/                       Bulk import/export operations
    printing/                   Receipt preview + WebView printing
    settings/                   App configuration + preferences
```

Each feature follows clean architecture:

- `presentation/` - pages and widgets
- `application/` - state and business logic
- `domain/` - models and enums
- `data/` - repository implementations and DB queries

## Features

### Sales Desk / Billing

- Keyboard-first cart entry and checkout flow
- 3-column image search cards with keyboard navigation
- `/` shortcut to focus search
- Enter-driven item add and qty/wt confirmation focus flow
- Recent bills and bill edit flow
- Hold / recall bills
- Qty/Wt editing in the cart with step controls
- Duplicate cart rows with merge action
- Preview and print-ready checkout overlay

### Bills

- Saved bill list with filters and pagination
- Bill reopen, edit, and delete actions

### Items & Inventory

- Item master list and redesigned add/edit form
- Item image selection (JPG/JPEG), SKU-based rename, and managed storage path
- Brand/category-aware metadata display
- Inventory tracking and stock adjustments
- Low-stock filtering and item metadata display

### Bulk

- Item bulk import/export
- Inventory bulk import/export
- Sample template downloads and batch result reporting

### Settings

- Section-based settings navigation
- Store profile, print language, UPI, payment options, appearance
- Admin session timeout configuration
- Inventory control toggle
- Item configuration:
  - Category and brand management
  - Brand propagation from catalog
  - Wholesale auto-apply toggle
  - Item Images Root Path configuration
- Toast-based success and error messages

### Authentication / Printing

- Admin PIN/session protection
- WebView-backed receipt preview and print flow

## Configuration

Runtime config resolves from `--dart-define` values (see
`core/config/app_config.dart`):

```
flutter run -d windows \
  --dart-define=POS_ENV=staging \
  --dart-define=POS_DATABASE_URL=postgres://user:pass@host:5432/pos294
```

| Define | Default | Purpose |
| --- | --- | --- |
| `POS_ENV` | `development` | Environment variant |
| `POS_APP_VERSION` | `0.1.0` | Reported app version |
| `POS_DATABASE_URL` | `postgres://postgres:postgres@localhost:5432/pos294` | PostgreSQL connection string |

The connection URL is parsed to extract host, port, database, username, and password.
Postgres is the only supported database backend (direct connection from the app).

## Database connection

`core/database/` contains a platform-aware database abstraction:

**Windows (Native):**
- Direct TCP socket connection to PostgreSQL using the `postgres` package
- No intermediary required; queries execute directly

**Web:**
- HTTP proxy to a backend API (for CORS and security)
- Expects backend endpoints at `/api/db/{query,execute,begin,commit,rollback}`
- Backend must proxy requests to PostgreSQL
- Gracefully degrades if API is unavailable (logs warnings, allows app to load)

### Web

Requires the backend API proxy server. See **[WEB_DATABASE_SETUP.md](WEB_DATABASE_SETUP.md)** for full instructions.

```bash
# Terminal 1: Start backend API server
cd backend && dart pub get
dart run server.dart --db-host localhost --db-port 5432 --db-name pos294 --db-user postgres --db-password postgres --port 3000

# Terminal 2: Run Flutter web app
flutter run -d chrome \
  --dart-define=POS_DATABASE_URL=postgres://postgres:postgres@localhost:5432/pos294
```

Tests are not required for this project.

---

Product developed and maintained by **silex-dv** — **https://silexdv.com**
