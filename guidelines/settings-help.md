# Settings Page Help Guide

This guide explains all sections available in the **Settings** page and how they are used.

## How the Settings page works

- Settings are organized into sections in the left-side navigation.
- Each section has **Reset** and **Save** buttons.
- **Reset** restores the current section values from last saved settings.
- **Save** writes only that section's values.
- Success and error messages appear as toast notifications.

## 1. Store Profile

Use this section to set:

- Store Name
- Business Type
- Store Address
- FSSAI Number

Notes:

- Store Name, Business Type, and Store Address are required.
- FSSAI Number is optional.

## 2. Print Language

Select receipt print language:

- English
- Tamil (தமிழ்)

## 3. UPI Payment

Set UPI details for receipts/payment display:

- UPI ID
- Display Name

## 4. Payment Options

Enable one or more billing payment modes:

- Cash
- GPay
- Card

Notes:

- At least one payment mode must remain selected.

## 5. Appearance

Configure application look and scale:

- UI Size: XS, SM, MD, LG, XL, XXL
- Theme: Light or Dark

## 6. Admin Session

Configure admin auto-logout timeout.

Available timeout values range from short to long sessions (seconds/minutes), and the selected value is saved as the admin session timeout.

## 7. Inventory Control

Toggle inventory behavior:

- Enable inventory tracking

## 8. Item Configuration

This section controls item master defaults and image behavior.

### Item Images Root Path

Set the root path used for item images, for example:

- Local path: `C:\POS\images`
- URL root: `http://localhost:3000/images`

Image conventions:

- Item images are saved and resolved using filename format: `<SKU>_MASTER.jpg`
- Only JPG/JPEG files are supported in item image selection flow

### Categories

- Add custom categories
- Remove categories
- `OTHER` is system-reserved and always available

### Brands

- Add custom brands
- Remove brands
- Use **Propagate from catalog** to build/update brands from existing item catalog values

### Wholesale

- Auto-apply wholesale pricing (toggle)

---

Product developed and maintained by **silex-dv** — **https://silexdv.com**
