# Dynamic Bar Motion Boundary Notes

## Purpose

This note records the implementation boundary for the dynamic bar motion review
follow-up so the shared motion spec stays aligned with the related system-monitor
plans.

## Scope Boundary

- `barMotion` remains a cross-widget runtime contract owned by
  `SettingsService.data.barMotion` and consumed through `Theme.anim.barExpand*`.
- The widget settings surface exposes that contract as a cross-widget block under
  the existing functional group for every widget, including widgets that do not
  yet have dedicated settings.
- This review pass does not add a dedicated `SuperSystemMonitorWidget` settings
  section, panel, or widget-local motion behavior.

## Deferred Super System Monitor Work

`SuperSystemMonitorWidget` stays on the already documented path captured in:

- `docs/plans/2026-03-17-super-system-monitor-widget-integration-design.md`
- `docs/plans/2026-03-17-super-system-monitor-widget-integration-plan.md`
- `docs/plans/2026-03-18-super-system-monitor-status.md`

That means the remaining widget-specific scope is still:

- upgrading the placeholder widget to render real `SystemMonitorService` data
- deciding whether the widget needs a dedicated settings block after that runtime
  contract exists
- evaluating any future panel or richer monitor interactions as a separate phase

## Why It Stays Deferred Here

The dynamic bar motion review only fixes shared motion behavior and the current
widget settings information architecture. Pulling `SuperSystemMonitorWidget`
into this pass would widen scope from shared motion plumbing into unfinished
widget product work.
