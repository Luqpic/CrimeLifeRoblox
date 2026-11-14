# Change Log: Supplier Billboard Input, Toast Duration, Dead Code Removed

**Date:** 2026-09-19
**Status:** Applied (confirmed live with real mouse input)

## Supplier response billboard was not clickable

Diffed the working FPS quest billboard against this one. Exactly one property differed:

```
FPS:     QuestResponsesGui.Active = true
Robbery: QuestResponsesGui.Active = false
```

`BillboardGui.Active` gates whether the billboard receives input at all and **defaults to false**. This copy was built with `Instance.new`, so it inherited the default; the FPS one was authored with it on. It rendered perfectly and was simply never in the input path.

A second blocker sat behind it. The supplier's `Interaction` part is ~0.7 studs inside the rig, so the line-of-sight ray hits the NPC's own `UpperTorso`/`HumanoidRootPart` from every approach angle and the prompt never showed -- tested from five positions with a raycast on each. All six FPS quest NPCs have `RequiresLineOfSight = false` for exactly this reason (their prompts are parented to `HumanoidRootPart`), so this one now matches.

- `StarterGui.QuestResponsesGui` -- `Active = true`.
- Supplier `ProximityPrompt` -- `RequiresLineOfSight = false`.
- The NPC nameplate also got `Active = true`, for parity with the FPS plates.

Verified with real mouse clicks: prompt shows, conversation opens, clicking "Where do I even find supplies?" advances to the explainer with the rows correctly swapped, clicking the sell option returns `no_supplies` from the server, and "Not today." closes with the right quip, nameplate restored and prompt re-enabled.

## Toast duration

`TOAST_SECONDS = 2.5` replaces a bare `5`. Measured by firing the real remote: **2.98s on screen** including the slide-out, down from about 5.5s.

## Dead code removed
- `StarterGui.SupplierDialogGui` -- the pre-billboard dialog, orphaned when the conversation moved to the shared engine. 7 descendants, already disabled, zero live references.
- `OpenSupplierDialog` -- removed from `Net`'s remote list along with the `Net:OpenSupplierDialog` method and the stale instance left in the place. Nothing fired it since the conversation moved client-side.

`SubmitSupplierChoice` and `SupplierResult` are untouched, so the outcome is still server-decided.
