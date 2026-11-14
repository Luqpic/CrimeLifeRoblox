# Change Log: Enemy Roster Rework — Three New Recruits, Enforcement Retired

**Date:** 2026-09-17
**Status:** Applied

## Summary
The enemy roster is now entirely criminal-side. Security, Police and Armed Police are being spun off
into a separate robbery system, so they keep their finished designs here but no longer spawn and no
longer appear in any quest. Criminal is renamed Offender and Armed Criminal is renamed Disrupters.
Three new enemies fill the gap the enforcement types left in the quest ladder: the Smuggler at level
10, Bandits at 35 and the Saboteur at 70. Separately, the limit on how many enemies can be alive at
once now applies to each type on its own rather than to all of them together.

## Changes
- `ServerStorage.EnemyTemplates` — Criminal renamed to Offender, Armed Criminal to Disrupters, both
  otherwise untouched. Three new templates added: Smuggler with the PB pistol, Bandits with the
  Mossberg 590 shotgun, Saboteur with the FN P-90. Nine templates in total.
- `Workspace.EnemySpawns` — the three enforcement spawn points removed, the two renamed ones updated,
  and three new ones added. Six spawn points, all criminal-side.
- `ReplicatedStorage.Quests.QuestConfig` — the level 10, 35 and 70 quests now target the three new
  enemies instead of the enforcement types, and every quest's internal name was brought in line with
  what it now asks for.
- `ReplicatedStorage.Enemy.Constants` — the population limit is renamed to make clear it is per type.
- `ServerScriptService.Enemy.Scripts.EnemySpawner` — counts living and in-progress enemies per type
  rather than as one total, and a spawn point is only considered if its own type is below the limit.

## Notes
- Each of the six spawn points may now hold up to ten of its own type, so the practical ceiling
  across the whole map rises from ten to sixty. One type filling up no longer starves the others,
  which was the point.
- The enforcement templates were checked afterwards and are byte-for-byte as they were — same
  attributes, same weapons. Only their spawn points went. Their positions were recorded before
  deletion in case the robbery system wants them back.
- The three new spawn points reuse the positions the enforcement ones occupied. Those were already
  proven to work as spawn ground and sit well clear of both the player spawn and the three remaining
  points, which is better evidence than picking fresh coordinates off a map I cannot walk around.
- The new enemies were built from existing rigs, which means each inherits its donor's outfit. Every
  attribute the donor carried was cleared before the new ones were set. That matters most for the
  Saboteur, built from Disrupters: its recoil and aim figures were tuned for an AKM and would have
  been badly wrong on a P-90.
- The health, speed and accuracy figures for all three are placeholders sitting on the existing
  difficulty curve between their level neighbours, not balance. Tune freely.
- A known and accepted consequence: the Smuggler and Bandits both pay out at pistol rate on death,
  because cash and experience are worked out from a weapon's firing mode and there is no separate
  shotgun tier. Nothing was changed to paper over this.
- The whole place was searched afterwards for any surviving mention of the old names or the old quest
  identifiers. There are none.
