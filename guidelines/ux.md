# POS & Billing Application
# AI UX Design System Specification
Version: 2.0

---

# PURPOSE

This document is the authoritative UX, UI, design, layout, spacing, typography, component, and interaction specification for the POS & Billing application.
All humans and AI agents must follow these rules.
If any implementation conflicts with this document, this document takes precedence.
AI agents must NOT invent styles, layouts, colors, spacing values, components, or interaction patterns not defined here.

---

# DESIGN PHILOSOPHY

Design Language: Calm Enterprise Minimalism

The application should feel:
- Professional
- Fast
- Quiet
- Predictable
- Efficient
- Data-Oriented

Avoid:
- Visual noise
- Excessive colors
- Excessive animations
- Trendy UI patterns
- Decorative styling

The UI must optimize for:
1. Speed of operation
2. Readability
3. Consistency
4. Accessibility
5. Scalability

---

# CORE DESIGN PRINCIPLES

## Principle 1

Consistency over creativity. If an existing pattern exists, reuse it.

## Principle 2

Users should never have to relearn controls. Similar actions must always look identical.

## Principle 3

Primary actions must be visually obvious.

## Principle 4

Information hierarchy must be stronger than color hierarchy.

## Principle 5

Whitespace must create structure. Not decoration.

---

# COLOR SYSTEM

## Primary Brand Color

Used only for:
- Primary actions
- Active navigation
- Active tabs
- Active toggles
- Selected radios
- Focus states

```yaml
primary-500: #1F3A5F
primary-600: #162C49
```

## Neutral System

```yaml
neutral-0:   #FFFFFF
neutral-50:  #F8FAFC
neutral-100: #F1F5F9
neutral-200: #E2E8F0
neutral-300: #CBD5E1
neutral-400: #94A3B8
neutral-500: #64748B
neutral-600: #475569
neutral-700: #334155
neutral-800: #1E293B
neutral-900: #0F172A
```

## Status Colors

### Success

```yaml
success-500: #16A34A
```

Used for:
- Paid
- Success
- Completed
- Available

### Warning

```yaml
warning-500: #D97706
```

Used for:
- Pending
- Low Stock
- Warning Messages

### Error

```yaml
error-500: #DC2626
```

Used for:
- Errors
- Validation failures
- Delete actions

### Info

```yaml
info-500: #0284C7
```

Used for:
- Informational messages
- Notifications

---

# COLOR USAGE RULES

Allowed:
- Primary color for actions
- Status colors for business meaning
- Neutral colors for structure

Forbidden:
- Gradients
- Decorative colors
- Random HEX values
- Rainbow status indicators
- Colored card backgrounds

The UI should remain 90% neutral.

---

# DARK MODE

The application supports a dark theme via `data-theme="dark"` on `:root`.

Dark token overrides:
```yaml
bg-root:     #0F172A
bg-surface:  #1E293B
bg-muted:    #334155
bg-hover:    #475569
text-primary:    #F8FAFC
text-secondary:  #E2E8F0
text-muted:      #CBD5E1
border-strong:   #475569
border-soft:     #334155
```

Rules:
- Always use semantic color tokens, never raw HEX values, so dark mode works automatically.
- Never test only in light mode. All components must work in both modes.

---

# TYPOGRAPHY

Font Family:
```yaml
Primary:
  Inter

Fallback:
  Segoe UI
  Arial
  Sans-Serif
```

---

# TYPOGRAPHY SCALE

## Page Title

```yaml
size: 28  (--fs-28)
weight: 700
line-height: 36  (--lh-36)
```

Examples:
- Items
- Settings
- Inventory

---

## Section Title

```yaml
size: 20  (--fs-20)
weight: 600
line-height: 28
```

---

## Card Title

```yaml
size: 16  (--fs-16)
weight: 600
line-height: 24  (--lh-24)
```

---

## Standard Text

```yaml
size: 14  (--fs-14)
weight: 400
line-height: 20  (--lh-20)
```

---

## Helper Text

```yaml
size: 12  (--fs-12)
weight: 400
line-height: 18  (--lh-18)
```

