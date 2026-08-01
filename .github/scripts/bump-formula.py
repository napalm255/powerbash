#!/usr/bin/env python3
"""Point the Homebrew formula at a new release.

Rewrites only the url and sha256 lines of Formula/powerbash.rb. The install
block, caveats, and test block stay in the tap repo and are not templated
here -- there is one copy of them, so there is nothing to drift.

    bump-formula.py <formula-path> <url> <sha256>

Exits non-zero unless it found exactly one url line and one sha256 line, so a
formula that has been restructured fails the release rather than being
silently left pointing at the previous version.
"""

import re
import sys


def main(argv):
    if len(argv) != 4:
        sys.exit(__doc__)

    path, url, sha256 = argv[1], argv[2], argv[3]

    if not re.fullmatch(r"[0-9a-f]{64}", sha256):
        sys.exit("not a sha256: %r" % sha256)

    with open(path) as f:
        src = f.read()

    src, n_url = re.subn(
        r'^(\s*url\s+)"[^"]*"$',
        lambda m: '%s"%s"' % (m.group(1), url),
        src,
        count=1,
        flags=re.M,
    )
    src, n_sha = re.subn(
        r'^(\s*sha256\s+)"[^"]*"$',
        lambda m: '%s"%s"' % (m.group(1), sha256),
        src,
        count=1,
        flags=re.M,
    )

    if n_url != 1 or n_sha != 1:
        sys.exit(
            "expected exactly one url and one sha256 line in %s "
            "(replaced %d and %d)" % (path, n_url, n_sha)
        )

    with open(path, "w") as f:
        f.write(src)

    print("%s -> %s" % (path, url))


if __name__ == "__main__":
    main(sys.argv)
