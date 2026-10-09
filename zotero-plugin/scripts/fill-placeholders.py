#!/usr/bin/env python3
"""Fill {{PLACEHOLDER}} tokens in every text file under a directory.

    python3 scripts/fill-placeholders.py <dir> KEY=VALUE [KEY=VALUE ...]

Used by new-minimal-plugin.sh; keys are the bare placeholder names (PLUGIN_NAME, PLUGIN_SLUG, ...).
YEAR defaults to the current year when not given.
"""
import datetime
import os
import sys

TEXT_EXT = {'.json', '.js', '.ftl', '.sh', '.md', '.txt', '.ts', '.xhtml', '.css', ''}


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    root = argv[1]
    subs = {'YEAR': str(datetime.date.today().year)}
    for pair in argv[2:]:
        key, _, value = pair.partition('=')
        subs[key] = value
    changed = 0
    for dirpath, _dirs, files in os.walk(root):
        for name in files:
            path = os.path.join(dirpath, name)
            if os.path.splitext(name)[1] not in TEXT_EXT:
                continue
            try:
                s = open(path, encoding='utf-8').read()
            except (UnicodeDecodeError, OSError):
                continue
            out = s
            for key, value in subs.items():
                out = out.replace('{{' + key + '}}', value)
            if out != s:
                open(path, 'w', encoding='utf-8').write(out)
                changed += 1
    print(f'filled placeholders in {changed} file(s)')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
