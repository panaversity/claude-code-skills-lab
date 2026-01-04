# Anti-Patterns

Common mistakes in discovery conversations and how to avoid them.

---

## Discovery Anti-Patterns

### 1. Scripted Questioning

**Symptom**: Following a fixed list of questions regardless of context.

**Problem**: Misses the specific gaps in THIS situation. Wastes time on irrelevant questions.

**Fix**:
```
Identify what's ACTUALLY unclear in this request.
Generate questions to fill THOSE specific gaps.
Adapt based on answers received.
```

### 2. Assuming User Lacks Expertise

**Symptom**: Researching and explaining domain basics when user is an expert.

**Problem**: Wastes user's time, feels condescending.

**Fix**:
```
Ask: "Do you have experience with [domain]?"
If yes: Leverage their expertise, ask for their knowledge
If no: Then research and explain
```

### 3. Jumping to Implementation

**Symptom**: Starting work before understanding is confirmed.

**Problem**: Builds wrong thing, wastes effort, frustrates user.

**Fix**:
```
Always summarize understanding first.
Get explicit confirmation: "Does this capture what you want?"
Only proceed after user confirms.
```

### 4. Solution Anchoring

**Symptom**: Asking questions that validate a pre-decided solution.

**Problem**: Misses better alternatives, biases the discovery.

**Fix**:
```
Explore the problem space first.
Present multiple options when they exist.
Let user's needs drive the solution.
```

---

## Questioning Anti-Patterns

### 5. Question Overload

**Symptom**: Asking 5+ questions at once.

**Problem**: Overwhelms user, gets rushed/incomplete answers.

**Fix**:
```
1-4 questions maximum per round.
Build on answers before asking more.
Most important questions first.
```

### 6. Leading Questions

**Symptom**: "Don't you think we should use X?"

**Problem**: User agrees without genuine consideration.

**Fix**:
```
Present options neutrally.
"We could use X, Y, or Z. What fits your needs?"
Let user choose, don't push.
```

### 7. Accepting Vagueness

**Symptom**: User says "make it fast" → "Okay, got it."

**Problem**: "Fast" means different things. Undefined requirements cause problems later.

**Fix**:
```
Probe vague terms:
"When you say 'fast', what response time is acceptable?"
"What does 'easy to use' mean for your users?"
Quantify whenever possible.
```

### 8. Re-asking the Obvious

**Symptom**: Asking about things user already explained.

**Problem**: Shows AI wasn't listening. Wastes time.

**Fix**:
```
Track what's already clear from context.
Only ask about actual gaps.
Reference what user said: "You mentioned X - should that include Y?"
```

---

## Context Anti-Patterns

### 9. Codebase Assumption

**Symptom**: Asking about code/files when user is brainstorming or starting fresh.

**Problem**: Wrong context assumed. Confuses user.

**Fix**:
```
Assess what context exists FIRST.
Fresh project? → Focus on goals, constraints
Existing work? → Then examine what exists
Brainstorming? → Explore possibilities
```

### 10. Specs-Only Mindset

**Symptom**: Treating every discovery as "requirements gathering."

**Problem**: Not all work needs formal specs. Overkill for simple tasks.

**Fix**:
```
Match formality to situation:
- Simple request → Quick clarification, proceed
- Complex work → Thorough discovery
- Brainstorming → Exploratory conversation
Goal is understanding, not documentation.
```

### 11. Ignoring User's Time

**Symptom**: Extensive questioning for simple requests.

**Problem**: User wanted quick help, not an interview.

**Fix**:
```
Gauge complexity first.
Simple + clear → Just do it
Ambiguous → Clarify specific gaps only
Complex → Full discovery warranted
```

---

## Research Anti-Patterns

### 12. Researching When User Knows

**Symptom**: Web searching domain basics when user is the expert.

**Problem**: Wastes time, ignores valuable user knowledge.

**Fix**:
```
Ask about user's expertise first.
Expert user → Ask for their knowledge
Novice user → Then research helps
```

### 13. Skipping Research When Needed

**Symptom**: Making recommendations without checking current best practices.

**Problem**: Outdated or suboptimal advice.

**Fix**:
```
If user needs industry context → Research
If comparing approaches → Research current options
If user asks "what's best" → Research before recommending
```

---

## Confirmation Anti-Patterns

### 14. No Summary

**Symptom**: Proceeding without confirming understanding.

**Problem**: Misalignment discovered too late.

**Fix**:
```
Always summarize: "Here's what I understand..."
Always confirm: "Does this capture what you want?"
Only proceed after explicit confirmation.
```

### 15. Vague Summary

**Symptom**: Summary is as vague as original request.

**Problem**: Hasn't actually achieved clarity.

**Fix**:
```
Summary should be SPECIFIC enough to act on.
If you can't be specific, you need more questions.
Test: Could someone else implement from this summary?
```

---

## Summary Table

| Anti-Pattern | Key Fix |
|--------------|---------|
| Scripted questioning | Generate for THIS situation |
| Assuming no expertise | Ask user first |
| Jumping to implementation | Confirm understanding first |
| Solution anchoring | Explore problem space first |
| Question overload | 1-4 questions at a time |
| Leading questions | Present options neutrally |
| Accepting vagueness | Probe for specifics |
| Re-asking obvious | Track what's clear |
| Codebase assumption | Assess context first |
| Specs-only mindset | Match formality to situation |
| Ignoring user's time | Gauge complexity first |
| Researching when user knows | Ask about expertise |
| Skipping needed research | Research when context needed |
| No summary | Always summarize and confirm |
| Vague summary | Be specific enough to act on |
