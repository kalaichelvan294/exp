# pos_294_flutter

Flutter **Windows desktop** POS app (`pos-294`).

## Recent functionality updates

- **Inventory automatic deduction** on bill save and update.
  - When a bill is created, inventory is deducted for each line item based on qty/weight.
  - When a bill is updated, old inventory is restored and new inventory is deducted (delta applied).
  - Allows negative inventory (no over-selling validation).
  - Updates `inv_current_qty` for unit items or `inv_current_weight` for weight items.
- **Camera search keyboard shortcut** for seamless workflow.
  - Press `/` to instantly capture a frame and search for products (camera activates on demand).
  - Press `/` to focus search field if camera is turned off.
  - Click camera badge to open settings modal with live preview and control options.
- **Camera control modal** with live feed preview and persistent off/on toggle.
  - Shows live camera preview so users can see what the camera sees.
  - Displays camera status with color-coded badge (Green/Orange/Red/Yellow/Gray).
  - "Turn Camera Off/On" button for persistent camera preference toggle.
  - Camera automatically disposes when modal closes to free resources.
  - Accessible via camera badge click from Sales Desk search area.
- **Camera lifecycle management** (graceful shutdown & on-demand initialization).
  - Camera is NOT initialized on app startup (lazy load only).
  - Camera only exists when actively needed: "/" search or modal preview.
  - Graceful disposal when not in use prevents "Camera must be disposed before creating again" errors.
  - Single camera controller shared between "/" search and modal preview.
- **Camera badge color states** (5-state system).
  - 🟢 Green: Camera connected and actively capturing.
  - 🟠 Orange: Camera turned off (requires modal to re-enable).
  - 🔴 Red: Camera error (shows error message in tooltip).
  - 🟡 Yellow: Scanning/capturing frame.
  - ⚫ Gray: Offline/unavailable.
- **Windows image-based product search** in Sales Desk with live camera integration and barcode detection.
  - Camera captures frames and extracts product data via barcode (priority) or ONNX image embedding similarity.
  - Barcode match returns 100% similarity; embedding match returns cosine-similarity score.
  - Search results display alongside typed-text results; click an image card to select that product.
- **Automatic barcode extraction** from training images during embedding refresh.
  - Scans master image for barcode codes (Code39, Code128, EAN, UPC, ITF, Codabar) using pure-Dart Yomu decoder.
  - If barcode found and differs from product barcode, updates product automatically.
- **Embedding refresh and cleanup controls** in Settings > Item Configuration.
  - Click "Refresh embeddings" to rebuild the product embedding index from training images.
  - Toggle "Clean up training images after embedding" to auto-delete variant images (_1 through _5) after indexing; master (_master) is always kept.
- Sales Desk search dropdown is now **image-card only** in a **3-column keyboard-navigable grid**.
- Sales Desk add flow: Enter adds selected item, focus moves to qty/wt, next Enter confirms and returns focus to search.
- Search cards now show item image, Tamil/English names, price per qty/kg, stock tag, and brand.
- Reports page and route were removed.
- Items add/edit modal redesigned with image-first layout and grouped fields.
- Item image handling supports JPG/JPEG/PNG, saved with training format (`<SKU>_master`, `<SKU>_1` through `<SKU>_5`) to configurable root path from Settings.
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
    image_search/               ONNX embedding indexing and camera search (Windows only)
```

Each feature follows clean architecture:

- `presentation/` - pages and widgets
- `application/` - state and business logic
- `domain/` - models and enums
- `data/` - repository implementations and DB queries

## Features

### Sales Desk / Billing

- Keyboard-first cart entry and checkout flow with automatic inventory deduction
- 3-column image search cards with keyboard navigation
- **Camera-based product search** (Windows only)
  - Press `/` to instantly capture and search (camera activates on demand)
  - Click camera badge to open settings modal with live preview
  - Camera status chip shows Live (green), Offline (gray), Error (red), Scanning (yellow), or Turned Off (orange)
  - Automatically tries barcode extraction first (priority match at 100% similarity)
  - Falls back to ONNX image embedding similarity for products without barcodes
  - Live camera feed preview in modal allows user to see what camera sees
  - Single camera controller shared between "/" search and modal preview
  - Graceful disposal prevents "Camera must be disposed" errors
- **Automatic inventory deduction**
  - Inventory is deducted when bill is successfully saved
  - On bill update, old inventory is restored and new inventory is deducted
  - Allows negative inventory (no over-selling validation)
  - Updates `inv_current_qty` (for unit items) or `inv_current_weight` (for weight items)
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
  - **Refresh embeddings** button to rebuild product image embeddings from training images
    - Scans all products for training image files (format: `<SKU>_master.<ext>`, `<SKU>_1.<ext>` through `<SKU>_5.<ext>`)
    - Only indexes products with master + at least one variant image
    - Computes 112x112 ONNX embeddings locally (Windows only)
    - Auto-extracts barcode from master image using Yomu decoder; updates product barcode if found and different
  - **Clean up training images after embedding** toggle
    - Auto-deletes variant images (_1 through _5) after successful embedding refresh
    - Master image (_master) is always retained for future searches
- Toast-based success and error messages

### Authentication / Printing

- Admin PIN/session protection
- WebView-backed receipt preview and print flow

## Image Search Architecture (Windows Only)

### Overview

The app includes a local, offline image-based product search system using ONNX neural network inference. This enables two search modes:

1. **Barcode-based** (priority): Extracts product barcode from camera frame or training image using pure-Dart Yomu decoder, returns exact 100% match if barcode found
2. **Embedding-based** (fallback): Computes cosine-similarity between query image embedding and indexed product embeddings, returns top match

### Training Images

Product images are organized in a configurable file root (set in Settings > Item Configuration):

```
<ImageRoot>/
  <SKU>_master.jpg        Master image (required for indexing)
  <SKU>_1.jpg             Variant 1 (optional, used for training)
  <SKU>_2.jpg             Variant 2 (optional, used for training)
  ...
  <SKU>_5.jpg             Variant 5 (optional, used for training)
