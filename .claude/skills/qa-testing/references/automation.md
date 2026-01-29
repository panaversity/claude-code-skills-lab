# Python Automation Patterns

## Table of Contents

- Project Structure
- pytest Configuration
- Fixtures
- API Testing Patterns
- JSON Schema Validation
- Playwright UI Testing
- Selenium UI Testing
- Error Handling in Tests
- Test Report Template
- Dependencies

---

## Project Structure

```
tests/
├── conftest.py          # Shared fixtures (base_url, auth_token, api_client)
├── api/
│   ├── conftest.py      # API-specific fixtures
│   ├── test_auth.py
│   ├── test_cart.py
│   └── test_orders.py
├── ui/
│   ├── conftest.py      # UI-specific fixtures (browser, page)
│   ├── pages/           # Page Object Model
│   │   ├── base_page.py
│   │   ├── login_page.py
│   │   └── cart_page.py
│   ├── test_login.py
│   └── test_checkout.py
├── data/
│   └── test_data.json   # Externalized test data
└── utils/
    ├── api_client.py    # Reusable API client wrapper
    └── helpers.py       # Shared utilities
```

---

## pytest Configuration

```ini
# pytest.ini
[pytest]
markers =
    smoke: Quick sanity checks (< 2min total)
    regression: Full regression suite
    api: API tests
    ui: UI tests
    slow: Long-running tests (> 30s each)
    security: Security-focused tests
testpaths = tests
addopts = -v --tb=short --strict-markers -ra
```

**Marker usage**: Always decorate tests with appropriate markers for selective execution.

```python
@pytest.mark.smoke
@pytest.mark.api
def test_health_check(api_client):
    ...
```

---

## Fixtures

### Session-Level (shared across all tests)

```python
import pytest
import requests

@pytest.fixture(scope="session")
def base_url():
    """Base API URL from environment or default."""
    import os
    return os.getenv("TEST_BASE_URL", "https://api.staging.example.com/v1")

@pytest.fixture(scope="session")
def auth_token(base_url):
    """Authenticate once per session, reuse token."""
    resp = requests.post(f"{base_url}/auth/login", json={
        "email": "test@example.com",
        "password": "TestPass123!"
    })
    assert resp.status_code == 200, f"Auth failed: {resp.status_code} {resp.text}"
    return resp.json()["token"]

@pytest.fixture(scope="session")
def api_client(base_url, auth_token):
    """Authenticated requests session."""
    session = requests.Session()
    session.base_url = base_url
    session.headers.update({
        "Authorization": f"Bearer {auth_token}",
        "Content-Type": "application/json"
    })
    yield session
    session.close()
```

### Function-Level (fresh per test)

```python
@pytest.fixture
def sample_product():
    """Standard test product data."""
    return {
        "name": "Test Widget",
        "price": 29.99,
        "sku": "TEST-001",
        "quantity": 100
    }

@pytest.fixture
def created_cart(api_client):
    """Create a cart and clean up after test."""
    resp = api_client.post(f"{api_client.base_url}/cart")
    assert resp.status_code == 201, f"Cart creation failed: {resp.text}"
    cart_id = resp.json()["id"]
    yield cart_id
    # Cleanup
    api_client.delete(f"{api_client.base_url}/cart/{cart_id}")
```

---

## API Testing Patterns

### CRUD Pattern

