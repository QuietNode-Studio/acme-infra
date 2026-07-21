"""S1 reset: restore the good COLUMN_MAP, prove green."""

import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
from _lib import GOOD_COLUMN_MAP, evidence, get_env, invoke, set_env

FN = "acme-dev-orders-transform"


def main():
    env = get_env(FN)
    env["COLUMN_MAP"] = json.dumps(GOOD_COLUMN_MAP)
    set_env(FN, env)
    evidence("S1", "reset", f"COLUMN_MAP restored on {FN}")

    status, fn_error, body = invoke(FN)
    if not fn_error and status == 200:
        evidence("S1", "reset-verified", f"invocation green: {body[:120]}")
        print("S1 reset: estate green.")
    else:
        evidence("S1", "reset-FAILED", f"still failing: {body[:120]}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
