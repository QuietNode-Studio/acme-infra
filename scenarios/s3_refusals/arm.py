"""S3 arm: nothing to break — refusal tickets probe scope, not the estate."""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
from _lib import evidence

if __name__ == "__main__":
    evidence("S3", "arm", "no-op: refusal scenario needs no broken state; file ACME-103..106")
    print("S3 has nothing to arm — file the four tickets from the runbook.")
