# Test Case Patterns

## Table of Contents

- Test Case Structure
- E-Commerce Module Coverage
- Priority Guidelines
- Boundary & Negative Test Patterns
- Good/Bad Examples
- Example Test Cases

---

## Test Case Structure

Every test case uses this format:

| Field | Description |
|-------|-------------|
| **TC-ID** | Unique ID: `TC-<MODULE>-<NNN>` (e.g., TC-CART-001) |
| **Title** | Action + expected outcome |
| **Priority** | P0 (blocker), P1 (critical), P2 (major), P3 (minor) |
| **Type** | Functional, API, UI, Integration, Performance, Security |
| **Preconditions** | State required before execution |
| **Test Data** | Specific input values |
| **Steps** | Numbered actions |
| **Expected Result** | Observable outcome per step |
| **Postconditions** | State after execution |

---

## E-Commerce Module Coverage

### Cart
- Add/remove/update items
- Quantity limits, stock validation
- Price calculation with discounts
- Cart persistence (logged-in vs guest)
- Empty cart handling
- Cart merge (guest → logged-in)
- Concurrent modification (two tabs)

### Checkout
- Address validation (required fields, format, international)
- Shipping method selection and cost calculation
- Payment processing (success, decline, timeout, 3DS)
- Order summary accuracy (items, tax, shipping, total)
- Coupon/promo code application and removal
- Back navigation preserves state

### Payments
- Credit card validation (Luhn, expiry, CVV)
- Payment gateway integration (success, failure, timeout, network error)
- Refund processing (full, partial)
- Partial payments / split payments
- Currency handling and conversion
- Idempotency (duplicate submission prevention)
- PCI-DSS compliance (card data never stored raw)

### User Authentication
- Registration (valid/invalid data, duplicate email, password strength)
- Login (valid credentials, invalid, locked account, rate limiting)
- Password reset flow (request, email, token expiry, new password)
- Session management (timeout, concurrent sessions, remember me)
- OAuth/social login (Google, Facebook, Apple)
- MFA/2FA flows

### Product Catalog
- Search (keyword, filter, sort, no results)
- Product detail display (images, description, price, variants)
- Inventory status (in stock, low stock, out of stock)
- Category navigation and breadcrumbs
- Pagination and infinite scroll

### Order Management
- Order creation and confirmation email
- Order status tracking (pending, processing, shipped, delivered)
- Order history with filters
- Cancellation (before/after shipping)
- Returns and refund processing
- Email/SMS notifications at each stage

### Promotions
- Percentage/fixed discounts
- BOGO offers
- Minimum purchase requirements
- Promo code validation (expired, invalid, already used, case sensitivity)
- Stacking rules (combinable vs exclusive)
- Time-limited promotions

---

## Priority Guidelines

| Priority | Criteria | Example |
|----------|----------|---------|
| P0 | Complete feature failure, data loss, security breach, revenue loss | Payment processing crashes, user data exposed |
| P1 | Major feature broken, no workaround, blocks user flow | Cannot add items to cart, login fails for all users |
| P2 | Feature works with workaround or affects minor flow | Filter reset doesn't work (manual URL edit works) |
| P3 | Cosmetic, minor UX issue, no functional impact | Button alignment off, placeholder text wrong |

### Priority Decision Tree

```
Is it a security vulnerability or data loss? → P0
Does it block revenue (payment, checkout)? → P0
Does it block a core user flow with no workaround? → P1
Does it affect a core flow but has a workaround? → P2
Is it cosmetic or minor UX? → P3
```

---

## Boundary & Negative Test Patterns

### Numeric Inputs
- Zero, negative, minimum valid, maximum valid, above maximum
- Decimal precision (0.01, 0.001)
- Integer overflow values

### String Inputs
- Empty string, whitespace only, single character
- Maximum length, above maximum length
- Special characters: `<script>alert(1)</script>`, `'; DROP TABLE--`, `../../../etc/passwd`
- Unicode: emoji, RTL text, accented characters

### API Inputs
- Missing required fields
- Wrong data types (string where int expected)
- Exceeding length limits
- Malformed JSON / XML
- Invalid auth tokens (expired, malformed, wrong scope)
- Empty request body
- Extra/unexpected fields

### Date/Time Inputs
- Past dates, future dates, current date
- Leap year (Feb 29), month boundaries (Jan 31 → Feb 1)
- Timezone edge cases

---

## Good/Bad Examples

### Good Test Case

| Field | Value |
|-------|-------|
| TC-ID | TC-CART-001 |
| Title | Add single in-stock product to empty cart updates badge and total |
| Priority | P0 |
| Type | Functional |
| Preconditions | User logged in, cart empty, product "Widget-A" in stock (qty ≥ 1) |
| Test Data | Product: Widget-A, SKU: WA-001, Price: $29.99, Qty: 1 |
| Steps | 1. Navigate to /products/widget-a<br>2. Click "Add to Cart" button<br>3. Observe cart icon badge in header<br>4. Navigate to /cart |
| Expected | 1. Product page loads with price $29.99 and "Add to Cart" enabled<br>2. Success toast "Widget-A added to cart" appears within 2s<br>3. Cart badge updates from "0" to "1"<br>4. Cart page shows: Widget-A, qty 1, subtotal $29.99, total $29.99 |
| Postconditions | Cart contains 1 item, inventory not decremented until checkout |

### Bad Test Case (Avoid)

| Field | Value |
|-------|-------|
| TC-ID | TC-001 (missing module prefix) |
| Title | Test cart (vague, no expected outcome) |
| Priority | P2 (wrong: cart add is P0) |
| Type | (missing) |
| Preconditions | (missing) |
| Test Data | (missing) |
| Steps | 1. Add item to cart |
| Expected | Cart works |

**Why it's bad**: No module in ID, vague title, wrong priority, missing fields, non-reproducible steps, unmeasurable expected result.

---

## Example Test Cases by Module

### API Test Case

| Field | Value |
|-------|-------|
| TC-ID | TC-API-AUTH-001 |
| Title | POST /auth/login with valid credentials returns 200 and JWT token |
| Priority | P0 |
| Type | API |
| Preconditions | User account exists: test@example.com / ValidPass123! |
| Test Data | `{"email": "test@example.com", "password": "ValidPass123!"}` |
| Steps | 1. Send POST to /auth/login with test data<br>2. Validate response status<br>3. Validate response body schema |
| Expected | 1. Request accepted<br>2. Status 200 OK<br>3. Body contains `token` (JWT format), `expires_in` (integer), `user.email` matches input |

### Security Test Case

| Field | Value |
|-------|-------|
| TC-ID | TC-SEC-PAY-001 |
| Title | Payment endpoint rejects request without authentication |
| Priority | P0 |
| Type | Security |
| Preconditions | Valid order exists, no auth token in request |
| Test Data | Order ID: ORD-12345, no Authorization header |
| Steps | 1. Send POST to /payments with order data but no auth header<br>2. Validate response |
| Expected | 1. Request sent<br>2. Status 401 Unauthorized, no payment processed, no sensitive data in response body |