Color:
```yaml
neutral-500  (var(--text-muted))
```

---

# CSS DESIGN TOKEN VARIABLES

All spacing, sizing, color, and radius values must reference CSS custom properties defined in `:root`. Never use raw values directly.

## Spacing Tokens

```css
--sp-4:  calc(4px  * var(--space-scale))
--sp-6:  calc(6px  * var(--space-scale))   /* chip padding, compact gaps */
--sp-8:  calc(8px  * var(--space-scale))
--sp-12: calc(12px * var(--space-scale))   /* table padding, dense form gaps */
--sp-16: calc(16px * var(--space-scale))
--sp-16: calc(24px * var(--space-scale))
--sp-32: calc(32px * var(--space-scale))
```

Note: `--sp-6` and `--sp-12` are off the base-8 grid and are reserved for compact UI
sub-components (chips, table cells, filter bars) where 8px is too large and 4px too small.

## Font Scale Tokens

```css
--fs-12  --fs-14  --fs-16  --fs-20  --fs-24  --fs-28
```

## Line Height Tokens

```css
--lh-18  --lh-20  --lh-24  --lh-32  --lh-36
```

## Border Radius Tokens

```css
--radius-sm:   8px    /* inputs, buttons, dropdowns, chips */
--radius-md:   12px   /* cards, modals, table wrappers */
--radius-full: 999px  /* pills, badges, circular icon buttons */
```

## Control Height Token

```css
--control-height: calc(40px * var(--space-scale))
```

Used for all interactive controls (inputs, selects, buttons) so they scale with the
`--space-scale` variable.

---

# SPACING SYSTEM

Base Grid: 8px

Primary approved spacing values:
```yaml
4    8    16    24    32    48    64
```

Compact sub-component exceptions (use token only, not raw value):
```yaml
6    12
```

Forbidden values:
```yaml
11   13   17   19   21   27   29
```

---

# BORDER RADIUS

```yaml
small:  8px   (--radius-sm)   → inputs, buttons, chips
medium: 12px  (--radius-md)   → cards, dialogs
full:   999px (--radius-full) → pills, icon buttons
```

---

# SHADOWS

Minimal shadows only.

Card:
```css
0 1px 3px rgba(0,0,0,0.05)   (--shadow-soft)
```

Dialog:
```css
0 10px 30px rgba(0,0,0,0.12)  (--shadow-dialog)
```

No floating UI. No dramatic shadows.

---

# LAYOUT STANDARD

Page Structure:
```text
Page Header

Page Description

Toolbar / Actions

Primary Content

Footer Actions
```

---

# PAGE PADDING

```yaml
24px  (--sp-24)
```

All content containers:
```yaml
24px
```

---

# CARD STANDARD

Card Layout:
```text
Card Title
Card Content
Card Actions
```

Card Spec:
```yaml
Background: var(--bg-surface)
Border:     1px solid var(--border-soft)
Radius:     var(--radius-md)
Padding:    var(--sp-16)
Shadow:     var(--shadow-soft)
```

Card spacing:
```yaml
24px  (--sp-24)
```

---

# FORM STANDARDS

Always:
```text
Label
Input
Helper Text
```

Never:
```text
Label: Input
```

Never:
```text
Input
Label
```

---

# FORM SPACING

Label to Input:
```yaml
8px  (--sp-8)
```

Input to Helper:
```yaml
4px  (--sp-4)
```

Field to Field:
```yaml
24px  (--sp-24)
```

Section to Section:
```yaml
32px  (--sp-32)
```

---

# INPUT COMPONENT

Height:
```yaml
var(--control-height)  [40px base]
```

Radius:
```yaml
var(--radius-sm)  [8px]
```

Horizontal Padding:
```yaml
12px  (--sp-12)
```

Default:
```yaml
Background: var(--bg-surface)
Border:     1px solid var(--border-strong)
```

Focus:
```yaml
Border:     var(--accent)
Box-shadow: var(--focus-ring)
```