```python
import pytest

class TestCartAPI:
    """Cart API endpoint tests."""

    @pytest.mark.smoke
    @pytest.mark.api
    def test_add_item_to_cart(self, api_client, sample_product):
        """Add a single item to cart - verify response structure and data."""
        resp = api_client.post(f"{api_client.base_url}/cart/items", json={
            "product_id": sample_product["sku"],
            "quantity": 1
        })
        assert resp.status_code == 201, (
            f"Expected 201, got {resp.status_code}: {resp.text}"
        )
        data = resp.json()
        assert data["items"][0]["product_id"] == sample_product["sku"]
        assert data["items"][0]["quantity"] == 1

    @pytest.mark.api
    def test_add_item_unauthorized(self, base_url):
        """Unauthenticated request returns 401."""
        resp = requests.post(f"{base_url}/cart/items", json={
            "product_id": "TEST-001",
            "quantity": 1
        })
        assert resp.status_code == 401, (
            f"Expected 401 Unauthorized, got {resp.status_code}"
        )

    @pytest.mark.api
    @pytest.mark.parametrize("quantity,expected_status", [
        (0, 400),
        (-1, 400),
        (1001, 400),   # above max
        (None, 400),
    ])
    def test_add_item_invalid_quantities(self, api_client, quantity, expected_status):
        """Invalid quantities return 400 with error details."""
        resp = api_client.post(f"{api_client.base_url}/cart/items", json={
            "product_id": "TEST-001",
            "quantity": quantity
        })
        assert resp.status_code == expected_status, (
            f"Quantity {quantity}: expected {expected_status}, got {resp.status_code}"
        )
```

### Response Validation Pattern

```python
def assert_error_response(resp, expected_status, expected_field=None):
    """Reusable assertion for error responses."""
    assert resp.status_code == expected_status, (
        f"Expected {expected_status}, got {resp.status_code}: {resp.text}"
    )
    body = resp.json()
    assert "error" in body, f"Missing 'error' field in response: {body}"
    if expected_field:
        assert expected_field in body["error"].lower(), (
            f"Expected '{expected_field}' in error, got: {body['error']}"
        )
```

---

## JSON Schema Validation

```python
from jsonschema import validate, ValidationError
import pytest

PRODUCT_SCHEMA = {
    "type": "object",
    "required": ["id", "name", "price", "sku"],
    "properties": {
        "id": {"type": "integer"},
        "name": {"type": "string", "minLength": 1},
        "price": {"type": "number", "minimum": 0},
        "sku": {"type": "string", "pattern": "^[A-Z]+-\\d+$"}
    },
    "additionalProperties": True
}

@pytest.mark.api
def test_product_response_schema(api_client):
    """Product endpoint response matches expected schema."""
    resp = api_client.get(f"{api_client.base_url}/products/1")
    assert resp.status_code == 200
    try:
        validate(instance=resp.json(), schema=PRODUCT_SCHEMA)
    except ValidationError as e:
        pytest.fail(f"Schema validation failed: {e.message}")
```

---

## Playwright UI Testing

```python
import pytest
from playwright.sync_api import Page, expect

class LoginPage:
    """Page Object for login page."""

    def __init__(self, page: Page):
        self.page = page
        self.email_input = page.locator("#email")
        self.password_input = page.locator("#password")
        self.login_button = page.locator("button[type='submit']")
        self.error_message = page.locator(".error-message")

    def goto(self):
        self.page.goto("/login")
        self.page.wait_for_load_state("networkidle")

    def login(self, email: str, password: str):
        self.email_input.fill(email)
        self.password_input.fill(password)
        self.login_button.click()


class TestLogin:
    @pytest.mark.smoke
    @pytest.mark.ui
    def test_successful_login(self, page: Page):
        login_page = LoginPage(page)
        login_page.goto()
        login_page.login("test@example.com", "ValidPass123!")
        expect(page).to_have_url("/dashboard")

    @pytest.mark.ui
    def test_invalid_credentials(self, page: Page):
        login_page = LoginPage(page)
        login_page.goto()
        login_page.login("test@example.com", "wrong")
        expect(login_page.error_message).to_be_visible()
        expect(login_page.error_message).to_contain_text("Invalid")

    @pytest.mark.ui
    def test_empty_fields_shows_validation(self, page: Page):
        login_page = LoginPage(page)
        login_page.goto()
        login_page.login_button.click()
        expect(login_page.email_input).to_have_attribute("aria-invalid", "true")
```

---

## Selenium UI Testing

