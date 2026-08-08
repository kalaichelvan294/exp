# Engineering Guidelines

This document distills implementation guardrails from `specs/documentation.md` and establishes baseline engineering rules.  
For all UX/UI design and styling decisions, `ux-guidelines.md` is the authoritative source of truth.

## Core Principles

1. Preserve keyboard-first POS flows and existing user behavior.
2. Keep mysql data-layer changes consistent and transaction-safe.
3. Route renderer data access only through preload + IPC; no direct DB access from renderer.
4. Keep live data and audit history consistent via transaction-bound writes.
5. Any new feature must not break current billing, items, reports, settings, print preview, or history flows.
6. For UX design, layout, spacing, typography, components, colors, and interactions, follow `ux-guidelines.md` strictly.

## Coding Guidelines

### Necessary

- Keep renderer entry files thin and place page logic in `src/renderer/modules/*-page-controller.js`.
- Reuse shared helpers (formatting, totals, error mapping) instead of duplicating logic.
- Keep preload API explicit and aligned with main IPC handlers.
- Validate IPC payloads and return user-safe error messages.
- Enforce Sales/Admin privilege separation in the **main process**: register
  admin IPC channels through the role guard (`ADMIN_CHANNELS` + `requireAdmin()`).
  Renderer nav/UI gating is cosmetic and must never be the only control.
- Preserve existing search relevance rules (exact SKU -> prefix -> contains) and keyboard interactions (`Alt+S`, Enter/Escape, arrow navigation).
- Maintain existing UI structure conventions (Sales Desk, Current Sale, Bills, Items, Reports, Settings).

### Not Necessary / Avoid

- Do not add direct renderer-to-database calls.
- Do not introduce page-specific visual systems that bypass shared styles.
- Do not return raw DB/runtime exceptions directly to UI.
- Do not duplicate business logic across renderer, main, and DB layers when a shared helper can be used.

## Database Guidelines

### Necessary

- Keep the `mysql-adapter.js` data-access contract consistent and well-structured.
- Continue column-first storage for business fields; use JSON only where already intended (`items_json`, audit item snapshots).
- Preserve constraints (for example, SKU uniqueness).
- Keep immutable audit tables for mutable entities (`product_audit`, `bill_audit`, `inventory_audit`).
- Ensure update/delete + audit write happen in the same transaction.
- Keep mysql foreign key enforcement in place for referential integrity.
- Keep seed behavior bootstrap-only so deleted/edited live items are not reintroduced.
- Keep monetary calculations stored as paise integers where applicable.

### Not Necessary / Avoid

- Do not store full business entities as large JSON blobs when scalar columns are available.
- Do not perform destructive schema resets that risk user data.
- Do not make migration changes in only one DB backend.
- Do not write audit records detached from the underlying mutation transaction.

## UX Guidelines

### Necessary

- Treat `ux-guidelines.md` as mandatory and higher priority than ad-hoc UI decisions.
- Apply only approved tokens, component patterns, spacing, typography, and interaction rules from `ux-guidelines.md`.
- Keep `src/renderer/styles.css` aligned with `ux-guidelines.md`; if conflicts exist, update implementation to match `ux-guidelines.md`.
- Keep billing readability high: compact density, clear amount typography, predictable focus behavior.
- Use actionable user-facing error messages (connection/schema/general), not technical stack traces.
- Preserve in-page tab behavior and backward compatibility routes where already supported.
- Keep print flow behavior consistent (2.5-inch preview path and language setting behavior).
- Keep bilingual item naming behavior intact (`name` + optional `name_ta` with safe fallback).

### Not Necessary / Avoid

- Do not introduce noisy or inconsistent visual patterns between pages.
- Do not remove accessibility affordances such as labeled controls, aria labels, and title hints.
- Do not add blocking UX for optional hardware states when manual billing must remain functional.
- Do not invent colors, spacing values, component variants, or layout patterns outside `ux-guidelines.md`.

## Feature Implementation Safety Checklist

Before considering a feature complete:

1. Verify impacted flows still work end-to-end (current sale, bill history, items CRUD, settings, print preview).
2. Verify preload API changes and main IPC handlers remain synchronized.
3. Verify both DB backends behave the same for create/update/delete/list/search paths.
4. Verify audit history remains correct for every mutable operation touched.
5. Verify existing shortcuts, search behavior, and totals/discount calculations remain unchanged unless intentionally updated.
6. Verify UX implementation conforms to `ux-guidelines.md` (tokens, spacing, typography, alignment, accessibility, and component rules).

## Change Scope Guidance

- Include: UI + renderer modules + preload/main IPC + DB adapters/schema/migrations + docs, when relevant.
- Exclude: unrelated refactors, visual redesign outside shared system, backend-specific one-off behavior.
- Prefer small, reversible, migration-safe increments.

