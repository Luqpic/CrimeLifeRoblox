---
type: moc
tags: [moc, rules]
updated: 2026-11-15
sources: ["CLAUDE.md (How to work in this project)", "OBT Vault/10 Rules/ (generic rules carried over)"]
---

# Rules MOC

How the developer wants work on CrimeLife done. Each note gives the rule, why it exists and how to apply it. CrimeLife's own rules come from the project section of `CLAUDE.md` ("How to work in this project"). Some general working rules were set by the same developer on their other project (OBT) and are carried over here where they fit; each such note says so.

Read [[Which Project This Is]], [[Safety and Security Rules]] and [[Save and Publish Rules]] first.

## Where you are

- [[Which Project This Is]]: Crimelife City is the target from 2026-11-15 (FPS System is frozen, it was the target until 2026-11-14); Robbery System and OBT are never edited unless named.

## Safety

- [[Safety and Security Rules]]: no secrets anywhere, ProfileStore Mock only in Studio, never `Steal`, review free models, the UnitTestRunner stays Disabled.
- [[Save and Publish Rules]]: never publish; the developer saves; reports end "NOT saved / NOT published".

## How a batch runs

- [[Ask First Then Build]]: questions up front in pickers, then build to the end.
- [[Measure Before and After]]: read before you edit, reproduce with numbers, root cause, re-measure.
- [[Verify in Edit and by Screenshot]]: verify the result, not the arithmetic; `AbsolutePosition` is the witness.
- [[Reporting Rules]]: verified vs not verified, the vault updated, one `Batch:` commit.

## How things are built

- [[Shared Code Extended by Attributes]]: prefer the shared module; weapon behaviour is Tool attributes, never a fork.
- [[GUI Rules]]: shared `UI.*` modules, clickable UI under PlayerGui, Figma art at 4x, titles baked into art.
- [[Phones First and Keep Optimised]]: touch works, nothing periodic does needless work.
- [[Building Rules]]: re-runnable build scripts, donor-skeleton swaps, copy raw meshes.
- [[Player-Facing Text]]: no dash as punctuation, no clipped or overlapping text.
- [[Content Maturity Rules]]: a crime shooter kept within Roblox's content rules.

## Related

[[Batch Workflow]] · [[Decisions MOC]] · [[Vault Conventions]]
