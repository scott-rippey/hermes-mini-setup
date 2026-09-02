# Telephony skill — the in-place modifications

The base skill is official (`hermes skills install official/productivity/telephony`, MIT, Nous Research). After installing, apply these edits to **your installed copy** (`~/.hermes/skills/productivity/telephony/`) plus drop in `call_report.py` from this folder (instantiate [call_report.py.template](call_report.py.template)). Your copy survives platform updates; only a skill **reinstall** reverts these. Sections 1–4 are the Vapi build (recommended, [docs/telephony.md](../../docs/telephony.md)); section 5 is the inbound neuter for either provider; section 6 is only for a Bland install.

## 1. `scripts/telephony.py` — custom User-Agent (Cloudflare ban fix, both providers)

In `_json_request`, right after `request_headers = dict(headers or {})`:

```python
    # Cloudflare (error 1010) bans the default Python-urllib UA signature on api.bland.ai and api.vapi.ai.
    request_headers.setdefault("User-Agent", "hermes-telephony/1.0")
```

Symptom without it: every API call 403s with `error code: 1010` while curl works fine.

## 2. `scripts/telephony.py` — Vapi defaults

In the constants block near the top:

```diff
 VAPI_DEFAULT_VOICE_PROVIDER = "11labs"
 VAPI_DEFAULT_VOICE_ID = "cjVigY5qzO86Huf0OWal"  # ElevenLabs "Eric"
-VAPI_DEFAULT_MODEL = "gpt-4o"
+VAPI_DEFAULT_MODEL = "gpt-4.1"
+VAPI_DEFAULT_VOICE_MODEL = "eleven_flash_v2_5"  # ElevenLabs TTS model (Vapi defaults to eleven_turbo_v2)
 TWILIO_DEFAULT_TTS_VOICE = "Polly.Joanna"
```

`gpt-4.1` is the tested call model. `VAPI_MODEL` and `VAPI_VOICE_MODEL` in `.env` override these constants if you ever want to change them.

## 3. `scripts/telephony.py` — `_vapi_call`: the per-call assistant payload

Replace everything from the end of the `model = _env_or_config(...)` block down to `if first_sentence:` with:

```python
    voice_model = _env_or_config(
        "VAPI_VOICE_MODEL",
        ("telephony", "vapi", "voice_model"),
        ("phone", "vapi", "voice_model"),
        default=VAPI_DEFAULT_VOICE_MODEL,
    )
    voice: dict[str, Any] = {"provider": voice_provider, "voiceId": voice_id}
    if voice_provider == "11labs" and voice_model:
        voice["model"] = voice_model
    system_prompt = (
        "You are {{AGENT_NAME}}, {{OPERATOR_NAME}}'s AI assistant, making this call on {{OPERATOR_FIRST_NAME}}'s behalf. Always introduce "
        "yourself exactly that way; never invent another name or role. Everything you say is spoken aloud on a "
        "live phone call: output only the words you would actually say — no narration, no stage directions, "
        "no notes to yourself.\n\nYour task for this call:\n"
        + task
        + "\n\nCall handling: when the other party answers or greets you (\"hello?\"), introduce yourself and "
        "start the task — a greeting is never an answer and never a reason to end the call. Let them finish "
        "speaking before you respond. If they do not actually answer your question or seem not to have heard "
        "you, ask it again. Stay on the call until the task is genuinely complete. Close like a normal caller: "
        "once the task is done, ask if there is anything else you can help with. When they say no or start "
        "saying goodbye, reply with one warm closing sentence that thanks them or confirms what was agreed, "
        "ending with 'bye!' — and stop there. The words 'goodbye for now' hang up the call instantly, so they "
        "must only ever be your ENTIRE reply to the other party's own goodbye or acknowledgement, never part of "
        "a longer message and never in the same message as anything else."
    )
    assistant = {
        "model": {
            "provider": "openai",
            "model": model,
            "messages": [{"role": "system", "content": system_prompt}],
        },
        # Hang-up is phrase-triggered: the agent must SPEAK its closing (tool-attached goodbyes never
        # reached the phone in testing), and Vapi drops the line once the phrase is said.
        "endCallPhrases": ["goodbye for now"],
        "voice": voice,
        # Greet as soon as the call is answered (default waits for the callee to speak first).
        "firstMessageMode": "assistant-speaks-first-with-model-generated-message",
        "maxDurationSeconds": max_duration * 60,
        # Vapi defaults phone calls to an 'office' ambience (keyboard/chatter) — clean line instead.
        "backgroundSound": "off",
        # Give the other party room: wait a little longer before replying (Vapi default 0.4s) and use
        # LiveKit endpointing, Vapi's recommendation for English.
        "startSpeakingPlan": {"waitSeconds": 0.8, "smartEndpointingPlan": {"provider": "livekit"}},
        # MP3 so the post-call report can attach it directly (Vapi defaults to wav;l16).
        "artifactPlan": {"recordingEnabled": True, "recordingFormat": "mp3"},
        # Detect voicemail and hang up (no voicemailMessage => Vapi hangs up cleanly).
        "voicemailDetection": {"provider": "vapi"},
    }
```

