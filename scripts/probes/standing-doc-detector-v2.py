#!/usr/bin/env python3
"""v2: narrowed after hand-classifying v1's 26 hits (5 TP / 21 FP)."""
import re, sys, pathlib
DATE = r"(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\s+\d{1,2},?\s+20\d\d"
CLASSES = {
 # 'deadline' alone is a ratified PROCESS term (the 🎓 deadline veto) -> dropped.
 # A bare date on its own line is the document footer -> excluded by the caller.
 "stop-condition": re.compile(r"hard stop|stop condition|ships? by " + DATE, re.I),
 # 'ID in scope' is the conventional-commit scope FIELD -> excluded explicitly.
 "scope-fence": re.compile(r"scope is\b|and nothing else|out of scope list|milestone is\b", re.I),
 "platform-minimum": re.compile(r"minimum\s+(?:ios|watchos|macos|android|python|node|java|rust|swift)|"
   r"\b(?:ios|ipados|watchos|macos|android)\s+\d+(?:\.\d+)?\+", re.I),
}
EXCLUDE = re.compile(r"\bid in scope\b|primary id in scope", re.I)
for path in sys.argv[1:]:
    p = pathlib.Path(path)
    try: lines = p.read_text(encoding="utf-8").splitlines()
    except Exception: continue
    for n, line in enumerate(lines, 1):
        s = line.strip()
        if not s or s.startswith("|"): continue
        if re.fullmatch(DATE, s, re.I): continue          # footer date stamp
        if EXCLUDE.search(s): continue
        for name, rx in CLASSES.items():
            m = rx.search(s)
            if m:
                print(f"{p.parts[-2]}\t{n}\t{name}\t{m.group(0)[:24]}\t{s[:92]}")
                break
