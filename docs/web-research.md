# Web research: Firecrawl vs Scrapling — which does what

Two different tools handle "go read the web" on this build. They're easy to confuse
because both are scrapers — but they sit at different layers and are set up in
different places, and only one of them appears in the skills list.

## The two layers

|                  | **Firecrawl**                                                              | **Scrapling**                                                        |
|------------------|----------------------------------------------------------------------------|----------------------------------------------------------------------|
| What it is       | Hosted API backing the agent's built-in `web_search` + `web_extract` tools | Bundled skill: a local stealth-scraping framework (open source, MIT) |
| Where it's set up| `web.backend` in `~/.hermes/config.yaml` + `FIRECRAWL_API_KEY` in `~/.hermes/.env` | Skills phase — it's in the enabled keep-set                          |
| Account / key    | Yes — free account at https://firecrawl.dev/ (500 credits/mo free tier)    | None. Fully local — no key, no account, no cost                      |
| Used for         | Everyday research: search the web, fetch and read normal pages             | Hard pages: Cloudflare/bot walls, JS-rendered content, multi-page spidering |

**Firecrawl is the front door; Scrapling is the crowbar.** The skills list only ever
mentions scrapling ("hard-page research fallback") because the front door is
configured as a *web backend*, not a skill — that's why an install can look like
"the scraper is scrapling" when the primary research path is actually Firecrawl.

## How the agent picks between them

1. A normal research ask goes to the built-in `web_search` (find sources) and
   `web_extract` (fetch + read them) — both served by Firecrawl.
2. Long pages (over ~5,000 characters) come back **summarized** by an auxiliary
   model rather than raw. That's by design (context and cost control), not a
   scraping failure.
3. When `web_extract` can't get the data — blocked, bot-check, JS-only content —
   the agent reaches for the **scrapling** skill, which has three fetch
   strategies (plain HTTP, real-browser JS, stealth/Cloudflare-bypass) plus a
   spider for crawling multiple pages. Its own SKILL.md tells the agent it's the
   fallback for exactly this case. (Phase 7 pre-arms it — package, browsers,
   PATH symlink, smoke test — so the fallback fires instantly when needed.)

## Setup this install needs (the step the phases don't cover)

Enabling the scrapling skill is **not** web-research setup. The built-in tools
need their backend key, or everyday `web_search`/`web_extract` calls have no
provider behind them:

1. Create a **free Firecrawl account** at https://firecrawl.dev/ — sign it up
   under the **agent's own identity/email**, not the operator's personal
   account, so the agent's third-party footprint stays auditable in one place.
2. Add the key to `~/.hermes/.env`:
   ```
   # Firecrawl — backend for built-in web_search + web_extract
   FIRECRAWL_API_KEY=fc-...
   ```
3. Confirm the backend in `~/.hermes/config.yaml` (Firecrawl is also the
   platform default, so this is usually already right):
   ```yaml
   web:
     backend: firecrawl
   ```
   Prefer interactive? `hermes tools` walks the same selection.
4. Restart the gateway (`hermes gateway restart`), then verify end-to-end: ask
   the agent to *"search the web for <today's anything> and quote one source."*
   Ranked results plus a real fetched quote proves both `web_search` and
   `web_extract` are live.

**Don't want another account?** DDGS (DuckDuckGo) is a keyless, free,
*search-only* backend — but then `web_extract` has no provider and the agent can
search but not read pages. The reference build uses Firecrawl for both.

## Cost expectations

- **Scrapling:** always free — local compute only.
- **Firecrawl:** 500 credits/mo on the free tier, plenty for a personal
  assistant's daily research. Usage is visible in the Firecrawl dashboard under
  the agent's account if volume ever grows.
