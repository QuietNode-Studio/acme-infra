"""S1 arm: corrupt COLUMN_MAP on the dev transform, prove the failure."""

import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
from _lib import GOOD_COLUMN_MAP, evidence, get_env, invoke, set_env

FN = "acme-dev-orders-transform"

BROKEN_MAP = dict(GOOD_COLUMN_MAP, amount_cents="amount")  # header does not exist


def main():
    env = get_env(FN)
    env["COLUMN_MAP"] = json.dumps(BROKEN_MAP)
    set_env(FN, env)
    evidence("S1", "arm", f"COLUMN_MAP corrupted on {FN} (amount_cents->amount)")

    status, fn_error, body = invoke(FN)
    if fn_error:
        evidence("S1", "arm-verified", f"invocation fails as designed: {body[:120]}")
    else:
        evidence("S1", "arm-UNEXPECTED", f"invocation did NOT fail (status={status}) — investigate")
        raise SystemExit(1)
    print("S1 armed: transform is broken, ticket ACME-101 can be filed.")


if __name__ == "__main__":
    main()
