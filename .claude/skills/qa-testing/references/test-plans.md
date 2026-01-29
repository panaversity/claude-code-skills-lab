# Test Plan & Strategy Patterns

## Test Plan Structure

```markdown
# Test Plan: [Project/Feature Name]

## 1. Overview
- **Objective**: What is being tested and why
- **Scope**: In-scope and out-of-scope items
- **References**: Requirements docs, user stories, designs

## 2. Test Scope
### In Scope
- List of features/modules to test
### Out of Scope
- Explicitly excluded items with rationale

## 3. Test Types
| Type | Coverage | Tools |
|------|----------|-------|
| Functional | Business logic, workflows | pytest |
| API | Endpoints, contracts | pytest + requests |
| UI | User flows, visual | Playwright/Selenium |
| Integration | Service interactions | pytest |
| Performance | Load, stress | locust/k6 |
| Security | OWASP Top 10 | manual + automated |

## 4. Test Environment
- **URL**: staging/QA environment URL
- **Database**: Test DB details
- **Test Data**: How test data is managed
- **Dependencies**: External services, mocks

## 5. Entry & Exit Criteria
### Entry
- Code deployed to test environment
- Unit tests passing (>80% coverage)
- Test data prepared
### Exit
- All P0/P1 tests passing
- No open P0/P1 defects
- Test report approved

## 6. Schedule
| Phase | Duration | Activities |
|-------|----------|------------|
| Preparation | ... | Test case design, data setup |
| Execution | ... | Test runs |
| Reporting | ... | Results analysis, report |

## 7. Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| Third-party API downtime | Blocks integration tests | Use mock servers |
| Test data corruption | Re-run failures | DB snapshots before runs |

## 8. Deliverables
- Test cases document
- Test execution report
- Defect log
- Test summary report
```

## Test Strategy Structure

```markdown
# Test Strategy: [Project Name]

## 1. Testing Approach
- Risk-based testing (prioritize by business impact)
- Shift-left: unit/integration tests in CI pipeline
- Automation-first for regression, manual for exploratory

## 2. Test Levels
| Level | Scope | Owner | Automation |
|-------|-------|-------|------------|
| Unit | Functions/methods | Dev | 100% |
| Integration | Service interactions | Dev/QA | 80%+ |
| System | End-to-end flows | QA | 60%+ |
| Acceptance | Business requirements | QA/PO | Key flows |

## 3. Automation Strategy
- **Framework**: pytest
- **API testing**: requests + JSON schema validation
- **UI testing**: Playwright (preferred) or Selenium
- **CI integration**: Run on every PR
- **Reporting**: pytest-html or allure

## 4. Defect Management
- **Tracking**: Jira / GitHub Issues
- **Severity**: S1 (blocker) → S4 (cosmetic)
- **SLA**: S1: 4h, S2: 24h, S3: sprint, S4: backlog

## 5. Test Data Strategy
- Factories/fixtures for reproducible data
- Isolated test database per run
- No production data in tests

## 6. Reporting
- Daily: execution progress
- Per-cycle: pass/fail metrics, defect trends
- Final: coverage summary, risk assessment
```
