"""Materialize service-user credentials: generate → set in Snowflake → store in
AWS Secrets Manager → (optionally) push to acme-dbt GitHub Actions secrets.

The ONLY place a service password ever exists in the clear is this process's
memory. Never printed, never written to disk, never in git, never in chat.

Requires: admin Snowflake env vars (SNOWFLAKE_ACCOUNT/USER/PASSWORD), working
AWS credentials, and (for --gh-secrets) an authed `gh` CLI.

    python snowflake/materialize_credentials.py [--gh-secrets]
"""

import json
import os
import secrets
import string
import subprocess
import sys

import boto3
import snowflake.connector

REGION = "us-east-2"
ACCOUNT = os.environ["SNOWFLAKE_ACCOUNT"]
DBT_REPO = "QuietNode-Studio/acme-dbt"

SERVICE_USERS = {
    "SVC_PUMPKIN_VALIDATE": {
        "secret_name": "acme/snowflake/pumpkin-validate",
        "role": "PUMPKIN_VALIDATE",
    },
    "SVC_DBT_RUNNER_DEV": {
        "secret_name": "acme/snowflake/dbt-runner-dev",
        "role": "DBT_RUNNER_DEV",
    },
}


def generate_password():
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(28))


def main(push_gh_secrets):
    conn = snowflake.connector.connect(
        account=ACCOUNT,
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        role=os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN"),
        login_timeout=30,
    )
    sm = boto3.client("secretsmanager", region_name=REGION)
    cur = conn.cursor()

    for user, cfg in SERVICE_USERS.items():
        pw = generate_password()
        # identifier is code-controlled; password passed as bound parameter is
        # not supported for ALTER USER, so it is embedded — connector logs are
        # off and the statement is never echoed.
        cur.execute(f"ALTER USER {user} SET PASSWORD = '{pw}'")

        payload = json.dumps({
            "account": ACCOUNT,
            "user": user,
            "password": pw,
            "role": cfg["role"],
            "warehouse": "ACME_WH_XS",
            "database": "ACME_DEV",
        })
        try:
            sm.create_secret(Name=cfg["secret_name"], SecretString=payload)
            action = "created"
        except sm.exceptions.ResourceExistsException:
            sm.put_secret_value(SecretId=cfg["secret_name"], SecretString=payload)
            action = "rotated"
        print(f"{user}: password set, secret {cfg['secret_name']} {action}")

        if push_gh_secrets and user == "SVC_DBT_RUNNER_DEV":
            for key, value in {
                "SNOWFLAKE_ACCOUNT": ACCOUNT,
                "SNOWFLAKE_USER": user,
                "SNOWFLAKE_PASSWORD": pw,
            }.items():
                subprocess.run(
                    ["gh", "secret", "set", key, "--repo", DBT_REPO],
                    input=value.encode(), check=True,
                )
            print(f"gh secrets set on {DBT_REPO}: SNOWFLAKE_ACCOUNT/USER/PASSWORD")

    conn.close()


if __name__ == "__main__":
    main(push_gh_secrets="--gh-secrets" in sys.argv)