Disabled:
```yaml
Background: var(--bg-muted)
Text:       var(--text-muted)
Opacity:    0.55
```

---

# TEXTAREA

Minimum Height:
```yaml
96px
```

Uses same styling as Input.

---

# DROPDOWN

Height:
```yaml
var(--control-height)
```

Uses exact Input styling.

---

# BUTTONS

Button Height:
```yaml
var(--control-height)  [40px base]
```

Horizontal Padding:
```yaml
var(--sp-16)  [16px]
```

Radius:
```yaml
var(--radius-sm)  [8px]
```

---

# PRIMARY BUTTON

Used only for:
- Save
- Create
- Checkout
- Submit
- Add Item

Style:
```yaml
Background: var(--accent)
Text:       var(--accent-contrast)
Border:     var(--accent)
```

Hover:
```yaml
Background: var(--primary-600)
```

---

# SECONDARY BUTTON

Used for:
- Cancel
- Reset
- Back
- Close
- Download

Style:
```yaml
Background: var(--bg-surface)
Border:     1px solid var(--border-strong)
Text:       var(--text-primary)
```

---

# DANGER BUTTON

Style:
```yaml
Background: var(--danger)
Text:       var(--accent-contrast)
```

Used only for destructive actions.

---

# BUTTON RULES

Maximum one primary button per section.

Example:

Correct
```text
[Cancel] [Save]
```

Wrong
```text
[Save]
[Create]
[Submit]
```

---

# ACTIVE STATE PRESERVATION

When a button/tab/chip is `.active`, its background and text color must be
explicitly preserved on `:hover` and `:focus-visible` so the global
`button:hover` rule (which sets `background: neutral-100`) does not override it.

Pattern:
```css
.tab-btn.active:is(:hover, :focus-visible):not(:disabled) {
  background: var(--accent);
  border-color: var(--accent);
  color: var(--accent-contrast);
}
```

This rule must be declared for every component that uses `.active` toggle states.

---

# ICON BUTTONS

Size:
```yaml
24 × 24px
```

Radius:
```yaml
var(--radius-full)
```

Default:
```yaml
Border:     transparent
Background: transparent
```

Hover / Focus-visible:
```yaml
Background: var(--neutral-100)
Border:     var(--border-soft)
```

---

# RADIO BUTTONS

Size:
```yaml
18px
```

Selected:
```yaml
accent-color: var(--primary-500)
```

Spacing:
```yaml
12px between button and label  (--sp-12)
24px between options            (--sp-24)
```

---

# CHECKBOXES

Size:
```yaml
18px
```

Selected:
```yaml
accent-color: var(--primary-500)
```

Use same rules as Radio Buttons.

---

# TOGGLE SWITCH

Size:
```yaml
44 × 24px
```

OFF:
```yaml
Track: var(--neutral-300)
Thumb: white
```

ON:
```yaml
Track: var(--accent)
Thumb: white
```

---

# TAB SYSTEM

## Tab Row Container

```yaml
display:      inline-flex
gap:          var(--sp-8)
align-self:   flex-start
margin-bottom: var(--sp-16)
```

Class: `.page-tabs`, `.inventory-tabs`, `.bulk-tabs` (all share one shared definition)

## Tab Button

A shared base class `.tab-btn` defines the base style. Existing page-specific
names (`.page-tab-btn`, `.inventory-tab-btn`, `.bulk-tab-btn`) are listed in the
same rule block as aliases — no separate definitions per page.

```yaml
height:  var(--control-height)
padding: 0 var(--sp-16)
radius:  var(--radius-sm)
border:  1px solid var(--border-soft)
bg:      var(--bg-surface)
color:   var(--text-secondary)
weight:  600
```

Active:
```yaml
background:   var(--accent)
border-color: var(--accent)
color:        var(--accent-contrast)
```

Active hover: Must be preserved (see Active State Preservation rule above).

---

# TABLE STANDARDS

Header Height:
```yaml
44px
```

Row Height:
```yaml
48px
```

Header Style:
```yaml
Background: var(--bg-muted)
Text Weight: 600
```

