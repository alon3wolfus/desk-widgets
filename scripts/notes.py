#!/usr/bin/env python3
"""Reads an Obsidian vault (plain Markdown files) for the desk-widgets notes card. Read only.

notes.py recent VAULT FOLDER COUNT EXCLUDE   most recently edited notes as JSON:
    {"vault": name, "notes": [{"path", "title", "modified", "snippet"}]}
notes.py note VAULT PATH                     one note, cleaned up for display:
    {"vault": name, "path", "title", "modified", "snippet", "body"}

VAULT empty means the vault Obsidian has open (from ~/.config/obsidian/obsidian.json).
EXCLUDE is a comma-separated list of folders to skip. Dot folders are always skipped.
"""
import json
import os
import re
import sys

HOME = os.path.expanduser("~")
CONFIG = os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config")


def find_vault():
    for path in (os.path.join(CONFIG, "obsidian", "obsidian.json"),
                 os.path.join(HOME, ".var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json")):
        try:
            vaults = json.load(open(path)).get("vaults", {}).values()
        except (OSError, ValueError):
            continue
        vaults = sorted(vaults, key=lambda v: (not v.get("open"), -v.get("ts", 0)))
        if vaults:
            return vaults[0]["path"]
    return ""


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def strip_frontmatter(text):
    if text.startswith("---\n"):
        end = text.find("\n---", 4)
        if end != -1:
            return text[end + 4:].lstrip("\n")
    return text


def inline(text):
    """Obsidian syntax to plain Markdown: embeds dropped, wikilinks to their label."""
    text = re.sub(r"!\[\[[^\]]*\]\]", "", text)
    text = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", text)
    text = re.sub(r"\[\[([^\]|#]*)(?:#[^\]|]*)?\|([^\]]*)\]\]", r"\2", text)
    text = re.sub(r"\[\[([^\]|#]*)(?:#([^\]|]*))?\]\]", lambda m: m.group(1) or m.group(2) or "", text)
    text = re.sub(r"%%.*?%%", "", text, flags=re.S)
    text = re.sub(r"==([^=]+)==", r"\1", text)
    return text


def title_and_body(path):
    text = strip_frontmatter(read(path))
    title = os.path.splitext(os.path.basename(path))[0]
    lines = text.split("\n")
    for i, line in enumerate(lines):
        if line.strip() == "":
            continue
        m = re.match(r"#\s+(.+)", line)
        if m:
            title = inline(m.group(1)).strip()
            lines = lines[i + 1:]
        elif re.sub(r"^#+\s*", "", line).strip().lower() == title.lower():
            lines = lines[i + 1:]  # first line just repeats the file name
        break
    return title, inline("\n".join(lines)).strip()


def snippet(body):
    out = []
    for line in body.split("\n"):
        line = line.strip()
        if not line or line.startswith("```") or re.fullmatch(r"[-*_|: ]+", line):
            continue
        line = re.sub(r"^#+\s*", "", line)
        line = re.sub(r"^[-*+]\s+\[[ ]\]\s*", "☐ ", line)
        line = re.sub(r"^[-*+]\s+\[[xX]\]\s*", "☑ ", line)
        line = re.sub(r"^([-*+]|\d+\.)\s+", "", line)
        line = re.sub(r"^>\s*(\[![^\]]*\][-+]?\s*)?", "", line)
        line = re.sub(r"[*_`~]", "", line)
        line = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", line)
        if line:
            out.append(line)
        if sum(len(l) for l in out) > 160:
            break
    return " ".join(out)[:200]


def recent(vault, folder, count, exclude):
    root = os.path.join(vault, folder) if folder else vault
    skip = {e.strip().strip("/") for e in exclude.split(",") if e.strip()}
    found = []
    for dirpath, dirs, files in os.walk(root):
        rel_dir = os.path.relpath(dirpath, vault)
        dirs[:] = [d for d in dirs if not d.startswith(".")
                   and os.path.normpath(os.path.join(rel_dir, d)) not in skip and d not in skip]
        for name in files:
            if name.endswith(".md"):
                full = os.path.join(dirpath, name)
                try:
                    st = os.stat(full)
                except OSError:
                    continue
                if st.st_size > 0:
                    found.append((st.st_mtime, full))
    found.sort(reverse=True)
    notes = []
    for mtime, full in found[:count]:
        title, body = title_and_body(full)
        notes.append({"path": os.path.relpath(full, vault), "title": title,
                      "modified": int(mtime * 1000), "snippet": snippet(body)})
    return notes


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "recent"
    vault = os.path.expanduser(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] else find_vault()
    out = {"vault": os.path.basename(vault.rstrip("/")), "found": bool(vault) and os.path.isdir(vault)}
    if not out["found"]:
        print(json.dumps(out))
        return
    if mode == "note":
        rel = sys.argv[3] if len(sys.argv) > 3 else ""
        if rel and not rel.endswith(".md"):
            rel += ".md"
        full = os.path.normpath(os.path.join(vault, rel))
        if rel and full.startswith(os.path.normpath(vault) + os.sep) and os.path.isfile(full):
            title, body = title_and_body(full)
            out.update(path=rel, title=title, modified=int(os.stat(full).st_mtime * 1000), body=body,
                       snippet=snippet(body))
    else:
        folder = sys.argv[3] if len(sys.argv) > 3 else ""
        count = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4] else 6
        exclude = sys.argv[5] if len(sys.argv) > 5 else ""
        out["notes"] = recent(vault, folder.strip("/"), count, exclude)
    print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()
