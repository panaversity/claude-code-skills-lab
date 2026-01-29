---
name: qa-testing
description: |
  Comprehensive QA testing skill for e-commerce web applications and APIs using Python.
  This skill should be used when the user needs help with:
  (1) Writing test cases from requirements, user stories, or acceptance criteria with structured format (ID, priority, steps, expected results),
  (2) Creating test plans covering scope, objectives, environment, entry/exit criteria, risks, and deliverables,
  (3) Creating test strategies defining test types, automation approach, defect management, and reporting,
  (4) Generating Python automation scripts using pytest, requests, Playwright, or Selenium with proper fixtures and assertions,
  (5) Creating automation test reports with pass/fail metrics and recommendations,
  (6) Reviewing code for testability, quality, error handling, security vulnerabilities, and best practices.
  Domain focus: e-commerce (cart, checkout, payments, inventory, promotions, auth, catalog, orders), RESTful APIs, web applications.
---

# QA Testing

## What This Skill Does

- Write structured test cases from requirements, user stories, or acceptance criteria
- Create test plans and test strategies
- Generate Python automation scripts (pytest, requests, Playwright, Selenium)
- Create automation test reports with pass/fail metrics
- Review code for testability, security, error handling, and best practices

## What This Skill Does NOT Do

- Execute tests in live/production environments
- Set up CI/CD pipelines or infrastructure
- Manage test data in databases directly
- Perform actual penetration testing or load testing
- Deploy or configure test environments

Domain focus is e-commerce, but patterns are adaptable to other domains by substituting the module coverage in `references/test-cases.md`.

---

## Before Implementation

Gather context to ensure successful implementation:

| Source | Gather |
|--------|--------|
| **Codebase** | Existing test structure, frameworks in use, project conventions |
| **Conversation** | User's specific module, requirements, constraints |
| **Skill References** | Domain patterns from `references/` |
| **User Guidelines** | Project-specific conventions, team standards |

Ensure all required context is gathered before implementing.
Only ask user for THEIR specific requirements — domain expertise is embedded in this skill's references. Do NOT research domain basics at runtime.

---

## Required Clarifications

Ask about the USER'S context before proceeding:

1. **Task type**: "What do you need?"
   - Test cases → follow Test Cases workflow
   - Test plan/strategy → follow Planning workflow
   - Automation scripts → follow Automation workflow
   - Test report → follow Reporting workflow
   - Code review → follow Review workflow

2. **Module/feature**: "Which module or feature?" (e.g., cart, checkout, payments, auth, catalog, orders, promotions)

3. **Existing setup**: "Any existing test framework or structure?"
   - Determines whether to scaffold from scratch or integrate

4. **Constraints**: "Any specific requirements?" (coverage targets, compliance, frameworks)

## Optional Clarifications

Ask only when relevant to the task:

5. **Coverage target**: "Any minimum coverage requirement?" (default: 80%)
6. **Reporting format**: "pytest-html or allure?" (default: pytest-html)
7. **UI framework preference**: "Playwright or Selenium?" (default: Playwright)

## If User Skips Clarifications

- **Task type**: Required — explain why needed and ask again simply
- **Module**: Infer from conversation context if possible; otherwise ask
- **Existing setup**: Assume new project, scaffold from scratch
- **Constraints**: Proceed with skill defaults
- **Optional questions**: Proceed with defaults noted above

---

## Workflow

Determine task type and follow the corresponding path:

```
User request
    │
    ├─ "Write test cases" ──────→ references/test-cases.md
    │                              → Structured tabular output
    │
    ├─ "Create test plan" ──────→ references/test-plans.md (Test Plan section)
    │
    ├─ "Create test strategy" ──→ references/test-plans.md (Strategy section)
    │
    ├─ "Write automation" ──────→ references/automation.md
    │   ├─ API tests? ──→ requests + pytest pattern
    │   ├─ UI tests?  ──→ Playwright (preferred) or Selenium
    │   └─ Both?      ──→ Full project structure
    │
    ├─ "Create test report" ────→ references/automation.md (Report Template)
    │
    └─ "Review code" ──────────→ references/code-review.md
        ├─ Testability assessment
        ├─ Security review (OWASP/PCI-DSS)
        └─ Structured findings output
```

---

## Core Technologies

