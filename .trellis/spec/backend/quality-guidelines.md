# Quality Guidelines

> Code quality standards for backend development.

---

## Overview

Service code should be defensive, atomic, and easy to recover after hot reload.
Keep persistence and normalization in the singleton that owns the data.

---

## Forbidden Patterns

- Direct file IO from `modules/` or `config/` files.
- Ad-hoc save timers outside the service that owns the persistence.
- Partial writes that can leave corrupted JSON behind.
- Unlogged parse or process failures.
- Changing a persisted schema without updating defaults/serialization.

---

## Required Patterns

- Atomic file replacement for writes when possible.
- Merge-or-fallback loading for older JSON files.
- Shared state exposed through singleton services.
- Short guard clauses before expensive or unsafe work.
- Keep service APIs narrow and domain-specific.

---

## Testing Requirements

Use the whole-shell load check as the main validation step:

```bash
timeout 5 qs --path .
```

---

## Code Review Checklist

- Is persistence still atomic and recoverable?
- Does the service handle malformed input without breaking the UI?
- Are logs concise and prefixed consistently?
- Did the change preserve backward compatibility for stored data?
- Is the service still the single owner of its data?
