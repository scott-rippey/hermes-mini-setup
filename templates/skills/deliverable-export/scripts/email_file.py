#!/usr/bin/env python3
"""Send an email (optionally with file attachments) as the agent account  via the Gmail API,
using the Hermes Google token. Built for {{AGENT_NAME}} to deliver files to {{OPERATOR_FIRST_NAME}}.

Usage:
  python email_file.py --to {{OPERATOR_EMAIL}} --subject "Q3 plan" \
      --body "Here's the draft." --attach ~/{{AGENT_SLUG}}-outputs/q3-plan.pdf

Notes:
- Sends FROM the authenticated account (the agent account ). Requires the gmail.send scope.
- --attach may be repeated for multiple files.
- Per the SOUL rule: only email {{OPERATOR_FIRST_NAME}} without approval; for any other recipient,
  the agent must get {{OPERATOR_FIRST_NAME}}'s explicit OK first.
"""
from __future__ import annotations
import argparse
import base64
import mimetypes
import os
import sys
from email.message import EmailMessage

TOKEN = os.path.expanduser("~/.hermes/google_token.json")


def main() -> int:
    ap = argparse.ArgumentParser(description="Email a file as the agent account  via Gmail.")
    ap.add_argument("--to", required=True, help="Recipient email address.")
    ap.add_argument("--subject", default="")
    ap.add_argument("--body", default="")
    ap.add_argument("--attach", action="append", default=[], help="File path (repeatable).")
    a = ap.parse_args()

    try:
        from google.oauth2.credentials import Credentials
        from googleapiclient.discovery import build
    except ImportError:
        print("ERROR: google libs missing — run this with the hermes venv python.", file=sys.stderr)
        return 1

    if not os.path.exists(TOKEN):
        print(f"ERROR: no Google token at {TOKEN} — run google-workspace setup.", file=sys.stderr)
        return 1

    creds = Credentials.from_authorized_user_file(TOKEN)
    svc = build("gmail", "v1", credentials=creds)

    msg = EmailMessage()
    msg["To"] = a.to
    msg["Subject"] = a.subject
    msg.set_content(a.body or "")

    for path in a.attach:
        p = os.path.expanduser(path)
        if not os.path.exists(p):
            print(f"ERROR: attachment not found: {p}", file=sys.stderr)
            return 1
        ctype, _ = mimetypes.guess_type(p)
        maintype, subtype = (ctype or "application/octet-stream").split("/", 1)
        with open(p, "rb") as f:
            msg.add_attachment(f.read(), maintype=maintype, subtype=subtype,
                               filename=os.path.basename(p))

    raw = base64.urlsafe_b64encode(msg.as_bytes()).decode()
    sent = svc.users().messages().send(userId="me", body={"raw": raw}).execute()
    print(f"SENT: id={sent.get('id')} to={a.to} attachments={len(a.attach)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
