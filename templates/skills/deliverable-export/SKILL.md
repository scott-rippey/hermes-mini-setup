---
name: deliverable-export
description: Turn content (research, notes, a draft, anything) into a polished file — Markdown, DOCX, or PDF — save it to the scratch area and/or the knowledge base, and optionally email it to {{OPERATOR_FIRST_NAME}}. Use when {{OPERATOR_FIRST_NAME}} asks to make/create/export a doc, "turn this into a pdf/docx", "email me this as a file", or produce a deliverable.
version: 1.0.0
author: hermes-mini-setup (reference build)
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Deliverable, Export, PDF, DOCX, Email, Document]
---

# Deliverable Export

Render content into a file (MD / DOCX / PDF), save it, and optionally email it to {{OPERATOR_FIRST_NAME}} or file it in the KB. Trigger when {{OPERATOR_FIRST_NAME}} says things like "make me a doc/pdf", "export this", "turn this into a docx", "email me this as a file", or "create a deliverable".

On this box: **pandoc** (`/opt/homebrew/bin/pandoc` — MD→DOCX and MD→PDF) + **weasyprint** (PDF engine). Scratch area: **`~/{{AGENT_SLUG}}-outputs/`**. Email helper: `scripts/email_file.py`.

## Procedure

### 1. Assemble the content as Markdown
Compose the deliverable as clean Markdown — a clear `# H1` title and good structure. Save it to a temp file (e.g. `/tmp/deliverable.md`). Markdown is the source format; do **not** paste raw Markdown into long-form email bodies.

### 1a. If emailing long-form content in the body, render HTML first
{{OPERATOR_FIRST_NAME}} prefers substantive emailed write-ups as polished **HTML email bodies**, not raw Markdown. For tables, choose the layout for the email client: simple 2–3 column tables are fine, but wide tables or long-cell tables should be converted into stacked/mobile-friendly card sections. Cramped wide tables are unreadable in mobile Gmail — house rule. Use Pandoc/GFM → standalone HTML and send with Gmail `--html`. See `references/html-email-formatting.md` for the known-good workflow, CSS, and mobile table-card pattern. Markdown remains appropriate for attachments/docs, but the email body should be legible HTML.

### 2. Render to the requested format(s)
- **MD:** write it straight to the output path.
- **DOCX:** `pandoc /tmp/deliverable.md -o OUT.docx --reference-doc "${HERMES_HOME:-$HOME/.hermes}/skills/productivity/deliverable-export/templates/reference.docx"`  — **always include the `--reference-doc`**; it brand-matches the Word doc to the PDF (deep-blue/teal headings).
- **PDF:** `pandoc /tmp/deliverable.md -o OUT.pdf --pdf-engine=weasyprint --css "${HERMES_HOME:-$HOME/.hermes}/skills/productivity/deliverable-export/templates/deliverable.css"`  — **always include the `--css` template**; it gives the PDF its styled, lightly-branded look (deep-blue/teal headings, styled tables, page numbers).

### 3. Always save to the scratch area
Save every deliverable to `~/{{AGENT_SLUG}}-outputs/` with a descriptive, dated filename, e.g. `~/{{AGENT_SLUG}}-outputs/2026-06-26-q3-plan.pdf`. This is the persistent scratch store (NOT the KB) — so nothing is lost even when it is not filed. Scratch is automatic.

### 4. (Optional) File it in the KB
If {{OPERATOR_FIRST_NAME}} wants it in the knowledge base, store it with `mcp_rag store`, scoped per the **kb-scoping policy**: AI / general research → `general`; {{OPERATOR_FIRST_NAME}}'s own projects → `{{OWNER_SLUG}}`; a customer's work → that customer. Ask which scope if unclear. Never auto-file — present-then-file.

### 5. (Optional) Email it to {{OPERATOR_FIRST_NAME}}
If {{OPERATOR_FIRST_NAME}} asks you to email a file, send it as an attachment:

```bash
python "${HERMES_HOME:-$HOME/.hermes}/skills/productivity/deliverable-export/scripts/email_file.py" \
  --to {{OPERATOR_EMAIL}} \
  --subject "<short subject>" \
  --body "<a line or two of context>" \
  --attach "<full path under ~/{{AGENT_SLUG}}-outputs/>"
```

If {{OPERATOR_FIRST_NAME}} asks for the write-up itself in email, send a formatted HTML body instead of raw Markdown:

```bash
GAPI="python ${HERMES_HOME:-$HOME/.hermes}/skills/productivity/google-workspace/scripts/google_api.py"
BODY=$(cat /tmp/deliverable-email.html)
$GAPI gmail send --to {{OPERATOR_EMAIL}} --subject "<subject>" --body "$BODY" --html
```

Sends FROM the agent account  TO {{OPERATOR_FIRST_NAME}} — emailing {{OPERATOR_FIRST_NAME}} his own deliverable is allowed. **Never email anyone other than {{OPERATOR_FIRST_NAME}} without his explicit approval** (SOUL rule): for any other recipient, draft and ask first.

## Notes
- Always save to `~/{{AGENT_SLUG}}-outputs/` even when emailing or KB-filing — scratch is the safety net ("don't lose it, even if not in the KB").
- "Scratch, KB, or both" is {{OPERATOR_FIRST_NAME}}'s call — confirm before KB-filing; scratch happens automatically.
- If {{OPERATOR_FIRST_NAME}} did not specify, confirm the format(s) and delivery (scratch / KB / email).
