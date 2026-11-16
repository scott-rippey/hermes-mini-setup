# Upgrading to Hermes v0.23

The reference box moved from v0.22.5 to v0.23.1 in one session. This page is that jump as a checklist for an existing install. **Only v0.22.5 → v0.23.1 was run.** A box still on v0.21 or older goes through the v0.22 migration first ([upgrading-to-v0.22.md](upgrading-to-v0.22.md)); doing both in one `hermes update` has not been tested here.

## Why take the update

- **Security hardening:** more secret shapes masked in output; the approval gate now catches `curl … | sudo bash`, abbreviated PowerShell deletes and credential uploads hidden behind an approved rule; a stale approval card can no longer approve the next request; approval prompts reveal hidden Unicode.
- **Reliability:** the once-a-minute gateway freeze during memory trims is gone, closed sessions release memory, and `hermes update` stashes nothing without asking.
- **Cost:** one-shot (`-z`) runs send ~1,570 fewer prompt tokens per call.
- **`hermes sessions refresh-prompts`:** live sessions pick up an edited SOUL.md, skills or context files on their next turn, history kept — no more `/new` in every channel after a SOUL change.
- **Not a runtime patch:** v0.23.1 pins the same Python (3.14.9) and Node (26.12.1) as v0.22.5.

## What changes under you

1. **The old browser is gone.** agent-browser and the ten `browser_*` tools (`browser_navigate`, `browser_click`, …) are removed; the only browser tool is `browser_exec` (model-written Python over CDP). **The config migration deletes `browser.backend: "off"`**, so a box that used it to keep `browser_exec` out gets it back the moment the updated gateway starts. The fix is the `browser` toolset in `agent.disabled_toolsets` — and it is a valid toolset name on v0.22.5 too, so add it **before** updating (step 1 below) and there is no exposed window at all.
2. **Instagram research is script-only.** The `instagram-coach-research` skill's capture has always been `ig_capture.py` (it drives Chrome itself); its login check and hand-browsing fallback used the removed tools and are gone. Pull the updated SKILL.md and script template from this repo. The script-only path passed every component check on the reference box (imports, the vision call it uses, the login checks) but has not yet run end to end on v0.23 — do one short capture after the update.
3. **One-shot runs go through the gateway.** Every `hermes -z` executes inside the gateway, which owns MCP. `-t context_engine,no_mcp` still yields zero tools on v0.23.1 — but prove it from the session record, not the model's answer (step 6). These jobs also need the gateway running now.
4. **Document skills merged.** `docx`, `xlsx` and `powerpoint` became one `microsoft-office` skill (arrives enabled). The old copies stay on disk — put `docx` and `xlsx` in `skills.disabled` — and add `python-pptx` to the `agent-deps` plugin.
5. **`hermes gateway restart` refuses while sessions are live.** Add `-y` when you mean it. The dashboard's `POST /api/gateway/restart` always interrupts, so dashboard-driven restarts are unaffected.
6. **Missed one-shot reminders are skipped** by default (recurring jobs catch up). Leave it, or give a reminder `catch_up: true` if a late delivery is better than none.
7. **New features stay off:** the Webapp, plugin auto-update, prepared compaction, Daybreak, MCP webhook events and the remote config backend all ship disabled. Confirm after the migration.
8. **Moved to plugins:** Camofox, `hermes mcp serve` (now `hermes mcp-serve`), `import-agent`, Singularity, GitHub Copilot — install the plugin only if you used one.

## Steps for an existing install

1. **Close the browser first:** add `browser` to `agent.disabled_toolsets`, restart the gateway, and confirm no tool whose name starts with `browser` remains in the Slack surface ([operations.md](operations.md) → ceremony check 1b).
2. **Back up everything:** a tar of `~/.hermes/hermes-agent`, a tar of `~/.hermes/installs` + `~/.hermes/tools` (the update's garbage collection removes old dependency generations, so this tar is your rollback), a tarball of `~/.hermes` minus caches, every SQLite db via `sqlite3 <db> ".backup '<dest>'"`, a fresh `pg_dump -Fc` of the KB, config.yaml, the launchd plists, `~/.local/bin`. Format-patch any carried commits.
3. **Pause the timer jobs** with `launchctl bootout` (leave gateway, serve and tunnel running) and keep the list.
4. **Pin and update:** `git fetch --tags origin` → `git checkout main && git reset --hard v0.23.1` → `hermes update`. Read its log: expect the config migration line about `browser.backend`.
5. **Re-apply carried patches** with `git am -3`, then read where each hunk landed. Drop any patch whose target file no longer exists (a real-profile Chrome flag patch, for example — the file is gone with the old browser layer).
6. **Verify before re-enabling anything:**
   - `hermes --version` names v0.23.1 (release candidates for later versions exist — don't land on one).
   - Tool surface: no `browser*` names, sent or uncollapsed.
   - Zero tools: `hermes -t context_engine,no_mcp -z "list your tools or NONE"`, then `sqlite3 ~/.hermes/state.db "select p.prompt from sessions s join system_prompts p on p.hash=s.tool_names order by s.started_at desc limit 1"` must show `"tools": []`; replay a synthetic phishing email through the triage judge and confirm the KB is untouched.
   - A full-tool `-z` that reads the KB (and your meeting-notes MCP, if any) returns without an approval hang.
   - Skills: `microsoft-office` enabled, old `docx`/`xlsx` disabled, recount after the first gateway start; `~/.local/bin/python -c 'import openpyxl, docx, pptx, scrapling'`.
   - A semantic config diff (old vs new values): expect `_config_version` 51 → 53 and `browser.backend` removed, nothing else.
7. **Restart and refresh:** `hermes gateway restart -y`, reload `hermes serve` if you run it, then `hermes sessions refresh-prompts` so every live session picks up the current SOUL and skills.
8. **Bring the timer jobs back** (`launchctl bootstrap` each), dry-run the digest, and check the next morning's digest is green.
