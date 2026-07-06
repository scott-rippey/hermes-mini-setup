# Templates — placeholder registry

Every `{{PLACEHOLDER}}` used across `templates/`, and where its value comes from. The installer (Claude Code) fills these from `setup/answers.md` during Phase 0–1 and writes instantiated files to their live locations — **instantiated files never come back into this repo.**

| Placeholder | Meaning | Example shape |
|---|---|---|
| `{{OPERATOR_NAME}}` / `{{OPERATOR_FIRST_NAME}}` | The human | "Jane Doe" / "Jane" |
| `{{OPERATOR_EMAIL}}` | Their Workspace address (the **read** lane + sole auto-email recipient) | jane@her-domain.com |
| `{{OPERATOR_CELL}}` | Their cell (profile seed; test-call target) | +1 … |
| `{{BUSINESS_NAME}}` / `{{BUSINESS_ONE_LINER}}` | The company + what it does | — |
| `{{AGENT_NAME}}` / `{{AGENT_NAME_UPPER}}` / `{{AGENT_SLUG}}` | Their Sidekick's name / UPPER / lowercase-slug | "Atlas" / "ATLAS" / "atlas" |
| `{{AGENT_EMAIL}}` | The agent's Workspace address (the **act** lane) | atlas@her-domain.com |
| `{{OWNER_SLUG}}` | KB identity for the operator's own work | "jane" |
| `{{KB_DB_NAME}}` | Postgres database name | "kb" |
| `{{DOCS_REPO_DIR}}` | Local dir of their build-docs repo (under `~`) | "agent-setup" |
| `{{PRIVATE_DOCS_REMOTE}}` | Their **private** GitHub repo for docs self-push | owner/agent-backup |
| `{{CC_MEMORY_DIR}}` | Claude Code project-memory dir (machine-specific, under `~/.claude/projects/…/memory`) | — |
| `{{HOME}}` / `{{HERMES_VENV_PYTHON}}` | Absolute home dir / the platform venv python | /Users/… |
| `{{JOB}}` / `{{SCRIPT}}` / `{{HOUR}}` / `{{MINUTE}}` | launchd instantiation values (schedule table in job.plist.template) | — |
| `{{TIMEZONE}}` / `{{LOCATION}}` | From the interview | — |
| `{{ROLE}}` / `{{BACKGROUND_BRIEF}}` / `{{WORK_TYPES}}` / `{{STACK_LIST}}` / `{{QUALITY_BAR}}` / `{{DELIVERABLE_FOCUS}}` / `{{VOICE_EXTRAS}}` | Interview-derived profile/persona content | — |
| `{{HOME_ADDRESS}}` | Operator's travel origin (meeting-prep "leave by") — lives only in the instantiated script, never in docs | — |

Rules the installer must keep:
1. Instantiate → smoke-test by hand → wire → verify → only then schedule.
2. A template with any leftover `{{…}}` must fail loudly, not run (grep before installing).
3. Secrets are never placeholders — they go to keychain/.env via the human-run Terminal ceremonies.