| Tool | Purpose | When to Use |
|------|---------|-------------|
| **pytest** | Test framework | Always (fixtures, markers, parametrize) |
| **requests** | API/REST testing | HTTP endpoint testing |
| **Playwright** | UI testing (preferred) | Modern web apps, async support needed |
| **Selenium** | UI testing (alternative) | Legacy apps, user already using it |
| **jsonschema** | Response validation | API contract testing |
| **pytest-html** | Reporting | HTML test reports |

---

## Standards Enforcement

### Must Follow

- [ ] Every test case has TC-ID, title, priority, preconditions, steps, expected results
- [ ] Test IDs follow `TC-<MODULE>-<NNN>` convention
- [ ] Priority assigned using P0-P3 scale based on business impact
- [ ] Automation uses pytest with class-based organization
- [ ] Page Object Model for all UI tests
- [ ] Session-scoped fixtures for auth tokens
- [ ] `@pytest.mark.parametrize` for data-driven tests
- [ ] JSON schema validation for API response contracts
- [ ] Test isolation (no shared mutable state between tests)
- [ ] Boundary and negative test cases for every input

### Must Avoid

- Bare `except:` clauses (always catch specific exceptions)
- Hardcoded test data in test methods (use fixtures/parametrize)
- `time.sleep()` in UI tests (use explicit waits)
- Shared mutable state between tests
- Testing implementation details instead of behavior
- Skipping negative/boundary test cases
- Assertions without descriptive messages on failures

See `references/anti-patterns.md` for detailed anti-patterns with examples.

---

## Output Formats

| Task | Format |
|------|--------|
| Test cases | Structured table (TC-ID, Title, Priority, Steps, Expected) |
| Test plans | Markdown with numbered sections |
| Test strategies | Markdown with tables for test levels and automation |
| Automation scripts | Python with pytest, proper structure and docstrings |
| Test reports | Markdown with summary metrics tables |
| Code reviews | Findings table (Critical/Major/Minor) + testability score |

---

## Output Checklist

Before delivering any output, verify:

### Test Cases
- [ ] Every test case has all required fields (TC-ID through Expected Result)
- [ ] Includes positive, negative, and boundary cases
- [ ] Priority reflects business impact (P0 for payment/security failures)
- [ ] Steps are specific and reproducible

### Automation Scripts
- [ ] Runs without syntax errors
- [ ] Uses fixtures for setup/teardown
- [ ] Assertions have descriptive failure messages
- [ ] Follows project structure conventions
- [ ] Includes pytest markers (smoke, regression, api, ui)

### Test Plans/Strategies
- [ ] Entry and exit criteria defined
- [ ] Risks identified with mitigations
- [ ] All required modules covered

### Code Reviews
- [ ] Security checklist applied (OWASP Top 10, PCI-DSS for payments)
- [ ] Findings categorized by severity
- [ ] Each finding has specific remediation

---

## Official Documentation

| Resource | URL | Use For |
|----------|-----|---------|
| pytest | https://docs.pytest.org/ | Framework reference, fixtures, markers |
| Playwright Python | https://playwright.dev/python/ | UI testing API, selectors, assertions |
| Selenium | https://www.selenium.dev/documentation/ | WebDriver API, waits, locators |
| requests | https://requests.readthedocs.io/ | HTTP client, sessions, auth |
| jsonschema | https://python-jsonschema.readthedocs.io/ | Schema validation |
| OWASP Top 10 | https://owasp.org/www-project-top-ten/ | Security testing checklist |
| PCI-DSS | https://www.pcisecuritystandards.org/ | Payment data compliance |
| pytest-html | https://pytest-html.readthedocs.io/ | HTML report generation |

## Unlisted Scenarios

For patterns not documented in this skill's references:

1. Fetch from official docs (see URLs above)
2. Apply the same quality standards (Must Follow / Must Avoid)
3. Follow established test structure patterns from `references/automation.md`

---

## Reference Files

| File | When to Read |
|------|--------------|
| `references/test-cases.md` | Writing test cases (format, module coverage, examples) |
| `references/test-plans.md` | Creating test plans or test strategies |
| `references/automation.md` | Generating Python automation scripts or test reports |
| `references/code-review.md` | Reviewing code for testability, security, quality |
| `references/anti-patterns.md` | Avoiding common QA testing mistakes |
