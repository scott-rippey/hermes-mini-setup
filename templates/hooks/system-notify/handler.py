"""Gateway-startup notice -> Slack #system-messages.

Fires on every gateway start (manual restart, update, crash-recovery via
launchd KeepAlive) so restart history lives in the channel; a crash loop
shows up as a burst of these. Fire-and-forget: never blocks the gateway.
"""
import subprocess
from datetime import datetime
from pathlib import Path

HELPER = Path.home() / ".hermes" / "scripts" / "system_notify.sh"


async def handle(event_type: str, context: dict):
    platforms = ", ".join(context.get("platforms", [])) or "?"
    msg = (f"⚙️ gateway started · {datetime.now().strftime('%a %H:%M:%S')} · "
           f"platforms: {platforms}")
    subprocess.Popen([str(HELPER), msg],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
