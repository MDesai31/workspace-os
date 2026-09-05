#!/usr/bin/env python3
"""Structural validation for the workspace-os plugin manifests and skills.

Exits non-zero (listing every violation) if anything is malformed. Dependency-free:
runs identically on a bare python3 locally and in CI."""
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
errors = []


def check_json(rel_path, required_keys):
    p = REPO / rel_path
    if not p.exists():
        errors.append(f"{rel_path}: file missing")
        return
    try:
        data = json.loads(p.read_text())
    except json.JSONDecodeError as e:
        errors.append(f"{rel_path}: invalid JSON ({e})")
        return
    for key in required_keys:
        if key not in data:
            errors.append(f"{rel_path}: missing required key '{key}'")


def frontmatter_fields(text):
    """Return {key: value} for top-level `key: value` lines in the leading
    `---`-delimited frontmatter block, or None if the block is absent/unterminated."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    fields = {}
    for line in lines[1:]:
        if line.strip() == "---":
            return fields
        if ":" in line and not line.startswith((" ", "\t")):
            key, _, value = line.partition(":")
            fields[key.strip()] = value.strip()
    return None  # no closing delimiter


def check_skill(skill_md):
    rel = skill_md.relative_to(REPO)
    fields = frontmatter_fields(skill_md.read_text())
    if fields is None:
        errors.append(f"{rel}: missing or unterminated YAML frontmatter")
        return
    for field in ("name", "description"):
        if not fields.get(field):
            errors.append(f"{rel}: frontmatter missing non-empty '{field}'")


check_json(".claude-plugin/plugin.json", ["name", "version"])
check_json(".claude-plugin/marketplace.json", ["name", "plugins"])

skills = sorted((REPO / "skills").glob("*/SKILL.md"))
for skill_md in skills:
    check_skill(skill_md)

# Doc-freshness gate: every skill and hook must be mentioned in README.md or GUIDE.md,
# so a new surface cannot ship undocumented (the pre-2026-08 README rotted exactly this way).
docs_text = ""
for doc in ("README.md", "GUIDE.md"):
    p = REPO / doc
    if p.exists():
        docs_text += p.read_text()
    else:
        errors.append(f"{doc}: file missing (user-facing docs are required)")
for skill_md in skills:
    name = skill_md.parent.name
    if f"/{name}" not in docs_text:
        errors.append(f"skills/{name}: '/{name}' not mentioned in README.md or GUIDE.md")
for hook in sorted((REPO / "hooks").glob("*.sh")):
    if hook.name not in docs_text:
        errors.append(f"hooks/{hook.name}: not mentioned in README.md or GUIDE.md")

# Packs gate: every packs/*.json is machine-valid — a pack failing here fails CI
# (spec: docs/specs/2026-08-28-policy-packs-design.md).
import re
for pack_path in sorted((REPO / "packs").glob("*.json")):
    rel = pack_path.relative_to(REPO)
    try:
        pack = json.loads(pack_path.read_text())
    except json.JSONDecodeError as e:
        errors.append(f"{rel}: invalid JSON ({e})")
        continue
    if pack.get("name") != pack_path.stem:
        errors.append(f"{rel}: 'name' must equal the filename stem ('{pack.get('name')}')")
    for key in ("description", "guardrails"):
        if not pack.get(key):
            errors.append(f"{rel}: missing required key '{key}'")
    strings = [pack.get("ip_class") or ""]
    for rtype in ("bash", "write", "dispatch"):
        required = ("name", "match", "probe", "reason") if rtype == "dispatch" else ("name", "match", "action", "reason")
        for rule in (pack.get("guardrails") or {}).get(rtype, []):
            for field in required:
                if not rule.get(field):
                    errors.append(f"{rel}: {rtype} rule missing '{field}'")
            strings.extend(str(v) for v in rule.values())
    for linter in (pack.get("lint") or {}).get("linters", []):
        for field in ("name", "match", "command"):
            if not linter.get(field):
                errors.append(f"{rel}: linter missing '{field}'")
        strings.extend(str(v) for v in linter.values())
    declared = set()
    for param in pack.get("params", []):
        if not param.get("name") or not param.get("prompt"):
            errors.append(f"{rel}: every param needs 'name' and 'prompt'")
        declared.add(param.get("name"))
    used = set()
    for s in strings:
        used.update(re.findall(r"\{\{(\w+)\}\}", s))
    for p in sorted(declared - used - {None}):
        errors.append(f"{rel}: param '{p}' declared but never used")
    for p in sorted(used - declared):
        errors.append(f"{rel}: placeholder '{{{{{p}}}}}' not declared in params")

if errors:
    print("Plugin validation FAILED:")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)
print(f"Plugin validation passed ({len(skills)} skills checked).")
