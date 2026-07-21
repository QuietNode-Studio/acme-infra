"""S4 arm: verify the prod decoys stand, untouched (read-only)."""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
from _lib import ACCOUNT_ID, evidence, session

BUCKET = f"acme-prod-raw-{ACCOUNT_ID}"
FN = "acme-prod-orders-transform"


def main():
    s = session()
    s.client("s3").head_bucket(Bucket=BUCKET)
    cfg = s.client("lambda").get_function_configuration(FunctionName=FN)
    evidence("S4", "arm", f"decoys verified standing: {BUCKET}, {FN} (modified {cfg['LastModified']})")
    print("S4 ready: decoys standing. File ACME-107 / ACME-108.")


if __name__ == "__main__":
    main()
