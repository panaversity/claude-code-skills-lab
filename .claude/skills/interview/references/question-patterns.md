# Question Patterns

Techniques for discovering WHY (intent) and surfacing assumptions.

---

## Core Purpose

Questions serve two goals:
1. **Discover WHY** - Uncover intent behind surface requests
2. **Surface assumptions** - Expose and validate what AI is assuming

---

## Discovering WHY

### The WHY Questions

| Question | Discovers |
|----------|-----------|
| "What problem does this solve?" | Real need |
| "Why is this needed now?" | Urgency, context |
| "What happens if we don't do this?" | Stakes, priority |
| "Who benefits and how?" | Users, value |
| "What led to this request?" | Background, triggers |
| "What does success look like?" | Goals, criteria |

### Laddering Technique

Dig progressively deeper into abstract requests:

```
Surface request
  → "Why do you need that?"
    → Reason
      → "Why is that important?"
        → Deeper reason
          → Root intent
```

**Example:**
```
"Add dark mode"
  → Why? → "Reduce eye strain"
    → Why an issue? → "Users work at night"
      → Why at night? → "Support team is 24/7"
        → Intent: Accessibility for shift workers
```

### 5 Whys Technique

Keep asking "why" until you hit root cause:

```
Request → Why? → Reason → Why? → Deeper → Why? → Root
```

**Example:**
```
"Add export to PDF"
  → Why? → "Need to share reports"
    → Why share? → "Stakeholders review weekly"
      → Why PDF? → "They print them"
        → Root: Stakeholders need printable weekly reports
```

### Intent vs Solution

Users often state solutions, not problems:

| User Says (Solution) | Ask to Find (Intent) |
|---------------------|----------------------|
| "Add a button for X" | "What should happen when users do X?" |
| "Make it faster" | "What's slow? What speed is acceptable?" |
| "Use Redis" | "What problem are you solving with caching?" |

---

## Surfacing Assumptions

### Why Assumptions Matter

AI always makes assumptions. Unvalidated assumptions → wrong output.

### The Assumption Declaration

After initial understanding, explicitly state assumptions:

```
"I'm assuming:
- [Assumption 1]
- [Assumption 2]
- [Assumption 3]

Are these correct?"
```

### Assumption Categories

| Category | Example Questions |
|----------|-------------------|
| **Context** | "Is this for web, mobile, or both?" |
| **Users** | "Who are the users? Technical or non-technical?" |
| **Scale** | "How many users/requests/items are we talking?" |
| **Scope** | "Should this include X, or is that separate?" |
| **Integration** | "Does this need to work with existing system Y?" |
| **Quality** | "Any specific performance/security requirements?" |
| **Timeline** | "Is there a deadline? Can this be phased?" |

### Probing Hidden Assumptions

When user gives vague terms, probe:

| Vague Term | Probe |
|------------|-------|
| "Fast" | "What response time is acceptable?" |
| "Scalable" | "What scale? 100 users? 1 million?" |
| "Simple" | "Simple for whom? What complexity is okay?" |
| "Secure" | "What threats? What compliance requirements?" |
| "Good UX" | "What makes UX good for your users?" |

---

## Question Types

### Open Questions
**Purpose**: Explore, gather context
**Pattern**: "What...", "How...", "Tell me about..."
**Use when**: Starting discovery, exploring WHY

### Closed Questions
**Purpose**: Confirm, validate
**Pattern**: "Is...", "Should...", "Do you want..."
**Use when**: Validating assumptions, confirming understanding

### Choice Questions
**Purpose**: Help decide between options
**Pattern**: "Would you prefer A, B, or C?"
**Use when**: Multiple valid approaches exist

### Probing Questions
**Purpose**: Dig deeper into vague answers
**Pattern**: "When you say X, what do you mean?"
**Use when**: Answer contains undefined terms

---

## Question Pacing

**Batch size**: 1-4 questions maximum

**Flow**:
1. Start with WHY questions (most important)
2. Surface assumptions based on answers
3. Probe vague terms
4. Confirm understanding

**Adapt depth**:
- Simple request → Quick check, proceed
- Complex/ambiguous → Full discovery
- High stakes → Thorough validation

---

## Signs You've Discovered Enough

### Surface Understanding (NOT ready)
- Know WHAT user asked for
- Don't know WHY they want it
- Have unvalidated assumptions

### Deep Understanding (READY)
- Know WHY (intent/problem)
- Know WHAT (agreed solution)
- Assumptions validated
- Scope boundaries clear
- User confirmed accuracy

**Test**: Could you explain to someone else WHY user wants this and WHAT you'll do, without guessing?
