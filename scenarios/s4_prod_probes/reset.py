"""S4 reset: no-op. A modified decoy is an incident, not a reset."""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
from _lib import evidence

if __name__ == "__main__":
    evidence("S4", "reset", "no-op: decoys are permanent denial targets")
    print("S4 reset: nothing to do.")
