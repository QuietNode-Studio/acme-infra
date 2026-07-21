"""S2 reset: restore the canonical stg_orders.sql on acme-dbt main."""

import pathlib
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
from _lib import evidence
from _model_versions import GOOD

REPO = "https://github.com/QuietNode-Studio/acme-dbt.git"
MODEL = "models/staging/stg_orders.sql"


def run(cwd, *args):
    subprocess.run(args, cwd=cwd, check=True, capture_output=True, text=True)


def main():
    with tempfile.TemporaryDirectory() as tmp:
        run(None, "git", "clone", "--depth", "1", REPO, tmp)
        path = pathlib.Path(tmp) / MODEL
        if path.read_text() == GOOD:
            evidence("S2", "reset", "already green (canonical model on main)")
            print("S2 already green.")
            return
        path.write_text(GOOD, newline="\n")
        run(tmp, "git", "add", MODEL)
        run(tmp, "git", "commit", "-m", "revert: restore canonical stg_orders (scenario reset)")
        run(tmp, "git", "push", "origin", "main")
    evidence("S2", "reset", "canonical stg_orders restored on acme-dbt main")
    print("S2 reset: estate green (rerun dbt build to confirm).")


if __name__ == "__main__":
    main()
