# QML Testing Strategy Skill Design

## Goal

Add a repo-local skill that teaches agents how to choose the right verification level for QML work in this repository, then keep `AGENTS.md` minimal by pointing to that skill instead of embedding detailed testing policy in the root guide.

## Problem

The current root guidance lists commands, but it does not tell an agent how to choose among them.

That gap leads to an expensive failure mode:

- failures mix together service-contract bugs, module wiring bugs, and test-observation bugs
- TDD becomes slow because the first RED is too broad

In practical terms, the repo has the test commands but not the triage policy.

## Decision

Create a repo-local skill for QML test selection and verification strategy, then add a short trigger in `AGENTS.md` telling agents when to load it.

This treats the root guide like a map legend and the skill like the field manual.

## Scope

The skill covers the whole QML repository, not just bar/layout work.

It should help with:

- service/state changes
- geometry and layout changes
- drag/drop and interaction flow changes
- panel lifecycle and visibility behavior
- module structure changes
- feature-specific UI regressions

It should not try to replace all existing development-process skills. It only answers: "Which test layer should I use first, and what must I run before claiming success?"

## Repository Changes

### 1. Root trigger only

`AGENTS.md` should stay short.

Add only:

- a short note in the testing section that agents must load the repo-local QML testing skill for QML features, bugfixes, or behavior changes

Do not duplicate the full decision tree in `AGENTS.md`.

### 2. Repo-local skill

Create a new repo-local skill under `.github/skills/`.

Suggested name:

- `qml-testing-strategy`

Why this name:

- broad enough for the whole QML repo
- explicit about use trigger
- avoids tying the skill to one subsystem like bar/layout

### 3. Optional Claude bridge

If the repository does not already contain `CLAUDE.md`, add one that points to `AGENTS.md` and the new skill table entry.

That keeps the repo-local context consistent across clients.

## Skill Content Design

The skill should be a reusable field manual, not a narrative postmortem.

### Frontmatter

The description should be trigger-based, for example:

`Use when implementing, debugging, or validating QML features, behavior changes, layout changes, or regressions in this repository.`

### Sections

#### Overview

State the core rule:

- choose the smallest test that can prove the intended behavior
- escalate only when a smaller layer no longer proves the claim

#### When to Use

Load for:

- new QML features
- bug fixes in QML behavior
- geometry/layout changes
- service-to-module state flow changes
- structure changes that affect QML windows, panels, or widgets

#### Test Selection Ladder

This is the main section.

Recommended ladder:

4. full-shell load check


#### Change Type Mapping

Map common change types to concrete repo commands.

Examples:

- repository-wide confidence check -> `timeout 10 qs --path .`

#### Verification Before Claiming Success

Keep this short and repo-specific.

Examples:

- run the narrowest relevant harness during development
- run the nearest subsystem suite before calling the change stable
- run `qs --path .` before claiming the repo still loads cleanly if QML runtime behavior changed

#### Common Mistakes

Call out the failure modes this change is meant to prevent:

- asserting unstable local coordinates instead of service-owned contracts

## Why This Design Fits The Repo


The missing piece is not more commands. It is a routing rule for those commands.

That makes a repo-local skill the right abstraction:

- stable enough to reuse
- specific enough to be actionable
- cheaper than bloating `AGENTS.md`

## Success Criteria

The change is successful when:

- `AGENTS.md` stays concise and points to the skill instead of duplicating it
- the new skill tells agents which test layer to use first
- the skill maps common QML change types to repository commands