```

**Supported formats**: JPG, JPEG, PNG

**Master image naming**: `<SKU>_master.<ext>` is the authoritative product image and barcode source. Master images are never deleted during cleanup.

**Variant images**: `<SKU>_1.<ext>` through `<SKU>_5.<ext>` are alternate angles or lighting. Used only for embedding indexing. Can be auto-deleted by enabling "Clean up training images after embedding" in Settings.

### Embedding Indexing

When "Refresh embeddings" is clicked in Settings:

1. **Scan**: Find all SKUs with master image + at least one variant
2. **Process**: For each product image:
   - Resize to 112×112 pixels
   - Normalize by mean=127.5, scale=1/128
   - Run ONNX model to get 512-dim embedding vector
   - L2-normalize for cosine-similarity dot-product equivalence
   - Store in `product_embeddings` table with product_id and image_url
3. **Barcode extraction** (master image only):
   - Decode barcode using Yomu (Code39, Code128, EAN, UPC, ITF, Codabar)
   - If barcode found and differs from `products.barcode`, auto-update the field
4. **Cleanup** (if enabled):
   - Delete variant images (_1 through _5); always keep master

### Camera Search (Sales Desk)

**Workflow**:
1. Press `/` to instantly capture a frame and search (camera activates on demand).
2. Camera captures and processes the frame:
   - Sent to barcode decoder → if match found, return 100% similarity (exact match)
   - Sent to embedding inference → compute cosine-similarity against indexed products
   - Best match (barcode or embedding) is displayed in search results
3. Click image card to select product and add to cart
4. Click camera badge to open settings modal with live preview

**Camera Control Modal**:
- Shows live camera preview so user can see what the camera sees
- Displays camera status with color-coded badge (Green/Orange/Red/Yellow/Gray)
- "Turn Camera Off/On" button to disable/enable camera search (persistent toggle)
- Camera automatically disposed when modal closes (graceful shutdown)

**Camera Lifecycle**:
- Camera is **NOT** initialized on app startup (lazy load only)
- Camera only initialized when needed:
  - "/" key pressed → capture one frame and search, then dispose
  - Camera badge clicked → initialize for live preview in modal
  - Modal closed → dispose camera and free resources
- Single camera controller shared between "/" search and modal preview
- Prevents "Camera must be disposed before creating again" errors through graceful lifecycle management

**Camera Badge States**:
- 🟢 **Live**: Camera connected and actively capturing (preview mode in modal)
- 🟡 **Scanning**: Currently processing a frame (busy state during "/" search)
- 🟠 **Off**: Camera turned off via modal (requires re-enabling)
- 🔴 **Error**: Camera error occurred (shows error in tooltip)
- ⚫ **Offline**: Camera unavailable or not connected

**Platform support**: Camera is Windows-only. On other platforms, "/" focuses search field instead.

## Inventory Management

### Automatic Deduction on Billing

When a bill is successfully created or updated, inventory is automatically adjusted:

**On Bill Creation**:
- Each line item's quantity/weight is deducted from the corresponding product inventory
- `inv_current_qty` is reduced for unit-priced items
- `inv_current_weight` is reduced for weight-priced items

**On Bill Update**:
- Old bill inventory is restored (reversed)
- New bill inventory is deducted
- Delta is calculated and applied: `new_qty - old_qty`

**Negative Inventory**:
- Negative inventory is **allowed** (no over-selling validation)
- Useful for backorders, consignment, or manual adjustments

**Example**:
```
Initial stock: 100 units
Bill created with 30 units → Inventory becomes 70
Bill updated to 50 units → Old 30 restored (70 + 30 = 100), new 50 deducted (100 - 50 = 50)
Final stock: 50 units
```

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
