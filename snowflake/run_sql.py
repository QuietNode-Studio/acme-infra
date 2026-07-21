"""Run a .sql file against Snowflake statement-by-statement as the admin user.

Admin credentials come from env (SNOWFLAKE_ACCOUNT / SNOWFLAKE_USER /
SNOWFLAKE_PASSWORD). Nothing secret is ever printed or written.

    python snowflake/run_sql.py snowflake/estate.sql
"""

import os
import sys

import snowflake.connector


def statements(path):
    with open(path) as f:
        text = f.read()
    # strip line comments, split on ';'
    lines = [l for l in text.splitlines() if not l.strip().startswith("--")]
    for stmt in "\n".join(lines).split(";"):
        if stmt.strip():
            yield stmt.strip()


def main(path):
    conn = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        role=os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN"),
        login_timeout=30,
    )
    try:
        cur = conn.cursor()
        for i, stmt in enumerate(statements(path), 1):
            cur.execute(stmt)
            first = stmt.split("\n")[0][:88]
            print(f"[{i:02d}] ok: {first}")
    finally:
        conn.close()


if __name__ == "__main__":
    main(sys.argv[1])