As a diff against the stock function, the stock lines this replaces are:

```diff
-        "model": {
-            "provider": "openai",
-            "model": model,
-            "messages": [{"role": "system", "content": task}],
-        },
-        "voice": {"provider": voice_provider, "voiceId": voice_id},
-        "maxDurationSeconds": max_duration * 60,
```

The wrapper carries the agent's **identity** (substitute `{{AGENT_NAME}}` / `{{OPERATOR_NAME}}` / `{{OPERATOR_FIRST_NAME}}` with real values — the brief itself never names the caller, SKILL.md rule 8) and the spoken-words-only rule, so the model never reads instructions aloud or invents a name. Why each override exists is in [docs/telephony.md](../../docs/telephony.md#the-per-call-assistant-what-ai-call---provider-vapi-sends). Validate without dialing: `POST /assistant` with the same body, read it back, `DELETE` it.

## 4. `scripts/telephony.py` — `_vapi_status`: read artifacts

Vapi returns the transcript and recording under `artifact`, and duration as timestamps. Replace the return dict:

```diff
     payload = _json_request(
         "GET",
         f"{VAPI_API_BASE}/call/{call_id}",
         headers={"Authorization": f"Bearer {api_key}"},
     )
+    artifact = payload.get("artifact") if isinstance(payload.get("artifact"), dict) else {}
     return {
         "success": True,
         "provider": "vapi",
         "call_id": call_id,
         "status": payload.get("status"),
-        "duration_seconds": payload.get("duration"),
+        "started_at": payload.get("startedAt"),
+        "ended_at": payload.get("endedAt"),
         "ended_reason": payload.get("endedReason"),
-        "transcript": payload.get("transcript", ""),
-        "recording_url": payload.get("recordingUrl"),
-        "summary": payload.get("summary"),
+        "transcript": artifact.get("transcript") or payload.get("transcript", ""),
+        "recording_url": artifact.get("recordingUrl") or payload.get("recordingUrl"),
+        "summary": (payload.get("analysis") or {}).get("summary") if isinstance(payload.get("analysis"), dict) else None,
         "cost": payload.get("cost"),
     }
```

`call_report.py` relies on `started_at`/`ended_at`/`recording_url`/`transcript` from this dict.

## 5. `SKILL.md` — the hard rules, mandatory reporting, provider note

Append to the "Safety rules — mandatory" list (substitute the operator's and agent's names):

