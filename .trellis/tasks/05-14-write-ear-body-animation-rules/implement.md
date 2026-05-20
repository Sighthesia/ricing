# Implement: Split Ear-Body Motion Rules into Skills

## Checklist

### Step 1: Update existing domain skill
- [ ] edit `.agents/skills/glass-liquid-design/SKILL.md`
- [ ] add explicit ear/body animation-unity rules
- [ ] state that overlay-ear ownership is transitional when unified large-scale animation is required

### Step 2: Create new transition hygiene skill
- [ ] create `.agents/skills/visual-transition-rules/SKILL.md`
- [ ] add frontmatter name and description
- [ ] document required transitions for perceptible style-variable changes

### Step 3: Optional discoverability adjustment
- [ ] check whether `AGENTS.md` needs a minimal note about the new skill
- [ ] only update `AGENTS.md` if it materially improves discoverability without bloating root context

## Validation

- read both skill files end-to-end for overlap and contradiction
- ensure the split between domain-specific rules and general transition rules is clear

## Risk Files

- `.agents/skills/glass-liquid-design/SKILL.md`
- `.agents/skills/visual-transition-rules/SKILL.md`
- `AGENTS.md` if updated

## Rollback Points

- after Step 1: revert `glass-liquid-design` changes if the wording becomes too implementation-specific
- after Step 2: remove the new skill if the split proves confusing
