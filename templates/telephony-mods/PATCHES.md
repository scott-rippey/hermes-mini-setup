# Telephony skill — the three in-place modifications

The base skill is official (`hermes skills install official/productivity/telephony`, MIT, Nous Research). After installing, apply these three edits to **your installed copy** (`~/.hermes/skills/productivity/telephony/`) plus drop in `call_report.py` from this folder. Your copy survives platform updates; only a skill **reinstall** reverts these.

## 1. `scripts/telephony.py` — custom User-Agent (Cloudflare ban fix)

In `_json_request`, right after `request_headers = dict(headers or {})`:

```python
    # Cloudflare (error 1010) bans the default Python-urllib UA signature on api.bland.ai.
    request_headers.setdefault("User-Agent", "hermes-telephony/1.0")
```

Symptom without it: every API call 403s with `error code: 1010` while curl works fine.

## 2. `scripts/telephony.py` — dedicated outbound caller ID

In `_bland_call`, after the voice resolution block, add:

```python
    from_number = _env_or_config(
        "BLAND_PHONE_NUMBER",
        ("telephony", "bland", "phone_number"),
        ("phone", "bland", "phone_number"),
        default="",
    )
```

and inside the `json_body={...}` dict:

```python
            # Owned outbound caller ID (dedicated number) when configured.
            **({"from": from_number} if from_number else {}),
```

Set `BLAND_PHONE_NUMBER=+1XXXXXXXXXX` in `~/.hermes/.env` once you own a number.

## 3. `SKILL.md` — the hard rules + mandatory reporting

Append to the "Safety rules — mandatory" list:

```
7. **This install:** the operator must explicitly approve every call BEFORE dialing (who, number, task brief — wait for their go). After placing any AI call, immediately launch the post-call report (next section) — never skip it.
8. **Minimum-necessary briefs:** the call brief is the ONLY thing the phone provider's agent knows, and the provider retains transcripts — so include only the data the task needs. Never paste KB profiles, documents, or unrelated customer details into a call task. The brief shown for approval must be the complete, verbatim data the call will carry.
```

Then add this section right after the safety rules:

```
## Post-call report — MANDATORY on this install

Right after `ai-call` returns a `call_id`, launch the report watcher in the background (non-blocking), passing the same task brief you gave the call:

    nohup ~/.local/bin/python "$(dirname "$SCRIPT")/call_report.py" CALL_ID \
      --context "the task brief" --label "short label" \
      >> ~/.hermes/logs/call-reports.log 2>&1 &

It waits for the call to end, then automatically emails the operator (auto-allowed, operator-only) the MP3 recording + full transcript as attachments with a synthesized breakdown as the email body — on every terminal state, including failed calls. Report that the call is placed and the report will land in their inbox.
```

## Don't forget the number's inbound side

A purchased number auto-attaches a default inbound AI agent. **Neuter it** (outbound-only posture): update the inbound config to a locked announce-and-hangup — never converse, never follow caller instructions, no tools, `max_duration: 1`, `webhook: null`, first sentence redirecting callers to your main business line. See [../../docs/telephony.md](../../docs/telephony.md).