```
7. **This install:** {{OPERATOR_FIRST_NAME}} must explicitly approve every call BEFORE dialing (who, number, task brief — wait for their go). After placing any AI call, immediately launch the post-call report (next section) — never skip it.
8. **Brief text is shell-quoted:** write dollar amounts and anything with `$`, backticks or quotes in plain words ("about 1000 dollars a month"), or the shell will eat them before Vapi ever sees the brief. Do NOT put your own identity in the brief — the skill prepends "You are {{AGENT_NAME}}, {{OPERATOR_NAME}}'s AI assistant" and the call-handling rules on every call; the brief is only the task.
9. **Grounded briefs:** when a brief draws on the KB, email, or meeting notes, copy every figure, date, name and who-said-what **verbatim** from the source record — never paraphrase numbers or attributions (a brief once turned the operator's own "2,000 dollars a month notional spend" into "the client's concern about 1,000 dollars a month"). If a fact isn't in the source, leave it out; the phone agent will deliver whatever you write as truth.
10. **Minimum-necessary briefs:** the call brief is the ONLY thing the phone provider's agent knows, and the provider retains transcripts — so include only the data the task needs. Never paste KB profiles, documents, or unrelated customer details into a call task. The brief you show {{OPERATOR_FIRST_NAME}} for approval must be the complete, verbatim data the call will carry.
```

Then add this section right after the safety rules:

````
## Post-call report — MANDATORY on this install

Right after `ai-call` returns a `call_id`, launch the report watcher in the background (non-blocking), passing the same task brief you gave the call. This is NOT optional and does not depend on who was called (even a call to {{OPERATOR_FIRST_NAME}} gets a report):

```bash
nohup ~/.local/bin/python "$(dirname "$SCRIPT")/call_report.py" CALL_ID --provider vapi \
  --context "the task brief" --label "short label" \
  >> ~/.hermes/logs/call-reports.log 2>&1 &
```

(`--provider` must match the provider that placed the call; it defaults to `PHONE_PROVIDER`. Launching it via the background-process tool instead of `nohup` is fine — the script writes its own log line to `~/.hermes/logs/call-reports.log` either way.) It waits for the call to end, then automatically emails {{OPERATOR_FIRST_NAME}} (auto-allowed, operator-only) the **MP3 recording + full transcript as attachments** with a **model-synthesized breakdown** as the email body — on every terminal state, including failed calls — and posts a **3-line summary to the Slack home channel** (the transcript path is in the message; do NOT prompt {{OPERATOR_FIRST_NAME}} to file — if they ask to file something from the call, file from that transcript via the offer-then-file gate, never auto-file). Tell {{OPERATOR_FIRST_NAME}} the call is placed and the report will land in their inbox; don't poll `ai-status` yourself unless they ask live.

**This install's AI-call provider is Vapi** (`PHONE_PROVIDER=vapi`; the number is a Telnyx local number imported into Vapi — `TELNYX_PHONE_NUMBER` in `.env`; ElevenLabs voice; call model gpt-4.1). Use `ai-call ... --provider vapi`. Bland is not configured on this install (no key).
````

(On a Bland install, write `--provider bland` and the matching provider note instead.)

## 6. Don't forget the number's inbound side (both providers)

Outbound-only is a security property: nothing conversational may ever answer the agent's number.

**Vapi:** the imported number gets **no assistant**; a `call.ringing` hook says a fixed redirect and the call ends. One API call (or the equivalent in the dashboard's phone-number *Hooks* panel):

```json
PATCH https://api.vapi.ai/phone-number/{VAPI_PHONE_NUMBER_ID}
Authorization: Bearer <VAPI_API_KEY>
{
  "assistantId": null,
  "hooks": [{
    "on": "call.ringing",
    "do": [{ "type": "say",
             "exact": "This line does not take incoming calls. To reach {{BUSINESS_NAME}}, call <main business number>. Goodbye." }]
  }]
}
```

Verify: `GET /phone-number/{id}` shows `assistantId: null` and the hook; call the number from a cell — you hear the announcement and the line drops.

**Bland:** a purchased number auto-attaches a default inbound AI agent. Replace it with a **locked announce-and-hangup** — never converse, never follow caller instructions, no tools, `max_duration: 1`, `webhook: null`, first sentence redirecting callers to your main business line.

## 7. If you chose Bland — dedicated outbound caller ID

Legacy patch for the Bland path (dormant on a Vapi install; harmless to apply). In `_bland_call`, after the voice resolution block, add:

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
