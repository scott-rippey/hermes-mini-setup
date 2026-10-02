"""social-readonly — Hermes plugin: the browser is read-only on social media.

The research Chrome profile (``browser.use_real_profile``) holds a real Instagram
login, so a click there is a real action on that account. SOUL.md states the
rule; this plugin enforces it: a ``pre_tool_call`` hook vetoes every browser
tool that could *act* on a page served from a social host (click, type, key
press, JS eval) and every navigation to the account / DM / composer areas.
Reading stays open — navigate, snapshot, scroll, back, get_images, vision.

Update-proof: a plugin hook, not a source patch. Fail-closed: if the current
page URL cannot be read, the interaction is refused.
"""
from typing import Any, Optional
from urllib.parse import urlsplit

READ_ONLY_HOSTS = (
    "instagram.com", "threads.net", "facebook.com", "tiktok.com",
    "x.com", "twitter.com", "linkedin.com", "youtube.com", "reddit.com",
)
ACTION_TOOLS = ("browser_click", "browser_type", "browser_press")
# Account settings, login, DMs, the composer — never a research destination.
BLOCKED_PATH_PREFIXES = ("/accounts/", "/direct/", "/create/")


def _social_host(url: str) -> Optional[str]:
    host = (urlsplit(url).hostname or "").lower()
    for h in READ_ONLY_HOSTS:
        if host == h or host.endswith("." + h):
            return h
    return None


def _current_url(task_id: str) -> Optional[str]:
    """The task's current page URL, or None when it cannot be read."""
    from tools import browser_tool as bt
    key = bt._last_session_key(task_id or "default")
    res = bt._session._run_browser_command(
        key, "eval", ["window.location.href"], timeout=5, _engine_override="auto")
    if not res.get("success"):
        return None
    return str(res.get("data", {}).get("result", "")).strip().strip('"').strip("'") or None


def _block(tool_name: str, host: str) -> dict:
    return {"action": "block", "message": (
        f"Blocked by the social-readonly guard: {tool_name} on {host}. Social-media sites are "
        "READ-ONLY for research — never like, follow, comment, post, DM, log in, or open account "
        "pages. Use browser_snapshot, browser_scroll, browser_get_images or vision instead.")}


def pre_tool_call(tool_name: str = "", args: Optional[dict] = None, task_id: str = "", **_: Any):
    args = args or {}
    if tool_name == "browser_navigate":
        url = str(args.get("url") or "")
        host = _social_host(url)
        if host and urlsplit(url).path.startswith(BLOCKED_PATH_PREFIXES):
            return _block(tool_name, host)
        return None
    is_eval = tool_name == "browser_console" and args.get("expression") is not None
    if tool_name not in ACTION_TOOLS and not is_eval:
        return None
    try:
        url = _current_url(task_id)
    except Exception:
        url = None
    if url is None:
        return {"action": "block", "message": (
            f"Blocked by the social-readonly guard: could not read the current page URL, so "
            f"{tool_name} is refused (fail-closed). Call browser_snapshot first and retry.")}
    host = _social_host(url)
    return _block(tool_name, host) if host else None


def register(ctx):
    ctx.register_hook("pre_tool_call", pre_tool_call)
