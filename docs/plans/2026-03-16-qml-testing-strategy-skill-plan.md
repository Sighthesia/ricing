# QML Testing Strategy Skill Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a repo-local QML testing strategy skill and keep the root agent guide minimal by moving detailed test-selection policy out of `AGENTS.md`.

**Architecture:** Keep `AGENTS.md` as the always-loaded routing layer and move the full QML testing decision tree into a repo-local skill under `.github/skills/`. If needed, add `CLAUDE.md` as a bridge so clients that do not auto-load `AGENTS.md` can still discover the same repo-local skill.

**Tech Stack:** Markdown, repo-local AI context files, `.github/skills/`, `AGENTS.md`

**Design doc:** `docs/plans/2026-03-16-qml-testing-strategy-skill-design.md`

---

### Task 1: Add the repo-local skill scaffold

**Files:**
- Create: `.github/skills/qml-testing-strategy/SKILL.md`

**Step 1: Write the skill frontmatter**

Add a trigger-focused name and description.

**Step 2: Write the minimal failing baseline note in the skill body**


**Step 3: Add the main sections**

Write sections for:

- `Overview`
- `When to Use`
- `Test Selection Ladder`
- `Change Type Mapping`
- `Verification Before Claiming Success`
- `Common Mistakes`

**Step 4: Keep the content repository-specific**

Use real commands from this repository only.

---

### Task 2: Update root routing guidance

**Files:**
- Modify: `AGENTS.md`

**Step 1: Add a short trigger rule in the testing section**

Tell agents to load the repo-local QML testing strategy skill when working on QML features, bugfixes, behavior changes, or regression fixes.

**Step 2: Keep root guidance minimal**

Do not copy the full test-selection ladder into `AGENTS.md`.

**Step 3: Add one concise selection principle**


---

### Task 3: Add a Claude bridge if missing

**Files:**
- Create if missing: `CLAUDE.md`

**Step 1: Add the bridge line**

Point Claude clients to `AGENTS.md`.

**Step 2: Add a skills table entry**

Include the new repo-local skill and when to use it.

**Step 3: Keep it minimal**

Do not duplicate the whole root guide or skill body.

---

### Task 4: Verify documentation consistency

**Files:**
- Verify: `AGENTS.md`
- Verify: `.github/skills/qml-testing-strategy/SKILL.md`
- Verify if created: `CLAUDE.md`

**Step 1: Read the updated files together**

Check that:

- root guidance is short
- the skill contains the detailed ladder and command mapping
- `CLAUDE.md` points to the same skill name and purpose

**Step 2: Verify there is no duplicated long-form policy in root files**

The detailed matrix should live only in the skill.

**Step 3: Verify terminology stays consistent**

Use the same skill name everywhere.

---

### Task 5: Final verification

**Files:**
- Verify: `AGENTS.md`
- Verify: `.github/skills/qml-testing-strategy/SKILL.md`
- Verify if created: `CLAUDE.md`

**Step 1: Re-read the final text for clarity**

Confirm the skill is concise, trigger-based, and repository-specific.

**Step 2: Check the git diff for only intended context-file changes**

Run:

```bash
git diff -- AGENTS.md CLAUDE.md .github/skills/qml-testing-strategy/SKILL.md docs/plans/2026-03-16-qml-testing-strategy-skill-design.md docs/plans/2026-03-16-qml-testing-strategy-skill-plan.md
```

**Step 3: Commit only if the user asks**

If asked, stage only the new skill and related context docs.
