---
name: reactive-measurement-layout-debugging
description: Use when diagnosing or fixing UI layout bugs where measured, preferred, target, actual, animated, or clipped sizes diverge. Applies to QML, React, native UI, and other reactive layout systems, especially when content is clipped even though the theoretical max size is large enough.
---

# Reactive Measurement Layout Debugging

## A. The Generic Pattern / Methodology

**Core Concept**: Reactive layout often has multiple width or height domains: natural content size, preferred size, host/stage target size, animated current size, actual rendered size, and clipped viewport size. A bug can persist when only one domain is fixed while another still constrains rendering.

**Universal Checklist**:

| Step | Check |
| --- | --- |
| 1 | Name every size domain in the path: content, measured, preferred, target, actual, clip. |
| 2 | Identify which domain owns final rendered geometry. |
| 3 | Verify measurement invalidates when children/delegates/items are created, removed, or rebound. |
| 4 | Ensure the target size uses measured preferred size when max bounds allow it. |
| 5 | Ensure title/text cap logic uses the final target or actual available size, not a transient animation width. |
| 6 | Verify the clip container is at least as large as the content that should be visible. |

## B. The Specific Trap / Symptom

**Context**: A capsule had screen-width max space available, but its title cards stayed truncated. The first fix changed the title-width cap formula, but the problem remained because the capsule's actual width was still driven by a smaller stage metric and the measurement chain could be stale.

**Trigger Symptom**: Text or content is clipped even though logs or obvious constants say the maximum width is large enough.

## C. The Anti-Pattern vs. Best Practice

| Anti-Pattern | Why It Fails |
| --- | --- |
| Fixing only the cap/elide formula | The visual owner may still render at a smaller actual width. |
| Assuming `itemAt()` or child traversal automatically rebinds | Many reactive engines do not track future delegate creation through imperative lookup calls. |
| Trusting max width as proof of available space | Max width is only a bound; target and actual width may still be smaller. |
| Testing only helper math | Helper math can pass while the component geometry still clips. |

| Best Practice | Effect |
| --- | --- |
| Drive actual geometry from measured preferred size when within max bounds | Content can expand when it genuinely fits. |
| Add explicit generation/revision invalidation around dynamic children | Parent measurements recompute after delegate creation/removal. |
| Test the composed component, not just pure functions | Regression covers measurement, target sizing, and clipping together. |
| Build a small harness that prints all relevant size domains | Quickly reveals which domain is still constraining the UI. |

## D. Generalizable Rules

**Agnostic Rules**:

- Treat `maxWidth` or screen width as a ceiling, not evidence that layout actually expanded.
- When using dynamic delegates, make measurement depend on an explicit revision/generation updated on item add/remove.
- If a component has animation, distinguish transient current size from final target size.
- If content is clipped, inspect both the content width and the clip viewport width.
- Fix the owner of the final rendered geometry, not only the helper that computes desired geometry.

**Warning Signs**:

- Imperative child lookup inside a reactive property, such as `itemAt()`, `children[index]`, refs maps, or view-holder traversal.
- Fallback widths like `56`, `144`, or fixed skeleton sizes appearing in preferred-size calculations.
- Separate modules computing stage/host size and child/content size.
- Text cap, elide, or overflow logic based on animated current width.
- The issue disappears after reload, delay, or interaction, indicating stale measurement invalidation.

## E. Universal Verification Strategy

**Agnostic Testing Logic**:

| Verification | What It Proves |
| --- | --- |
| Create a component with small initial/stage metrics but a larger max bound | The component can grow beyond the stale/current metric. |
| Use content whose natural width fits within max bounds | Any truncation is a bug, not a valid overflow. |
| Assert actual width equals preferred width | The final visual owner follows measurement. |
| Assert cap/elide is disabled or infinite when content fits | Text logic no longer constrains unnecessarily. |
| Print measured, preferred, target, actual, and clip widths in a temporary harness | Confirms the constraining domain before and after the fix. |

**Cleanup Rule**: Remove temporary harnesses and debug logs after verification; keep only regression tests at the real composed-component seam.
