#!/usr/bin/env python3
"""定位真实资源和项目档案，或为全新项目建立档案。只使用标准库。"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RECORD_NAMES = ("PROJECT-DESIGN.md", "DESIGN.md", "docs/design.md")


def read_registry():
    return json.loads((ROOT / "references/resources.json").read_text(encoding="utf-8"))


def records(project):
    return [project / name for name in RECORD_NAMES if (project / name).is_file()]


def require_project_directory(project):
    if not project.exists():
        raise ValueError("目标项目目录不存在，请核对 --project 路径。")
    if not project.is_dir():
        raise ValueError("目标项目路径不是目录，请核对 --project 路径。")


def context(project):
    require_project_directory(project)
    registry = read_registry()
    entries = []
    for entry in registry["resources"]:
        path = ROOT / entry["path"]
        entries.append({**entry, "path": str(path), "resolved_path": str(path.resolve()), "exists": path.is_file()})
    existing = records(project)
    return {
        "skill_root": str(ROOT), "phase": registry["phase"], "project": str(project), "project_exists": True,
        "project_record": str(existing[0] if existing else project / RECORD_NAMES[0]),
        "project_record_exists": bool(existing),
        "record_names_checked": list(RECORD_NAMES),
        "other_record_candidates": [str(path) for path in existing[1:]],
        "resources": entries, "capabilities": registry["capabilities"],
    }


def check():
    missing = []
    resources = []
    for entry in read_registry()["resources"]:
        path = ROOT / entry["path"]
        if not path.is_file():
            missing.append(entry["id"])
            continue
        resources.append({"id": entry["id"], "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "state": entry["state"]})
    return {"ok": not missing, "missing": missing, "resources": resources}


def init_record(project, name, purpose):
    require_project_directory(project)
    existing = records(project)
    if existing:
        raise ValueError("已有设计档案，请复用：" + str(existing[0]))
    destination = project / RECORD_NAMES[0]
    content = (ROOT / "templates/PROJECT-DESIGN.md").read_text(encoding="utf-8")
    content = content.replace("{{project_name}}", name).replace("{{project_purpose}}", purpose)
    with destination.open("x", encoding="utf-8") as target:
        target.write(content)
    return {"created": str(destination)}


def install(target):
    if target.is_symlink() or target.exists():
        if target.resolve() == ROOT:
            return {"installed": str(target), "source": str(ROOT), "changed": False}
        raise ValueError("安装入口已有其他内容，拒绝覆盖：" + str(target))
    target.parent.mkdir(parents=True, exist_ok=True)
    target.symlink_to(ROOT, target_is_directory=True)
    return {"installed": str(target), "source": str(ROOT), "changed": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    current = commands.add_parser("context", help="只读列出本次任务的资料入口")
    current.add_argument("--project", type=Path, required=True)
    commands.add_parser("check", help="检查资源是否存在并记录摘要")
    create = commands.add_parser("init-record", help="仅为尚无档案的项目写入模板")
    create.add_argument("--project", type=Path, required=True)
    create.add_argument("--name", required=True)
    create.add_argument("--purpose", required=True)
    registration = commands.add_parser("install", help="建立指向本机源目录的使用入口，不覆盖已有内容")
    registration.add_argument("--target", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == "context":
            result = context(args.project.expanduser().resolve())
        elif args.command == "check":
            result = check()
        elif args.command == "init-record":
            result = init_record(args.project.expanduser().resolve(), args.name, args.purpose)
        else:
            result = install(args.target.expanduser().absolute())
        print(json.dumps(result, ensure_ascii=False, indent=2))
        if result.get("ok") is False:
            return 1
        return 0
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(json.dumps({"error": str(error)}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
