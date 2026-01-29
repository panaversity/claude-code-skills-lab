# Code Review for Testability

## Table of Contents

- Review Checklist
- Security Checklist (E-Commerce / PCI-DSS)
- Good/Bad Examples
- Review Output Format
- Remediation Patterns

---

## Review Checklist

### Testability
- [ ] Functions have single responsibility
- [ ] Dependencies are injectable (no hard-coded URLs, DB connections)
- [ ] Business logic separated from I/O
- [ ] No global state mutation
- [ ] Functions return values (not just side effects)
- [ ] Complex conditionals extracted into named functions
- [ ] No hidden dependencies (imports inside functions that change behavior)

### Error Handling
- [ ] All external calls wrapped in try/except
- [ ] Specific exception types (not bare except)
- [ ] Meaningful error messages with context
- [ ] Errors logged before re-raising
- [ ] HTTP errors return appropriate status codes
- [ ] Validation errors return field-level details
- [ ] No silent failures (catch + pass)

### Security (E-Commerce Focus)
- [ ] No SQL injection (parameterized queries / ORM)
- [ ] No XSS (output encoding, CSP headers)
- [ ] Input validation on all user data
- [ ] Authentication on protected endpoints
- [ ] Authorization checks (user can only access own data)
- [ ] Sensitive data not logged (passwords, tokens, card numbers)
- [ ] HTTPS enforced
- [ ] Rate limiting on auth endpoints
- [ ] CSRF protection on state-changing operations
- [ ] Payment data handled per PCI-DSS (never stored raw)
- [ ] Session tokens rotated after login
- [ ] Password hashing (bcrypt/argon2, not MD5/SHA1)

### API Best Practices
- [ ] Consistent response format (envelope pattern)
- [ ] Proper HTTP methods (GET/POST/PUT/DELETE)
- [ ] Meaningful status codes (201 for create, 204 for delete)
- [ ] Pagination on list endpoints
- [ ] Input validation with clear error messages
- [ ] Versioned endpoints
- [ ] Idempotency keys on payment operations
- [ ] CORS properly configured

### Code Quality
- [ ] No code duplication (DRY)
- [ ] Meaningful variable/function names
- [ ] No magic numbers/strings (use constants)
- [ ] Functions under 30 lines
- [ ] No deeply nested logic (max 3 levels)
- [ ] Type hints on function signatures

---

## Security Checklist (PCI-DSS for E-Commerce)

| Requirement | Check | Severity if Missing |
|-------------|-------|---------------------|
| Card numbers never stored in logs | Grep for card patterns in log statements | Critical |
| Card data encrypted in transit | HTTPS enforced, no HTTP fallback | Critical |
| Card data not in URL parameters | No GET requests with card data | Critical |
| CVV never stored (even encrypted) | No CVV in database models | Critical |
| Access control on payment endpoints | Auth + authz checks | Critical |
| Audit trail for payment operations | Logging for payment CRUD | Major |
| Token-based card storage (Stripe/Braintree) | No raw card handling | Major |

---

## Good/Bad Examples

### Error Handling

```python
# Bad: Silent failure
try:
    process_payment(order)
except:
    pass

# Good: Specific handling with context
try:
    process_payment(order)
except PaymentGatewayTimeout as e:
    logger.error(f"Payment timeout for order {order.id}: {e}")
    return {"error": "Payment service temporarily unavailable"}, 503
except InvalidCardError as e:
    logger.warning(f"Invalid card for order {order.id}: {e}")
    return {"error": "Invalid card details", "field": "card_number"}, 400
except Exception as e:
    logger.exception(f"Unexpected payment error for order {order.id}")
    raise
```

### Dependency Injection

```python
# Bad: Hard-coded dependency
def get_product(product_id):
    db = psycopg2.connect("host=prod-db.example.com dbname=store")
    return db.execute("SELECT * FROM products WHERE id = %s", (product_id,))

# Good: Injectable dependency
def get_product(product_id, db_connection):
    return db_connection.execute(
        "SELECT * FROM products WHERE id = %s", (product_id,)
    )
```

### SQL Injection

```python
# Bad: String interpolation
query = f"SELECT * FROM users WHERE email = '{email}'"

# Good: Parameterized query
query = "SELECT * FROM users WHERE email = %s"
cursor.execute(query, (email,))

# Good: ORM
user = User.query.filter_by(email=email).first()
```

### Authorization

```python
# Bad: No ownership check
@app.get("/orders/{order_id}")
def get_order(order_id):
    return Order.query.get(order_id)

# Good: Verify ownership
@app.get("/orders/{order_id}")
def get_order(order_id, current_user):
    order = Order.query.get(order_id)
    if order.user_id != current_user.id:
        raise HTTPException(403, "Access denied")
    return order
```

### Sensitive Data

```python
# Bad: Logs credit card
logger.info(f"Payment: card={card_number}, amount={amount}")

# Good: Mask sensitive data
logger.info(f"Payment: card=****{card_number[-4:]}, amount={amount}")
```

---

## Review Output Format

```markdown
## Code Review: [File/Module]

### Summary
[1-2 sentence overview of code quality and key concerns]

### Findings

#### Critical (Must Fix Before Release)
| # | Issue | Location | Recommendation |
|---|-------|----------|----------------|
| 1 | SQL injection risk | file.py:42 | Use parameterized query |

#### Major (Fix in Current Sprint)
| # | Issue | Location | Recommendation |
|---|-------|----------|----------------|

#### Minor (Fix When Convenient)
| # | Issue | Location | Recommendation |
|---|-------|----------|----------------|

### Testability Score: X/10

| Category | Score (0-2) | Notes |
|----------|-------------|-------|
| Single Responsibility | X | |
| Dependency Injection | X | |
| State Management | X | |
| Error Handling | X | |
| Separation of Concerns | X | |

**Overall**: X/10 — [Brief justification]
```

---

## Remediation Patterns

| Issue | Fix | Example |
|-------|-----|---------|
| Bare except | Catch specific exceptions | `except ValueError as e:` |
| SQL injection | Parameterized queries or ORM | `cursor.execute(sql, (param,))` |
| Hardcoded secrets | Environment variables | `os.getenv("DB_PASSWORD")` |
| No input validation | Validate at boundary | Pydantic models, JSON schema |
| God function (>50 lines) | Extract into smaller functions | One function per responsibility |
| No auth check | Add middleware/decorator | `@require_auth` decorator |
| Sensitive data in logs | Mask or omit | `card=****{last4}` |
| No rate limiting | Add rate limit middleware | `@rate_limit(max=5, per=60)` |
| Missing CSRF | Add CSRF tokens | Framework CSRF middleware |
| Password in plaintext | Hash with bcrypt | `bcrypt.hashpw(password, salt)` |
