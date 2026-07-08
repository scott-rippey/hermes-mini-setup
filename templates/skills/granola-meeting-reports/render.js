// Granola meeting report renderer: content JSON -> Markdown (KB copy) + email-safe HTML fragment.
// Both built from ONE content object, so they never drift. NO PDF/docx (delivery is the HTML brief).
// Usage:  node render.js <content.json> [outDir]
//   outDir default: ~/{{AGENT_SLUG}}-outputs/granola-reports  (writes markdown/<base>.md and html/<base>.html)
// The skill reads html/<base>.html into the morning-brief manifest; the brief embeds it inline.
const fs = require('fs');
const path = require('path');
const os = require('os');

const data = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const outDir = process.argv[3] || path.join(os.homedir(), '{{AGENT_SLUG}}-outputs', 'granola-reports');
const base = data.base;
for (const sub of ['markdown', 'html']) fs.mkdirSync(path.join(outDir, sub), { recursive: true });

// ---------------- Markdown (KB copy) ----------------
const yamlList = (a) => '[' + (a || []).map(x => /[:#\[\],]/.test(String(x)) ? JSON.stringify(x) : x).join(', ') + ']';
function buildMarkdown(d) {
  const L = [
    '---',
    `title: ${d.title}`, `date: ${d.date}`, `time: ${d.time || ''}`,
    `meeting_type: ${d.meeting_type || 'other'}`,
    `counterpart: ${d.counterpart || 'unknown'}`,
    `counterpart_inferred: ${d.counterpart_inferred !== false}`,
    `people_mentioned: ${yamlList(d.people_mentioned)}`,
    `tools_products: ${yamlList(d.tools_products)}`,
    'source: granola', `meeting_id: ${d.meeting_id || ''}`,
    `filed_company: ${d.filed_company || ''}`, `generated: ${d.generated || ''}`,
    `tags: ${yamlList(d.tags)}`, '---', '', `# ${d.title}`, '',
  ];
  if (d.counterpart_note) L.push(`> ${d.counterpart_note}`, '');
  L.push('## TL;DR', d.tldr || '', '');
  L.push('## Topics Discussed', '');
  for (const t of d.topics || []) { L.push(`### ${t.h}`, ''); for (const p of t.p) L.push(p, ''); }
  if ((d.decisions || []).length) { L.push('## Decisions Made', ''); for (const x of d.decisions) L.push(`- ${x}`); L.push(''); }
  if ((d.actions || []).length) {
    L.push('## Action Items', '', '| Owner | Action | Timing |', '|---|---|---|');
    for (const r of d.actions) L.push(`| ${r[0]} | ${r[1]} | ${r[2]} |`); L.push('');
  }
  if ((d.quotes || []).length) { L.push('## Key Moments & Notable Quotes', ''); for (const q of d.quotes) L.push(`- "${q.q}" - ${q.a}`); L.push(''); }
  if ((d.open_questions || []).length) { L.push('## Open Questions / Unresolved', ''); for (const x of d.open_questions) L.push(`- ${x}`); L.push(''); }
  if ((d.people_entities || []).length) { L.push('## People & Entities', ''); for (const p of d.people_entities) L.push(p, ''); }
  if ((d.glossary || []).length) { L.push('## Glossary / Term Corrections', ''); for (const g of d.glossary) L.push(`- ${g[0]} -> ${g[1]}`); L.push(''); }
  L.push('---', `Generated from Granola - ${d.generated || ''}`);
  return L.join('\n');
}

// ---------------- HTML fragment (for the morning brief) ----------------
const FONT = "-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";
const INK = "#1f2937", MUTED = "#6b7280", FAINT = "#9ca3af", ACCENT = "#4f46e5", CARD = "#f5f6f9", LINE = "#e5e7eb";
const e = (s) => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
function buildHTML(d) {
  const H = [];
  const h = (t) => `<div style="font:700 13px ${FONT};color:${ACCENT};margin:14px 0 4px">${e(t)}</div>`;
  const para = (t) => `<div style="font:13px/1.5 ${FONT};color:${INK};margin:4px 0">${e(t)}</div>`;
  H.push(`<div style="border:1px solid ${LINE};border-radius:12px;padding:16px 18px;margin:6px 0">`);
  H.push(`<div style="font:700 11px ${FONT};letter-spacing:.06em;color:${FAINT};text-transform:uppercase">Meeting report</div>`);
  H.push(`<div style="font:800 18px ${FONT};color:${INK};margin:2px 0 1px">${e(d.displayTitle || d.title)}</div>`);
  H.push(`<div style="font:12px ${FONT};color:${MUTED}">${e(d.date)} &middot; ${e((d.meeting_type || '').replace(/_/g, ' '))} &middot; with ${e(d.counterpart || 'unknown')}</div>`);
  if (d.filed_company) H.push(`<div style="font:12px ${FONT};color:${MUTED};margin-top:1px">Filed under: ${e(d.filed_company)}</div>`);
  if (d.tldr) H.push(`<div style="background:${CARD};border-left:3px solid ${ACCENT};border-radius:0 8px 8px 0;padding:10px 12px;margin:12px 0;font:14px/1.5 ${FONT};color:${INK}"><strong>TL;DR</strong><br>${e(d.tldr)}</div>`);
  if ((d.topics || []).length) { H.push(h('Topics discussed')); for (const t of d.topics) { H.push(`<div style="font:600 13px ${FONT};color:${INK};margin:8px 0 2px">${e(t.h)}</div>`); for (const p of t.p) H.push(para(p)); } }
  if ((d.decisions || []).length) { H.push(h('Decisions')); H.push(`<ul style="margin:4px 0;padding-left:18px">`); for (const x of d.decisions) H.push(`<li style="font:13px/1.5 ${FONT};color:${INK}">${e(x)}</li>`); H.push('</ul>'); }
  if ((d.actions || []).length) {
    H.push(h('Action items'));
    H.push(`<table style="border-collapse:collapse;width:100%;font:13px ${FONT};margin:4px 0">`);
    H.push(`<tr><th align="left" style="border-bottom:1px solid ${LINE};color:${MUTED};padding:4px 6px;font-weight:600">Owner</th><th align="left" style="border-bottom:1px solid ${LINE};color:${MUTED};padding:4px 6px;font-weight:600">Action</th><th align="left" style="border-bottom:1px solid ${LINE};color:${MUTED};padding:4px 6px;font-weight:600">Timing</th></tr>`);
    for (const r of d.actions) H.push(`<tr><td style="border-bottom:1px solid ${LINE};padding:4px 6px;color:${INK}">${e(r[0])}</td><td style="border-bottom:1px solid ${LINE};padding:4px 6px;color:${INK}">${e(r[1])}</td><td style="border-bottom:1px solid ${LINE};padding:4px 6px;color:${MUTED}">${e(r[2])}</td></tr>`);
    H.push('</table>');
  }
  if ((d.quotes || []).length) { H.push(h('Key moments')); for (const q of d.quotes) H.push(`<div style="border-left:2px solid ${FAINT};padding:2px 0 2px 10px;margin:6px 0;font:italic 13px/1.5 ${FONT};color:${INK}">&ldquo;${e(q.q)}&rdquo;<div style="font-style:normal;color:${MUTED};font-size:12px;margin-top:1px">${e(q.a)}</div></div>`); }
  if ((d.open_questions || []).length) { H.push(h('Open questions')); H.push(`<ul style="margin:4px 0;padding-left:18px">`); for (const x of d.open_questions) H.push(`<li style="font:13px/1.5 ${FONT};color:${INK}">${e(x)}</li>`); H.push('</ul>'); }
  H.push('</div>');
  return H.join('');
}

fs.writeFileSync(path.join(outDir, 'markdown', `${base}.md`), buildMarkdown(data));
fs.writeFileSync(path.join(outDir, 'html', `${base}.html`), buildHTML(data));
console.log(`md + html written for: ${base}`);
