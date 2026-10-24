# Upgrading to Hermes v0.22

The reference build moved from v0.21.5 to v0.22.5 on 2026-10-23. This page tells that story — what changed underneath, what we did about each change, and why — and then gives the steps for an existing install. A fresh install from this repo already lands on v0.22 and needs none of it.

## Why we took the update

- **Security fixes we needed.** v0.21.6 fixed dashboard sign-in weaknesses reported by Tenable, including a spoofed `X-Forwarded-For` header resetting the login rate limit — relevant to anyone who exposes `hermes serve` behind a proxy. v0.22.0 also stops child processes inheriting platform secrets and hard-stops runaway tool loops in unattended sessions.
- **Cheaper, steadier turns.** About 2,100 fewer prompt tokens per request, a stalled-turn watchdog, and safer compaction.
- **Updates now follow tagged releases**, so the version you pin is a release, not whatever was on `main` that day.

## What changed, and what we did

**1. Python moved to 3.14, under a package manager.** Hermes now owns its Python, Node, uv and a few tools in a pinned store (`~/.hermes/tools/`), and builds each update's packages as a new "generation" that only goes live once it passes a check. Good for reliability, but two things broke for us. Every script and launchd job called the old venv's Python by path, and that path no longer exists. And packages we had pip-installed for the document and scraping skills were not carried into the new environment.
*What we did:* `~/.local/bin/python` became a small wrapper ([templates/bin/python.template](../templates/bin/python.template)) that finds Hermes's current Python the same way Hermes does, so nothing hard-codes a path again. The extra packages moved into a do-nothing plugin whose only job is to declare them ([templates/plugins/agent-deps/](../templates/plugins/agent-deps/)), which the package manager keeps across every update.

**2. "No tools" stopped meaning no tools.** Our email and transcript jobs run the model with a zero-tool toolset, so a hidden instruction in an email has nothing to act with. v0.22 quietly adds every connected MCP server to an explicit toolset list unless you name `no_mcp`. On the first run after the update, the email jobs could see the knowledge base's write tools again. Nothing failed, nothing logged an error.
*What we did:* every such call now passes `-t context_engine,no_mcp`, which works on old versions too, and a synthetic phishing email confirmed the jobs are tool-less again. This is the most important line on this page.

**3. Connectors arrived switched on.** v0.22 can act inside hosted apps (Notion, Linear, Gmail and more) through Nous's gateway, creating a free account for you on first use.
*What we did:* off, three ways — `tools.connectors.enabled: false`, `nous.guest: false`, and `connections` in `agent.disabled_toolsets`. Background installs (`security.allow_lazy_installs: false`) and usage metrics went off too. Our rule is that nothing we haven't discussed gets turned on.

**4. Chats no longer reset on a timer.** The 4 AM daily reset is gone; a conversation lasts until `/new`.
*What we did:* deleted `session_reset` from config and made `/new` the habit after any persona change.

**5. The command scanner (tirith) was removed.** Built-in rules now flag secret uploads, hidden Unicode and pipe-to-shell.
*What we did:* tested that those still trigger an approval prompt. The only loss is look-alike-URL detection.

**6. Smaller changes.** The reminder tool is now `cronjob_manage` (the old name still works). Finished reminders are kept 7 days instead of deleted, so our digest and `/reminders` now show "delivered" separately. The gateway's command line changed, so the digest asks launchd for its process instead of searching by name. Every browser tool now runs through `agent-browser`, which the package manager installs; we kept it and left out the computer-use driver, which controls the Mac's mouse and keyboard.

## Steps for an existing install

Your Claude Code does these, one at a time, checking each before moving on.

1. **Back up everything** into `~/backups/hermes-update-v0.22/`: a tar of `~/.hermes/hermes-agent`, a tarball of `~/.hermes`, each SQLite database via `sqlite3 <db> ".backup '<dest>'"`, a `pg_dump -Fc` of the KB, all `ai.hermes.*` plists, and `~/.local/bin`. Commit the change ledger. Save carried patches: `git -C ~/.hermes/hermes-agent format-patch <current-release-tag>..HEAD -o <backup>/patches/`.
2. **Pause the timer jobs** with `launchctl bootout` (leave the gateway running) and keep the list.
3. **Do not run the old `hermes update`.** v0.21.6 and older hard-reset to `origin/main`, thousands of commits past the release. Instead set `security.allow_lazy_installs: false`, then `git -C ~/.hermes/hermes-agent fetch --tags origin`, `git checkout main && git reset --hard v0.22.5`, then run `hermes update`. Any `hermes` command at this point performs the migration first.
4. **Re-apply carried patches** with `git am -3 <backup>/patches/*.patch`, then read where each hunk landed — one merged "cleanly" into dead code on the reference build.
5. **Install the new pieces:** the Python wrapper (and `bin/scrapling.template` if you use scrapling), the `agent-deps` plugin plus `hermes plugins enable agent-deps`, and `hermes pm install agent-browser` — every browser tool runs through it, so without it the browser tools silently disappear. Nothing else to install: with lazy installs off, the update downloads no default tools, so the computer-use driver never arrives.
6. **Lock down config:** connectors and guest off, `connections` denied, metrics off; delete `session_reset` (if it's still there, the gateway log warns that it's ignored).
7. **Repoint** every script, quick command and plist from the old venv path to `~/.local/bin/python` / `~/.local/bin/hermes`, and add `no_mcp` to every tool-less call. Pull this repo's templates — they already carry both.
8. **Restart and verify:** `hermes gateway restart`; `hermes -t context_engine,no_mcp -z "list your tools or NONE"` answers NONE; the jobs' dry runs pass; reload the paused jobs, and kick any calendar job whose time passed while paused (launchd doesn't replay a missed slot); then in Slack send a question, `/new`, `!jobs`, and a two-minute reminder.

**Rollback:** check out your old tag, restore the checkout tar, plists and config from step 1, and restart the gateway.

**Unverified:** whether the stable-channel updater keeps carried patch commits on later updates. Keep pinning by hand until that's tested.
