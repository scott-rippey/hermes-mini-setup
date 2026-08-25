# Memory System

> Four layers with strict lanes. The governing rule: **standing behavior lives in backend config (SOUL/skills); memory holds small personal facts; documents live in the KB.** Getting these lanes wrong caused the reference build's first real bug — the full story is below because it *will* save you.

## The layers

| Layer | File/store | What belongs there | Injected | Written by |
|---|---|---|---|---|
| **Persona** | `~/.hermes/SOUL.md` | Who the agent is + standing rules (KB-first, offer-then-file, outbound gates, injection guard, email formatting, ping policy) | Snapshot at **session start** | Humans only |
| **Profile** | `memories/USER.md` | Small durable facts about the operator | Every session | The memory tool only |
| **Agent notes** | `memories/MEMORY.md` | Things the agent learned (environment, conventions) | Every session | The memory tool only |
| **History** | `state.db` | Every session/message, FTS-searchable via `session_search` | On demand | Platform core |

Not memory: the **Postgres KB** ([knowledge-base.md](knowledge-base.md)). Never store documents in built-in memory.

## The format contract (the scar-tissue section)

`USER.md`/`MEMORY.md` are **not documents**. The memory tool stores a flat list of entries joined by `\n§\n`, budgets the **whole file** against a char limit, and refuses any write when the file doesn't byte-round-trip through its parser, or any single entry exceeds the whole-store limit. On refusal it snapshots a `.bak` and errors ("Refusing to write… resolve the drift first"). Anti-data-loss by design — but it means **a hand-authored markdown profile jams the store permanently.**

**The reference-build incident:** at setup, USER.md was written as a beautiful structured document (~3,700 chars, headers, sections). The tool read it as ONE entry, 2.7× over budget → **every preference-save failed from day one**, surfacing as months' worth of recurring "drift" errors in chat. The vicious part: the agent's only mechanism for remembering "my memory is broken" *was the broken memory* — so every session rediscovered the problem and could never retain the fix. Diagnosis ultimately took reading the tool's source; the remediation was in the error message the whole time.

**Fix (and what this repo ships by default):**
1. Seed USER.md from `templates/identity/USER-seed.md.template` — proper §-entries, verified with the built-in round-trip check, 3–4 entries max.
2. Raise `memory.user_char_limit` (the 1,375 default leaves no learning headroom; the reference build runs 5000 on both stores — memory is injected per-turn, so even full stores cost only ~1K tokens).
3. Standing rules → SOUL, never memory.
4. The ops digest re-runs the exact drift check daily from *outside* the agent — a future jam becomes a red row at breakfast, not chat noise.
5. A **weekly CONTENT audit** (Mondays, riding the 3:05a `system_changes.py` job — also outside the agent, for the same reason: an agent can't reliably notice its own memory is bad, the broken memory is what it thinks with): a deterministic near-budget check (≥85% of the char limit) plus one flag-only agent-model pass over USER.md + MEMORY.md + SOUL.md — entries that contradict each other, restate a SOUL rule (redundant — behavior lives in SOUL, memory holds supporting facts), or are time-expired. Artifacts `~/.hermes/logs/memory-audit.{html,meta.json}`; the ops digest renders a "Memory content audit" section **only when there are findings** (or the audit itself errored). Resolve findings via chat (memory writes are ungated) or the backend; a SOUL line also has the agent flag contradictions/redundancy at save time instead of saving.

## Rules of the road

- **Never hand-edit `memories/*.md` into document form.** Let the agent save facts (`write_approval: false` is fine — KB writes are the gated ones, not profile facts).
- **Standing behavior → SOUL.md** + gateway restart. SOUL is snapshotted per session: live conversations keep the old version; the **daily 4am session reset** guarantees changes land by morning (`/new` forces it immediately).
- **Supporting facts → memory, freely.** That's the split: rules on the backend, facts in memory.

## Knobs (reference values, deliberate)

`memory_char_limit: 5000` · `user_char_limit: 5000` (raised) · `write_approval: false` · session reset: 4am / 24h idle (a feature — keep it).
