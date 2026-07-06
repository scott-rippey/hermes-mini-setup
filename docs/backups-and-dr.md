# Backups & Disaster Recovery

> Three independent layers, all nightly, deliberately ordered so they capture the same day. Everything irreplaceable leaves the box every night. **The passphrase gets an off-box copy on day one — this is a setup step, not a someday.**

## The nightly trilogy

| Time | Job | Layer | Destination |
|---|---|---|---|
| 3:05a | system-changes | **Change ledger** commit (`~/.hermes` local git) | stays on box (its history rides layer 3) |
| 3:10a | git-backup | **Docs push** | your private GitHub repo |
| 3:15a | backup | **Encrypted full bundle** | the agent account's Google Drive |

## Layer 3 in detail — the encrypted bundle (`templates/scripts/backup.py.template`)

**Contents (one tarball):**
1. `kb.sql` — `pg_dump` of the KB (customers, people, apps, meetings, documents, embeddings)
2. `state.db` + `kanban.db` — **sqlite online snapshots** (`.backup` — never file-copy a WAL-active DB)
3. `~/.hermes` — config, SOUL, memories, skills (including your modified copies), scripts, **secrets** (.env, tokens), and the ledger's `.git`
4. Your docs repo, **including `.git` history**
5. Claude Code project memory + global CLAUDE.md (box-only knowledge)
6. `RESTORE.txt` — the restore guide, embedded in every bundle

**Excluded (regenerable bulk):** the platform install, venvs, node_modules, browser drivers, caches, logs — keeps the bundle tens of MB instead of hundreds.

**Encryption:** gpg AES-256; passphrase from the login keychain, fed via `--passphrase-fd` — never logged, never in files. The Drive copy is opaque even though it contains live credentials.

**Retention:** 14 days in Drive (the prune matches only the exact backup filename pattern), 1 local copy.

## Layer 2 — docs push (`templates/scripts/git_backup.py.template`)

Auto-commits any dirty working tree nightly and pushes `main` to your **private** repo. Auth: a fine-grained PAT (Contents R/W, that single repo) in the keychain, injected at push time by a repo-local credential helper — the token never exists in a file or URL. Working-session commits with real messages still happen; the nightly job is the safety net. The ops digest's **"Docs repo push"** row FAILs on any unpushed or uncommitted state — a supposed-to-exist backup that isn't flowing should nag you at breakfast.

## Layer 1 — change ledger

`~/.hermes` as a local-only git repo (no remote, secrets gitignored). Not a backup per se — it's the **history** of config/skills/scripts, and its `.git` rides the encrypted bundle nightly, so full change history survives box loss.

## What restore looks like (box-loss drill)

On a fresh Mac, with the passphrase from your off-box copy:

1. Download the newest bundle from the agent account's Drive → `gpg -d` → `tar xzf`.
2. Postgres + pgvector → `createdb <kb>` → `psql -f kb.sql`.
3. Install the platform (same pinned version) → stop gateway → restore `~/.hermes` → copy the sqlite snapshots in.
4. Restore the docs repo + Claude Code memory.
5. **Recreate keychain items** (backup passphrase, PATs) — the keychain does NOT travel in the bundle.
6. Re-apply your tracked patch list ([operations.md](operations.md)), reload the launchd plists, start the gateway.
7. Re-auth OAuth surfaces that need it (main-model OAuth, any MCP OAuth).

Every bundle's embedded `RESTORE.txt` carries the short version.

## Verification discipline

- **Day one:** run the backup by hand, then do a full round-trip — download, decrypt, restore into a scratch DB, compare row counts. (The reference build did this before trusting anything.)
- **Quarterly:** decrypt + `tar t` spot-check.
- **Twice a year:** full scratch-restore drill.
- The digest verifies the *ran-and-uploaded* part daily; drills verify the *actually restorable* part.

## The rule that outranks the others

The gpg passphrase must exist **somewhere off this box** (your password manager, or even a printed copy) from the day it's created. A keychain-only passphrase means box loss silently converts your entire backup history into random bytes.
