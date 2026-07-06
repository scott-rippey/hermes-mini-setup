# HTML email formatting for long-form deliverables

{{OPERATOR_FIRST_NAME}} prefers long-form deliverables sent in email as a polished HTML body, not raw Markdown pasted into the message. Markdown is fine as a source format and for attachments/docs, but email clients should receive actual HTML so headings, tables, code blocks, and callouts render legibly.

## When to use

Use this whenever {{OPERATOR_FIRST_NAME}} asks to email substantive content, research, planning notes, proposals, or a detailed write-up directly in the email body.

If he explicitly asks for an attachment, still attach the requested file; optionally include a short HTML summary in the body.

## Recommended workflow

1. Draft the content in clean Markdown.
2. Convert Markdown to standalone HTML with Pandoc using a small email-oriented CSS file.
3. Send via `google-workspace` Gmail with `--html`, or via an email helper that sends `text/html`.
4. Verify that tables in the Markdown source became real `<table>` elements, not pipe-table text.
5. **Mobile Gmail rule:** if a table has more than 2–3 columns or any long cell text, do **not** send it as a wide table. Convert each row into a stacked “card” / key-value section. {{OPERATOR_FIRST_NAME}} specifically rejected cramped wide tables on iPhone; card-style sections are preferred for mobile readability.

Example:

```bash
cat > /tmp/email-style.css <<'CSS'
body { margin:0; padding:0; background:#f6f7fb; color:#1f2937; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif; line-height:1.55; }
.email-wrap { max-width:920px; margin:0 auto; background:#fff; padding:34px 42px; border-radius:14px; border:1px solid #e5e7eb; }
h1 { color:#111827; font-size:30px; line-height:1.2; margin:0 0 20px; padding-bottom:14px; border-bottom:3px solid #2563eb; }
h2 { color:#111827; font-size:22px; margin:34px 0 12px; padding-top:8px; }
h3 { color:#1f2937; font-size:17px; margin:24px 0 8px; }
blockquote { margin:18px 0; padding:14px 18px; background:#eff6ff; border-left:5px solid #2563eb; color:#1e3a8a; font-weight:600; }
table { border-collapse:collapse; width:100%; margin:16px 0 24px; font-size:14px; }
th { background:#f3f4f6; color:#111827; text-align:left; font-weight:700; border:1px solid #d1d5db; padding:9px 10px; }
td { border:1px solid #e5e7eb; padding:9px 10px; vertical-align:top; }
tr:nth-child(even) td { background:#fafafa; }
code { background:#f3f4f6; color:#111827; padding:2px 5px; border-radius:4px; font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; font-size:.92em; }
pre { background:#111827; color:#f9fafb; padding:16px; border-radius:10px; overflow-x:auto; font-size:13px; line-height:1.45; }
pre code { background:transparent; color:inherit; padding:0; }
CSS

pandoc /tmp/deliverable.md --from=gfm --to=html --standalone \
  --css=/tmp/email-style.css \
  --metadata title="Email title" \
  -o /tmp/deliverable-email.html

python3 - <<'PY'
from pathlib import Path
p = Path('/tmp/deliverable-email.html')
html = p.read_text()
html = html.replace('<body>', '<body><div style="padding:24px;background:#f6f7fb;"><div class="email-wrap">')
html = html.replace('</body>', '</div></div></body>')
p.write_text(html)
PY

GAPI="python ${HERMES_HOME:-$HOME/.hermes}/skills/productivity/google-workspace/scripts/google_api.py"
BODY=$(cat /tmp/deliverable-email.html)
$GAPI gmail send --to {{OPERATOR_EMAIL}} \
  --subject "Subject" \
  --body "$BODY" \
  --html
```

## Pitfalls

- Do not paste raw Markdown into an email body for long-form deliverables; pipe tables and code fences are hard to read in email clients.
- Do not assume “real HTML table” means “readable.” On mobile Gmail, wide 4–5 column tables collapse/cramp. For planning emails, turn wide tables into stacked cards where the first column becomes the card title and the remaining columns become labeled key-value rows.
- Do not rely on external CSS. Use inline `<style>`/standalone HTML or simple inline styles; Gmail may strip or rewrite some CSS, so keep styling conservative.
- For very long technical docs, send a polished HTML email body plus an attachment if requested.
