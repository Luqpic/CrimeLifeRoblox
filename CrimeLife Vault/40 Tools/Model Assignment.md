---
type: tool
tags: [tool, models, workflow]
updated: 2026-11-18
sources: ["The developer's request in the 2026-11-14 planning session", "The developer's request, 2026-11-18 session"]
---

# Model Assignment

Which Claude model does which CrimeLife work. From 2026-11-18 the developer's rule is to juggle **Opus 5.5 and Sonnet 5.5** for great output with efficient token use ([[Vault Skills Only and Model Routing]]). The 2026-11-14 split also named Fable; Fable is not in the rotation from 2026-11-18, and its work (design, hard bugs, final reviews) moved to Opus.

| Model | Work |
|---|---|
| **Opus 5.5** (the main thread, and Opus subagents) | Reading the request, the pickers, game and system design, plans, Luau that touches shared modules or remotes, security and remote validation, Studio building and verification, hard bugs, the whole-branch final review of a batch, judging a subagent's output, the final report. |
| **Sonnet 5.5** (subagents, `model: "sonnet"`) | Broad read-only searches and inventories (Explore agent), bulk surveys of a place (part counts, script audits, duplicates), per-task reviews of a plan's tasks, vault note drafts from facts Opus hands over (batch notes, Open Items edits, system note updates), mechanical edits across many files, simple writing (changelogs, captions). |

## How to apply

- A design or plan is written by Opus and approved by the developer before building from it.
- Brief a Sonnet subagent with the paths and what is already known, and ask for a compact table or a draft. Its findings are reports, not proof: check a count or a claim before it goes into a decision or the vault.
- Two builders never write to the same Studio place at once. A reviewer working in the background is read-only.

Related: [[Batch Workflow]], [[Tools MOC]], [[Roblox Skills]].
