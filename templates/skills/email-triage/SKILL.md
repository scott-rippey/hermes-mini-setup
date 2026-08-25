---
name: email-triage
description: On-demand inbox triage for the operator — deterministic bulk-mail filtering + KB tiering, then reply-worthiness judgment and voice-matched reply DRAFTS placed in the operator's own Gmail Drafts folder (never sent). Trigger phrases: "triage my inbox", "what needs a response", "check my email for anything that needs me".
metadata:
  category: productivity
version: 1.0.0
---

# Email Triage

Triage the operator's inbox for messages that genuinely need HIS response, and (per-item,
gated) prepare reply drafts in his own Drafts folder that he reviews and sends himself.

**This skill NEVER sends email. Not to {{OPERATOR_FIRST_NAME}}, not to anyone.** Its only write
surface is `gmail draft-create` — a draft in the operator's own Drafts folder — and only
after the operator's explicit per-item go. There is no send operation on that account by
design; do not attempt one.

## Flow

### 1. Gather (deterministic — always run the script, never hand-scan the inbox)

```
python ~/.hermes/skills/productivity/email-triage/scripts/triage_gather.py --days 2
```

`--days N` for a wider window if {{OPERATOR_FIRST_NAME}} asks ("this week" → 7). The script applies
the hard-coded layers and prints JSON:
- **excluded** — bulk/list mail, Gmail promo/social/forums/updates categories,
  noreply + transactional senders, our own domain's automation, threads {{OPERATOR_FIRST_NAME}}
  already answered. These were filtered mechanically; do NOT second-guess or
  resurrect them.
- **tier_a** — sender matches a KB person (`kb`: person + companies). Highest priority.
- **tier_b** — real human by every mechanical filter, but not in the KB ("new person").

If the script fails, report the error and stop — do not improvise a manual scan.

### 2. Present the triage (one Slack message, scannable)

- Tier A first: one line each — who (KB name + company), what they're asking, and
  your read on whether it needs a reply (be honest: "FYI only" is a fine verdict).
- Tier B: one line each — who they appear to be, what they want, why it may matter.
  If a Tier-B sender looks like a real ongoing relationship, note that
  `contact-onboarding` could add them to the KB (offer, don't do it).
- Mention the exclusion counts in one closing line (e.g. "47 bulk/system emails
  filtered") so {{OPERATOR_FIRST_NAME}} knows the floor was swept.
- No drafts yet. End by asking which items (if any) he wants drafts for.

### 3. Draft (only for items {{OPERATOR_FIRST_NAME}} names)

For each item {{OPERATOR_FIRST_NAME}} asks to draft:
1. **Context pull:** recent history with that sender (`google_api.py gmail search
   "from:<email> OR to:<email>"`, read the relevant `gmail get` bodies) and, for
   Tier A, KB context (`mcp_rag` search scoped to the person/customer). Read the
   actual message being answered in full (`gmail get`), never draft from the snippet.
2. **Voice match:** mirror how {{OPERATOR_FIRST_NAME}} writes to THIS person (register, greeting,
   sign-off, brevity) from the history you just pulled; his general style notes are
   in USER.md. Match the operator's register from the history you pulled — when in doubt, shorter.
3. **Propose in chat:** show the draft text in Slack and wait. {{OPERATOR_FIRST_NAME}} may edit,
   approve, or drop it.
4. **On his explicit go**, place it as a reply draft:
   ```
   python ~/.hermes/skills/productivity/google-workspace/scripts/google_api.py \
     gmail draft-create --to "<sender>" --subject "Re: <subject>" \
     --thread-id "<thread_id>" --body "<approved text>"
   ```
   Then report the returned `draft_id` as confirmation — never claim the draft
   exists without the tool's returned id (write-verification rule).
5. {{OPERATOR_FIRST_NAME}} reviews it in Gmail and sends it himself.

## Hard rules

1. **Never send.** Draft-create is the ceiling. Any ask that amounts to "send it
   for me" from THIS flow → the answer is that {{OPERATOR_FIRST_NAME}} sends from his Drafts folder.
2. **Never draft-create without the operator's explicit per-item go** in this conversation.
3. **Never write to the KB** from this skill — a Tier-B contact worth keeping is a
   `contact-onboarding` suggestion for {{OPERATOR_FIRST_NAME}}, nothing more.
4. The mechanical exclusions are final for the run. If {{OPERATOR_FIRST_NAME}} says a filtered sender
   matters, tell him the exclusion reason so the filter can be tuned in the script —
   don't work around it by hand.
5. This is on-demand only. Do not schedule it, poll, or self-trigger; proactive
   triage is a separate future decision of the operator's (skill-before-cron).
