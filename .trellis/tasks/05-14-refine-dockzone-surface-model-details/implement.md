# Implement: Contract-Spec Planning Output

## Checklist

### Step 1: Freeze planning boundaries
- [ ] keep renderer-agnostic core contract
- [ ] keep state-transition-oriented canonical progress drivers
- [ ] keep mirrored ear defaults with explicit override escape hatch
- [ ] keep surface-local ownership

### Step 2: Define the contract-spec output format
- [ ] commit to a specification-style artifact
- [ ] include field groups, field table, types, required/optional rules, transition table, and forbidden fields

### Step 3: Prepare the next implementation-facing task
- [ ] ensure this planning output is sufficient for a future contract document task
- [ ] avoid introducing renderer-specific shortcuts into the contract boundary

## Validation

- planning docs stay internally consistent
- no conflict with earlier unified-owner and geometry-model tasks
- the output clearly narrows the next task to authoring the spec rather than reopening architecture debate

## Risk Files

- `.trellis/tasks/05-14-refine-dockzone-surface-model-details/prd.md`
- `.trellis/tasks/05-14-refine-dockzone-surface-model-details/design.md`
- `.trellis/tasks/05-14-refine-dockzone-surface-model-details/implement.md`

## Rollback Point

- If the contract output shape becomes too implementation-specific, roll back to the last accepted renderer-agnostic boundary and remove renderer-bound details.