Row Hover:
```yaml
Background: var(--bg-hover)
```

Table Wrapper:
```yaml
border:  1px solid var(--border-soft)
radius:  var(--radius-md)
shadow:  var(--shadow-soft)
```

Use `:is(th, td)` selectors for shared alignment rules to eliminate repetition.

---

# TABLE ALIGNMENT RULES

Text Columns:
```yaml
Left Aligned
```

Examples:
- Product Name
- Category
- SKU

Numeric Columns:
```yaml
Right Aligned
```

Examples:
- Rate
- Discount
- Tax
- Quantity
- Total

Actions Column:
```yaml
Right Aligned
```

---

# FILTER BAR COMPONENT

Used on: Inventory, Reports (where row-level filtering is needed above a table).

```yaml
display:       flex
flex-wrap:     wrap
gap:           var(--sp-8)
align-items:   center
padding:       var(--sp-16)
background:    var(--bg-muted)
border:        1px solid var(--border-soft)
border-radius: var(--radius-md)
margin-bottom: var(--sp-16)
```

Filter inputs/selects inside a filter bar:
```yaml
height:  var(--control-height)
radius:  var(--radius-sm)
border:  1px solid var(--border-strong)
bg:      var(--bg-surface)
```

Primary filter action button:
```yaml
background: var(--accent)
color:      var(--accent-contrast)
```

Reset button:
```yaml
background: var(--bg-surface)
color:      var(--text-secondary)
border:     var(--border-strong)
```

---

# CHIP / CHIP-SELECT COMPONENT

## Display Chips (non-interactive, removable)

Used in: settings chip lists for categories and brands.

```yaml
display:        inline-flex
padding:        var(--sp-6) 10px
border-radius:  var(--radius-full)
border:         1px solid var(--border-soft)
background:     var(--bg-surface)
color:          var(--text-primary)
```

Remove button inside chip:
```yaml
background: transparent
border:     none
color:      var(--text-secondary)
```

Remove button hover:
```yaml
color: var(--danger)
```

## Selectable Filter Chips (toggled on/off)

Used in: bulk operations brand/category filter.

Inactive:
```yaml
background: var(--bg-surface)
border:     1px solid var(--border-soft)
color:      var(--text-secondary)
weight:     600
font-size:  var(--fs-12)
```

Active (selected):
```yaml
background:   var(--accent)
border-color: var(--accent)
color:        var(--accent-contrast)
```

Active hover must be preserved (see Active State Preservation rule).

---

# NAVIGATION

Top Navigation Height:
```yaml
48px
```

Structure:
```text
[topbar-left]
  topbar-shop
    topbar-brand (store name)
    topbar-subtitle (business type)
  topbar-nav (page links)
```

Active Nav Button:
```yaml
Background: var(--accent)
Text:       var(--accent-contrast)
```

Inactive Nav Button:
```yaml
Background: var(--bg-surface)
Text:       var(--text-secondary)
Border:     1px solid var(--border-soft)
```

---

# DIALOGS

Maximum Width:
```yaml
640px
```

Padding:
```yaml
24px  (--sp-24)
```

Footer Actions:
```text
Cancel | Save
```

Primary action always rightmost.

---

# POS BILLING SCREEN RULES

Layout:
```text
Sales Area      75%
Checkout Area   25%
```

---

# CHECKOUT PANEL

Must contain:
- Payment Method
- Discount
- Item Count
- Subtotal
- Total
- Checkout Action

---

# TOTAL DISPLAY

Must be visually dominant.

Typography:
```yaml
Size:   var(--fs-24)
Weight: 700
```

Color:
```yaml
var(--text-primary)
```

---

# ITEM GRID RULES

Search must remain visible.

Table remains primary interaction method.

Actions must require at most one click.

---

# SETTINGS PAGE RULES

Layout:
```yaml
Single-column stack of settings-section cards
```

Gap:
```yaml
24px  (--sp-24)
```

Maximum controls per card:
```yaml
8
```

Split into additional cards if exceeded.

Sub-sections within a settings card use `.settings-subsection` with a
left border and muted background for visual grouping.