```python
import pytest
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

class LoginPage:
    """Page Object for login page (Selenium)."""

    def __init__(self, driver):
        self.driver = driver
        self.wait = WebDriverWait(driver, 10)

    def goto(self, base_url):
        self.driver.get(f"{base_url}/login")

    def login(self, email, password):
        self.wait.until(EC.visibility_of_element_located((By.ID, "email")))
        self.driver.find_element(By.ID, "email").send_keys(email)
        self.driver.find_element(By.ID, "password").send_keys(password)
        self.driver.find_element(By.CSS_SELECTOR, "button[type='submit']").click()

    @property
    def error_message(self):
        return self.wait.until(
            EC.visibility_of_element_located((By.CLASS_NAME, "error-message"))
        ).text


class TestLogin:
    @pytest.mark.ui
    def test_successful_login(self, driver, base_url):
        page = LoginPage(driver)
        page.goto(base_url)
        page.login("test@example.com", "ValidPass123!")
        WebDriverWait(driver, 10).until(EC.url_contains("/dashboard"))
        assert "/dashboard" in driver.current_url

    @pytest.mark.ui
    def test_screenshot_on_failure(self, driver, base_url, request):
        """Example: capture screenshot on test failure."""
        page = LoginPage(driver)
        page.goto(base_url)
        page.login("test@example.com", "wrong")
        try:
            assert page.error_message == "Invalid credentials"
        except AssertionError:
            driver.save_screenshot(f"screenshots/{request.node.name}.png")
            raise
```

---

## Error Handling in Tests

### Retry Pattern for Flaky External Services

```python
import pytest
from tenacity import retry, stop_after_attempt, wait_exponential

@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, max=10))
def call_external_api(api_client, endpoint):
    """Retry flaky external API calls."""
    resp = api_client.get(f"{api_client.base_url}{endpoint}")
    resp.raise_for_status()
    return resp
```

### Soft Assertions (collect all failures)

```python
class SoftAssert:
    """Collect multiple assertion failures before failing test."""

    def __init__(self):
        self.errors = []

    def check(self, condition, message):
        if not condition:
            self.errors.append(message)

    def assert_all(self):
        if self.errors:
            pytest.fail("Soft assertion failures:\n" + "\n".join(self.errors))

# Usage
def test_order_response(api_client, order_id):
    resp = api_client.get(f"{api_client.base_url}/orders/{order_id}")
    data = resp.json()
    sa = SoftAssert()
    sa.check(resp.status_code == 200, f"Status: {resp.status_code}")
    sa.check("id" in data, "Missing 'id' field")
    sa.check("total" in data, "Missing 'total' field")
    sa.check(data.get("status") in ["pending", "confirmed"], f"Bad status: {data.get('status')}")
    sa.assert_all()
```

---

## Test Report Template

```markdown
# Test Execution Report

## Summary
| Metric | Value |
|--------|-------|
| Total Tests | X |
| Passed | X (X%) |
| Failed | X (X%) |
| Skipped | X (X%) |
| Blocked | X (X%) |
| Duration | Xm Xs |
| Environment | staging / QA |
| Date | YYYY-MM-DD |
| Build | vX.Y.Z / commit SHA |

## Failed Tests
| # | Test | Module | Error Summary | Priority | Jira |
|---|------|--------|---------------|----------|------|
| 1 | test_name | module | AssertionError: expected 200 got 500 | P1 | PROJ-123 |

## Coverage by Module
| Module | Total | Passed | Failed | Skipped | Pass Rate |
|--------|-------|--------|--------|---------|-----------|
| Cart | X | X | X | X | X% |
| Auth | X | X | X | X | X% |
| Payments | X | X | X | X | X% |

## Defect Summary
| Severity | Open | Fixed | Total |
|----------|------|-------|-------|
| S1 (Blocker) | X | X | X |
| S2 (Critical) | X | X | X |
| S3 (Major) | X | X | X |
| S4 (Minor) | X | X | X |

## Recommendations
1. [Specific action items based on failures]
2. [Risk areas needing additional testing]
3. [Environment or data issues encountered]

## Go/No-Go Assessment
- **Recommendation**: GO / NO-GO
- **Rationale**: [Based on exit criteria]
```

---

## Dependencies

```
pytest>=7.0
requests>=2.28
playwright>=1.40
selenium>=4.0
jsonschema>=4.0
pytest-html>=4.0
tenacity>=8.0
```
