#!/usr/bin/env python3
"""Merge a Windows Terminal settings fragment into an existing settings.json.

Deep-merges profiles.defaults (fragment keys win), upserts schemes[] by name,
and sets top-level launchMode. Prints the merged JSON to stdout. Never mutates
the input file; install.sh decides whether to write the result.
"""
import json
import sys


def deep_merge(base, overlay):
    for key, val in overlay.items():
        if isinstance(val, dict) and isinstance(base.get(key), dict):
            deep_merge(base[key], val)
        else:
            base[key] = val
    return base


def upsert_schemes(settings, schemes):
    existing = settings.setdefault("schemes", [])
    by_name = {s.get("name"): i for i, s in enumerate(existing) if isinstance(s, dict)}
    for scheme in schemes:
        name = scheme.get("name")
        if name in by_name:
            existing[by_name[name]] = scheme
        else:
            existing.append(scheme)


def main():
    fragment_path, settings_path = sys.argv[1], sys.argv[2]
    with open(fragment_path) as f:
        fragment = json.load(f)
    try:
        with open(settings_path) as f:
            settings = json.load(f)
    except (json.JSONDecodeError, ValueError) as err:
        print(f"wt-merge: {settings_path} is not valid JSON: {err}", file=sys.stderr)
        sys.exit(1)

    if "profiles" in fragment:
        deep_merge(settings.setdefault("profiles", {}), fragment["profiles"])
    if "launchMode" in fragment:
        settings["launchMode"] = fragment["launchMode"]
    if "schemes" in fragment:
        upsert_schemes(settings, fragment["schemes"])

    print(json.dumps(settings, indent=4))


if __name__ == "__main__":
    main()