---

# CODE ORGANIZATION

CSS is split across shared and page-specific files:

```text
src/renderer/shared/styles.css          → tokens, layout, shared components
src/renderer/pages/billing/billing.css  → billing-specific styles only
src/renderer/pages/items/items.css
src/renderer/pages/inventory/inventory.css
src/renderer/pages/bulk/bulk.css
src/renderer/pages/reports/reports.css
src/renderer/pages/settings/settings.css
```

Rules:
- Shared base styles and tokens always live in `styles.css`.
- Page-specific prefixed class names (`.billing-*`, `.inv-*`, `.bulk-*`, `.reports-*`, `.settings-*`) live in their co-located CSS file.
- Cross-page classes (`.items-page-head`, `.items-form`, `.form-group`) live in `styles.css`.
- Never add page-specific styles to `styles.css`.
- Never add shared/token styles to a page file.

---

# ALIGNMENT RULES

Labels:
```yaml
Left Aligned
```

Form Controls:
```yaml
Full Width
```

Buttons:
```yaml
Right Aligned
```

Totals:
```yaml
Right Aligned
```

Currency:
```yaml
Right Aligned
```

---

# ACCESSIBILITY

Minimum Contrast:
```yaml
4.5:1
```

Required Keyboard Support:

```yaml
Tab
Shift+Tab
Enter
Escape
```

Focus States:
Mandatory
AI must never remove focus indicators.

ARIA attributes required:
- `role="dialog"` and `aria-modal="true"` on all modal dialogs
- `aria-label` on icon buttons
- `aria-current="page"` on active navigation links
- `aria-live="polite"` on dynamic list regions (chip lists)
- `aria-labelledby` on grouped form sections

---

# RESPONSIVE RULES

Desktop First

Breakpoints:
```yaml
Large:  1200px  (settings form grid 2-col → 2-col tighter)
Tablet: 1024px  (layout grid → single column)
Mobile: 768px   (stacked forms, reduced padding)
Small:  720px   (settings form → full width fields)
```

Cards may stack vertically.
Controls must remain usable.

---

# ANIMATION

Allowed:
```yaml
100ms - 200ms
```

Animations limited to:
- Hover
- Focus
- Toggle switch transition (300ms — explicitly approved)

Forbidden:
- Bounce
- Spin
- Flash
- Decorative motion

---

# AI IMPLEMENTATION RULES

AI MUST ALWAYS:
- Use CSS design tokens (`var(--token-name)`)
- Use approved spacing tokens
- Use approved typography tokens
- Reuse existing components
- Follow accessibility standards
- Maintain alignment consistency
- Preserve active-state colors on hover/focus
- Use `:is()` selectors to reduce repetition

---

# AI MUST NEVER
- Hardcode colors
- Hardcode spacing values
- Hardcode border-radius values
- Create new component styles outside this spec
- Introduce gradients
- Introduce glassmorphism
- Introduce neumorphism
- Introduce multiple button variants
- Create custom layouts outside this specification
- Add page-specific styles to `styles.css`
- Override active-state colors from a global hover rule without restoring them

---

# AI REVIEW CHECKLIST

Before code is accepted verify:
- Uses approved color tokens
- Uses approved spacing tokens
- Uses approved typography tokens
- Uses approved component styles
- Uses approved alignment rules
- Uses approved layouts
- Uses accessibility rules (ARIA, focus states)
- Right-aligns numeric values
- Uses one primary action per section
- Uses labels above controls
- Uses token-based styling only
- Active states are preserved on hover/focus
- CSS lives in the correct file (shared vs page-specific)
- No hardcoded values outside `:root`

---

# DEFINITION OF DONE

A UI implementation is complete only if:

- Follows this specification
- Uses only approved tokens
- Reuses approved components
- Passes accessibility review
- Passes alignment review
- Passes spacing review
- Passes visual consistency review
- Works in both light and dark modes
- CSS is in the correct file

If a new UI pattern is needed, the AI must propose a design system update rather than inventing a new pattern.