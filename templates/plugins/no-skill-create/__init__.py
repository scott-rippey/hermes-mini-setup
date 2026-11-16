"""no-skill-create: the agent never creates skills.

Skills are built deliberately by the operator (with Claude Code). On the reference build, the
approval queue kept filling with whole skills the agent drafted mid-task on its own.

Blocks, before dispatch:
  * skill_manage with action "create", directly or inside a batch's operations;
  * the generic file tools (write_file, patch) touching anything under ~/.hermes/skills/ —
    every agent change to a skill must go through skill_manage, which stages it for approval.
Edits to existing skills via skill_manage still go to the approval queue as before.
"""
import os
from typing import Any, Optional

SKILLS_DIR = os.path.realpath(os.path.expanduser("~/.hermes/skills"))

_CREATE_MSG = (
    "Blocked by the no-skill-create guard: the agent does not create skills on this box. "
    "If a reusable skill would help, say so to the operator in plain words (what it would do and why) "
    "and carry on with the task; the operator builds skills deliberately.")
_FILE_MSG = (
    "Blocked by the no-skill-create guard: skill files can't be written with file tools. "
    "Use skill_manage for changes to an existing skill (they stage for approval).")


def _under_skills(path: str) -> bool:
    if not path:
        return False
    p = os.path.realpath(os.path.expanduser(str(path)))
    return p == SKILLS_DIR or p.startswith(SKILLS_DIR + os.sep)


def pre_tool_call(tool_name: str = "", args: Optional[dict] = None, task_id: str = "", **_: Any):
    args = args or {}
    if tool_name == "skill_manage":
        ops = args.get("operations") or []
        if str(args.get("action", "")).lower() == "create" or any(
                isinstance(o, dict) and str(o.get("action", "")).lower() == "create" for o in ops):
            return {"action": "block", "message": _CREATE_MSG}
        return None
    if tool_name in ("write_file", "patch"):
        if _under_skills(args.get("path", "")):
            return {"action": "block", "message": _FILE_MSG}
        text = str(args.get("patch") or "")
        if ".hermes/skills/" in text or SKILLS_DIR in text:
            return {"action": "block", "message": _FILE_MSG}
    return None


def register(ctx):
    ctx.register_hook("pre_tool_call", pre_tool_call)
