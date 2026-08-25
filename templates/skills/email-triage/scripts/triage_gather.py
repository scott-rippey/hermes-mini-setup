#!/usr/bin/env python3
"""Deterministic inbox-triage gather: the hard-coded layers 1+2 of the email-triage skill.

Layer 1 (mechanical excludes — bulk mail never reaches the model):
  Gmail category labels (promotions/social/forums/updates), List-Unsubscribe,
  Precedence bulk/list/junk, Auto-Submitted, noreply-style senders, the operator's own mail.
Also drops threads whose LAST message is from the operator (already answered).

Layer 2 (KB tiering):
  Tier A — sender matches a KB person (people.email or an email in people.aliases,
           same match meeting_prep uses) → enriched with person + companies.
  Tier B — real human by the layer-1 filters, but not in the KB ("new person").

Output: one JSON object on stdout. No LLM, no writes, read-account token only.
Usage: triage_gather.py [--days 2] [--max 60] [--query "in:inbox ..."]
"""
import argparse
import json
import re
import subprocess
import sys
from email.utils import parseaddr
from pathlib import Path

# Reuse the google-workspace skill's auth/service plumbing (read account is its
# import-time default; only main() ever switches to the send token).
sys.path.insert(0, str(Path.home() / ".hermes/skills/productivity/google-workspace/scripts"))
import google_api  # noqa: E402

PSQL = "/opt/homebrew/bin/psql"
PGDATABASE = "{{KB_DB_NAME}}"
OWNER = "{{OPERATOR_EMAIL}}"

EXCLUDE_CATEGORIES = {"CATEGORY_PROMOTIONS", "CATEGORY_SOCIAL", "CATEGORY_FORUMS", "CATEGORY_UPDATES"}
NOREPLY_RE = re.compile(r"no[-_.]?reply|do[-_.]?not[-_.]?reply|notifications?@|mailer-daemon|postmaster@", re.I)
TRANSACTIONAL_RE = re.compile(r"^(invoice|receipts?|billing|statements?|orders?|support|help|hello|info)\b[\w+.-]*@", re.I)
OWN_DOMAIN = "@" + OWNER.split("@", 1)[1]
META_HEADERS = ["From", "To", "Cc", "Subject", "Date", "List-Unsubscribe", "Precedence", "Auto-Submitted", "Reply-To"]


def pg(query, **params):
    """Parameterized psql via stdin (:'var' quoting); rows on \\x1e, fields on \\x1f."""
    cmd = [PSQL, "-d", PGDATABASE, "-At", "-F", "\x1f", "-R", "\x1e"]
    for k, v in params.items():
        cmd += ["-v", f"{k}={v}"]
    try:
        r = subprocess.run(cmd, input=query, capture_output=True, text=True, timeout=30)
    except Exception:
        return []
    if r.returncode != 0:
        return []
    return [row.split("\x1f") for row in r.stdout.split("\x1e") if row.strip()]


def headers_dict(msg):
    return {h["name"].lower(): h["value"] for h in msg.get("payload", {}).get("headers", [])}


def exclude_reason(headers, labels, from_email):
    if from_email.lower().endswith(OWN_DOMAIN):
        return "internal (own domain/system)"
    cat = EXCLUDE_CATEGORIES & set(labels)
    if cat:
        return f"gmail category ({sorted(cat)[0].split('_', 1)[1].lower()})"
    if "list-unsubscribe" in headers:
        return "list/bulk (List-Unsubscribe)"
    if headers.get("precedence", "").lower() in {"bulk", "list", "junk"}:
        return "list/bulk (Precedence)"
    auto = headers.get("auto-submitted", "").lower()
    if auto and auto != "no":
        return "auto-submitted"
    if NOREPLY_RE.search(from_email):
        return "noreply sender"
    if TRANSACTIONAL_RE.match(from_email):
        return "transactional sender"
    return None


def kb_person(email):
    """Tier-A match: people.email or an email hiding in people.aliases (meeting_prep's match)."""
    rows = pg(
        "SELECT p.id, p.name, p.slug, "
        "coalesce(string_agg(DISTINCT c.name, ', '), '') "
        "FROM people p "
        "LEFT JOIN customer_people cp ON cp.person_id = p.id "
        "LEFT JOIN customers c ON c.id = cp.customer_id "
        "WHERE lower(p.email)=lower(:'em') "
        "OR EXISTS (SELECT 1 FROM unnest(coalesce(p.aliases, ARRAY[]::text[])) a "
        "WHERE lower(a)=lower(:'em')) "
        "GROUP BY p.id, p.name, p.slug LIMIT 1",
        em=email,
    )
    if not rows or len(rows[0]) < 4:
        return None
    return {"person_id": rows[0][0], "name": rows[0][1], "slug": rows[0][2], "companies": rows[0][3]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=2)
    ap.add_argument("--max", type=int, default=60)
    ap.add_argument("--query", default="", help="Override the Gmail query entirely")
    args = ap.parse_args()

    q = args.query or f"in:inbox newer_than:{args.days}d"
    service = google_api.build_service("gmail", "v1")
    listing = service.users().messages().list(userId="me", q=q, maxResults=args.max).execute()
    ids = [m["id"] for m in listing.get("messages", [])]

    excluded = {}
    threads = {}  # threadId -> newest surviving message record
    for mid in ids:
        msg = service.users().messages().get(
            userId="me", id=mid, format="metadata", metadataHeaders=META_HEADERS
        ).execute()
        h = headers_dict(msg)
        from_name, from_email = parseaddr(h.get("from", ""))
        reason = exclude_reason(h, msg.get("labelIds", []), from_email or "")
        if reason:
            excluded[reason] = excluded.get(reason, 0) + 1
            continue
        rec = {
            "message_id": msg["id"],
            "thread_id": msg["threadId"],
            "from_name": from_name or from_email,
            "from_email": from_email,
            "subject": h.get("subject", ""),
            "date": h.get("date", ""),
            "snippet": msg.get("snippet", ""),
            "internal_date": int(msg.get("internalDate", 0)),
        }
        cur = threads.get(msg["threadId"])
        if cur is None or rec["internal_date"] > cur["internal_date"]:
            threads[msg["threadId"]] = rec

    # Drop threads the operator already answered (last message in thread is theirs).
    already_answered = 0
    survivors = []
    for tid, rec in threads.items():
        th = service.users().threads().get(
            userId="me", id=tid, format="metadata", metadataHeaders=["From"]
        ).execute()
        last = th.get("messages", [])[-1] if th.get("messages") else None
        last_from = parseaddr(headers_dict(last).get("from", ""))[1] if last else ""
        if last_from.lower() == OWNER:
            already_answered += 1
            continue
        survivors.append(rec)

    tier_a, tier_b = [], []
    for rec in sorted(survivors, key=lambda r: -r["internal_date"]):
        rec.pop("internal_date", None)
        person = kb_person(rec["from_email"]) if rec["from_email"] else None
        if person:
            rec["kb"] = person
            tier_a.append(rec)
        else:
            tier_b.append(rec)

    print(json.dumps({
        "query": q,
        "scanned": len(ids),
        "excluded": excluded,
        "already_answered_threads": already_answered,
        "tier_a": tier_a,
        "tier_b": tier_b,
    }, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
