# QA Testing Anti-Patterns

## Test Case Anti-Patterns

### Vague Steps

```
# Bad: Ambiguous, not reproducible
Steps: "Test the cart functionality"
Expected: "Cart works correctly"

# Good: Specific, reproducible
Steps:
  1. Navigate to /products/widget-a
  2. Click "Add to Cart" button
  3. Navigate to /cart
Expected:
  1. Product page loads with "Add to Cart" enabled
  2. Toast "Added to cart" appears, cart badge shows "1"
  3. Cart page shows Widget-A, qty 1, total $29.99
```

### Missing Negative Cases

```
# Bad: Only happy path
Test: "User can log in with valid credentials"

# Good: Cover failure modes
Tests:
- TC-AUTH-001: Login with valid credentials → success
- TC-AUTH-002: Login with wrong password → error message, no lockout
- TC-AUTH-003: Login with nonexistent email → same error (no enumeration)
- TC-AUTH-004: Login after 5 failed attempts → account locked
- TC-AUTH-005: Login with SQL injection in email → sanitized, error
```

### Wrong Priority Assignment

```
# Bad: Payment failure marked P2
TC-PAY-001 | Payment gateway timeout | P2

# Good: Payment failure is always P0/P1
TC-PAY-001 | Payment gateway timeout | P0 (revenue-blocking)
```

---

## Automation Anti-Patterns

### Sleep Instead of Wait

```python
# Bad: Flaky, slow
import time
time.sleep(5)
element = driver.find_element(By.ID, "result")

# Good: Explicit wait
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
element = WebDriverWait(driver, 10).until(
    EC.visibility_of_element_located((By.ID, "result"))
)
```

### Hardcoded Test Data

```python
# Bad: Data buried in test
def test_add_to_cart(self, api_client):
    resp = api_client.post("/cart/items", json={
        "product_id": "PROD-123",
        "quantity": 2
    })

# Good: Data in fixtures
@pytest.fixture
def cart_item():
    return {"product_id": "PROD-123", "quantity": 2}

def test_add_to_cart(self, api_client, cart_item):
    resp = api_client.post("/cart/items", json=cart_item)
```

### No Assertion Messages

```python
# Bad: Unhelpful failure output
assert resp.status_code == 201

# Good: Clear failure context
assert resp.status_code == 201, (
    f"Expected 201 Created, got {resp.status_code}: {resp.text}"
)
```

### Shared Mutable State

```python
# Bad: Tests depend on execution order
class TestCart:
    cart_id = None  # Shared across tests!

    def test_create_cart(self, api_client):
        resp = api_client.post("/cart")
        TestCart.cart_id = resp.json()["id"]

    def test_add_item(self, api_client):
        # Fails if test_create_cart didn't run first
        api_client.post(f"/cart/{TestCart.cart_id}/items", ...)

# Good: Each test creates own state
class TestCart:
    @pytest.fixture
    def cart_id(self, api_client):
        resp = api_client.post("/cart")
        return resp.json()["id"]

    def test_add_item(self, api_client, cart_id):
        resp = api_client.post(f"/cart/{cart_id}/items", ...)
```

### Testing Implementation, Not Behavior

```python
# Bad: Coupled to internal implementation
def test_cart_uses_redis_cache(self, api_client):
    api_client.post("/cart/items", json=item)
    assert redis_client.exists("cart:user123")

# Good: Test observable behavior
def test_cart_persists_across_sessions(self, api_client):
    api_client.post("/cart/items", json=item)
    # New session, same user
    resp = api_client.get("/cart")
    assert len(resp.json()["items"]) == 1
```

### No Cleanup / Teardown

```python
# Bad: Test data leaks
def test_create_order(self, api_client):
    resp = api_client.post("/orders", json=order_data)
    assert resp.status_code == 201
    # Order left in DB!

# Good: Cleanup with fixture
@pytest.fixture
def created_order(self, api_client, order_data):
    resp = api_client.post("/orders", json=order_data)
    order_id = resp.json()["id"]
    yield order_id
    api_client.delete(f"/orders/{order_id}")
```

---

## Code Review Anti-Patterns

### Bare Except

```python
# Bad
try:
    process_payment(order)
except:
    pass

# Good
try:
    process_payment(order)
except PaymentGatewayError as e:
    logger.error(f"Payment failed for order {order.id}: {e}")
    raise
except ValidationError as e:
    return {"error": str(e)}, 400
```

### SQL Injection

```python
# Bad: String concatenation
query = f"SELECT * FROM products WHERE id = '{product_id}'"
cursor.execute(query)

# Good: Parameterized query
cursor.execute("SELECT * FROM products WHERE id = %s", (product_id,))
```

### Sensitive Data Logging

```python
# Bad: Logs credit card
logger.info(f"Processing payment: card={card_number}, cvv={cvv}")

# Good: Mask sensitive data
logger.info(f"Processing payment: card=****{card_number[-4:]}")
```

---

## Test Plan Anti-Patterns

### No Exit Criteria

```
# Bad: "Testing is done when we feel confident"

# Good:
Exit Criteria:
- All P0/P1 test cases passing
- No open P0/P1 defects
- Code coverage ≥80%
- Performance tests within SLA thresholds
```

### No Risk Assessment

```
# Bad: No risks section

# Good:
| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Payment gateway sandbox down | Blocks payment tests | Medium | Mock gateway responses |
| Test data corruption | False failures | Low | DB snapshot before each run |
| Flaky UI tests | False negatives | High | Retry mechanism + screenshot on failure |
```
