# Meeting Intelligence Pipeline (optional module)

> Three cooperating pieces: **meeting notes → nightly reports → KB**, **inline delivery in the morning brief**, and a **15-minute prep poller** before upcoming meetings — plus traffic-aware "leave by" guidance. Meetings become structured, searchable, and pre-briefed without the operator doing anything.

## Source: a meeting-notes tool (reference build: Granola, via MCP)

Wire your notes tool as an MCP server if it offers one. OAuth gotcha worth knowing: gateways can't do interactive OAuth, and some MCP login flows need a real TTY with tight timeouts — a `pty` wrapper (and temporarily bumping the connect timeout) gets the token cached; it's smooth after that.

## Nightly reports (10:00p)

A skill run headlessly each night:

1. Pull recent meetings; dedupe via a local `processed.json`.
2. Author each report; render **Markdown + email-safe HTML** (inline delivery beats attachments).
3. **Resolve who it was:** counterpart name → person → company (a multi-company person resolves to their primary). Unmatched name → a Slack prompt asking the operator to assign it — never guess.
4. **File it** via `add_meeting` — a sanctioned deterministic write: the structured `meetings` row (unique meeting-id dedupe, FKs to customer/person) + the searchable KB doc.
5. Queue the rendered HTML for the next morning's brief.

## Meeting prep — every 15 minutes

A **poll, deliberately not a calendar webhook** (push needs a public endpoint + domain verification + weekly channel renewal — against the no-ingress posture; a poll handles reschedules and cancellations for free):

- Scans the shared calendar for meetings starting within ~2h that have a real external counterpart (skips all-day/solo/declined; one prep per meeting via a dedup ledger).
- Builds the prep from the **KB** (who they are, company/role, past meetings, filed docs) + **recent email** with them + the invite → a sharp HTML email: the relationship, what's open, a "walk in ready" list.
- Quiet ticks log one line each; the digest treats **poller staleness >35m as FAIL** — a dead poller can't hide.

## Travel: "leave by" (traffic-aware)

When the invite's `location` is a **physical address** (URLs/Zoom/Meet/Teams ⇒ skip entirely — no address means travel info isn't wanted), prep computes the drive from the operator's home and renders a green card: **"Leave by H:MM"** = start − drive − 10-min buffer, with the fact also feeding the synthesis.

- **Primary: Google Routes API, `TRAFFIC_AWARE`, two-pass** — pass 1 estimates the drive, pass 2 recomputes at the actual departure time (predictive traffic for when you'll really be on the road). ≤2 calls per prepped meeting; ~10 addressed meetings/month sits far inside the 5,000 free traffic-aware calls/month. Key: Routes-restricted, in `.env`. (The reference build shipped a keyless typical-time version first and switched the same day — for a "leave by" number, traffic-awareness is the point. Ship Google-primary.)
- **Fallback: OpenStreetMap/OSRM via the maps skill** (keyless) — any Google failure degrades to a typical-time estimate with an honest label switch ("Live + predicted traffic (Google Routes)" vs. "Typical drive time (OpenStreetMap) — no live traffic data").
- **Solo appointments still get travel (2026-07-17):** an event with a physical address but no other attendees skips the full prep (no one to research) and instead sends a compact deterministic reminder — title, time, place, **leave by** — same travel engine, no synthesis. No address and no attendees → silence, as before.
- **Override = no code:** plans changed, different origin → ask the agent live in Slack; the maps skill routes from anywhere on demand.
- ⚠️ The OSM path must run on the **venv python** — Apple's `/usr/bin/python3` fails TLS to OSM hosts.

## Field notes

`psql -c` doesn't expand `:'var'` bindings — feed SQL via stdin; newline-bearing snippets in query output need the record-separator trick (`-R $'\x1e'`). GCP billing accounts cap linked projects — "cannot enable billing" usually means unlink idle projects, not make a new account.
