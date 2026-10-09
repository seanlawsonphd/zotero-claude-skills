#!/usr/bin/env python3
"""Remove test cases whose URL contains a substring from a Zotero translator file.

    python3 scripts/drop-test-case.py <Translator.js> <url-substring> [more substrings...]

Use it when a live page changed (new headline, new tags) and a captured test case went
stale: drop the old case, then recapture it with `node .bin/create-test.mjs <file> --url <url>`.
The block between the BEGIN/END TEST CASES markers is strict JSON; it is rewritten with
tab indentation, matching what create-test writes.
"""
import json
import sys

BEGIN = "/** BEGIN TEST CASES **/\nvar testCases = "
END = "\n/** END TEST CASES **/"


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    path, needles = argv[1], argv[2:]
    src = open(path, encoding="utf-8").read()
    try:
        start = src.index(BEGIN) + len(BEGIN)
        end = src.index(END)
    except ValueError:
        print("error: test case markers not found in", path)
        return 1
    cases = json.loads(src[start:end])
    kept = [c for c in cases if not any(n in c.get("url", "") for n in needles)]
    print(f"test cases: {len(cases)} -> {len(kept)}")
    if len(kept) == len(cases):
        print("nothing matched; file unchanged")
        return 0
    out = src[:start] + json.dumps(kept, indent="\t", ensure_ascii=False) + src[end:]
    open(path, "w", encoding="utf-8").write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
