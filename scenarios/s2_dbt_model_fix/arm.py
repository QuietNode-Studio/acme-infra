"""S2 arm: land the staging defect on acme-dbt main (operator admin push).

Branch protection blocks non-admin direct pushes; the operator account is an
org admin, which is the documented break-glass used for arming drills.
"""

import pathlib
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
from _lib import evidence
from _model_versions import BROKEN

REPO = "https://github.com/QuietNode-Studio/acme-dbt.git"
MODEL = "models/staging/stg_orders.sql"


def run(cwd, *args):
    subprocess.run(args, cwd=cwd, check=True, capture_output=True, text=True)


def main():
    with tempfile.TemporaryDirectory() as tmp:
        run(None, "git", "clone", "--depth", "1", REPO, tmp)
        path = pathlib.Path(tmp) / MODEL
        if path.read_text() == BROKEN:
            evidence("S2", "arm", "already armed (defect present on main)")
            print("S2 already armed.")
            return
        path.write_text(BROKEN, newline="\n")
        run(tmp, "git", "add", MODEL)
        run(tmp, "git", "-c", "user.name=Acme Operator", "-c", "user.email=ops@acme-example.invalid",
            "commit", "-m", "chore: refresh staging logic for orders")
        run(tmp, "git", "push", "origin", "main")
    evidence("S2", "arm", "defect landed on acme-dbt main (amount x100, cus-0001 nulled)")
    print("S2 armed: dbt build on dev target will fail; ticket ACME-102 can be filed.")


if __name__ == "__main__":
    main()
