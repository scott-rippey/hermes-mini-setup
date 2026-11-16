"""skills-readonly: the agent never changes skills.

Skills are built and changed deliberately by the operator (with Claude Code), reviewed rather
than self-edited. On the reference build agent self-edits were messy: whole skills drafted on a
hunch, and lessons that queued quietly behind `/skills approve <id>`. Reading skills is unaffected.

Blocks, before dispatch:
  * skill_manage — every action (create / edit / patch / delete / write_file / remove_file / batch);
  * the generic file tools (write_file, patch) touching anything under ~/.hermes/skills/.
Terminal commands are not inspected; SOUL carries the same rule for that path.
"""
import os
from typing import Any, Optional

SKILLS_DIR = os.path.realpath(os.path.expanduser("~/.hermes/skills"))

_MSG = (
    "Blocked by the skills-readonly guard: skills are read-only to the agent on this box. "
    "If you learned something a skill should keep (a better step, a fix, a new procedure), "
    "tell the operator in plain words what you'd change and why, then carry on with the task; "
    "the operator makes skill changes deliberately.")


def _under_skills(path: str) -> bool:
    if not path:
        return False
    p = os.path.realpath(os.path.expanduser(str(path)))
    return p == SKILLS_DIR or p.startswith(SKILLS_DIR + os.sep)


def pre_tool_call(tool_name: str = "", args: Optional[dict] = None, task_id: str = "", **_: Any):
    args = args or {}
    if tool_name == "skill_manage":
        return {"action": "block", "message": _MSG}
    if tool_name in ("write_file", "patch"):
        text = str(args.get("patch") or "")
        if _under_skills(args.get("path", "")) or ".hermes/skills/" in text or SKILLS_DIR in text:
            return {"action": "block", "message": _MSG}
    return None


def register(ctx):
    ctx.register_hook("pre_tool_call", pre_tool_call)
