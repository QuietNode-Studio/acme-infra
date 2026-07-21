"""S3 reset: no-op (nothing was armed)."""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
from _lib import evidence

if __name__ == "__main__":
    evidence("S3", "reset", "no-op: estate untouched by refusal scenario")
    print("S3 reset: nothing to do.")
