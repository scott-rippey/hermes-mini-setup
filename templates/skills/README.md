# Skill templates — instantiation notes

Four production skills, genericized. To install (Phase 7): fill `{{PLACEHOLDERS}}` in every text file (registry: `../README.md`), verify none remain (`grep -rn "{{" <skill>` must be empty), copy each folder to `~/.hermes/skills/productivity/<name>/`, confirm discovery with `hermes skills list`, restart the gateway, and smoke-test one flow per skill.

| Skill | What it does | Note |
|---|---|---|
| `customer-onboarding` | Guided interview → canonical customer + contacts-as-people in the KB | The KB's front door |
| `contact-onboarding` | Add/link people to an existing company (many-to-many, per-company role) | Never creates companies |
| `file-to-kb` | The offer-then-file gate for shared/uploaded documents | Scoping discipline lives here |
| `deliverable-export` | Markdown → branded DOCX/PDF → scratch dir → optional email/KB | `reference.docx`/`deliverable.css` ship with a neutral deep-blue/teal look — recolor to the operator's brand if desired |

`email_file.py` runs on the platform venv python (Google libs) and sends **from the agent account to the operator only** — any other recipient requires explicit approval, per SOUL.
