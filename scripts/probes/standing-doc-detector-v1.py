#!/usr/bin/env python3
"""Candidate detector for the ABSENCE rule turing-review proposed:
   'CLAUDE.md and agent briefs hold no milestone-scoped fact.'
Three claim classes. Reports every hit for hand-classification."""
import re, sys, pathlib

CLASSES = {
 "stop-condition": re.compile(r"hard stop|stop condition|ships? by|due (?:by|on)|deadline|"
   r"\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\s+\d{1,2},?\s+20\d\d", re.I),
 "scope-fence": re.compile(r"scope is|in scope|out of scope|and nothing else|"
   r"phase\s*\d|\bv\d+(?:\.\d+)?\s+(?:is|only|scope)|milestone is", re.I),
 "platform-minimum": re.compile(r"minimum\s+(?:ios|watchos|macos|android|python|node|java|rust|swift)|"
   r"\b(?:ios|watchos|macos|android)\s+\d+(?:\.\d+)?\+?\b|targets?\s+\w+\s+\d+\.\d+", re.I),
}

for path in sys.argv[1:]:
    p = pathlib.Path(path)
    try: lines = p.read_text(encoding="utf-8").splitlines()
    except Exception: continue
    for n, line in enumerate(lines, 1):
        if line.strip().startswith("|") or not line.strip(): continue
        for name, rx in CLASSES.items():
            m = rx.search(line)
            if m:
                print(f"{p.parts[-2] if len(p.parts)>1 else p}\t{n}\t{name}\t{m.group(0)[:28]}\t{line.strip()[:95]}")
                break
