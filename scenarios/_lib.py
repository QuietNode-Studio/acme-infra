"""Shared helpers for scenario arm/reset scripts.

These scripts are OPERATOR tooling: they run on the platform team's
credentials (default AWS chain / gh auth), never Pumpkin's. Arming a scenario
means deliberately breaking the estate the way a careless human would; Pumpkin
must then fix it through its governed paths.
"""

import datetime
import json
import os
import pathlib

import boto3

REGION = "us-east-2"
ACCOUNT_ID = "488179516291"
EVIDENCE = pathlib.Path(__file__).parent / "EVIDENCE.md"

GOOD_COLUMN_MAP = {
    "order_id": "order_id",
    "customer_id": "customer_id",
    "order_date": "order_date",
    "status": "status",
    "amount_cents": "amount_cents",
    "currency": "currency",
}


def session():
    return boto3.Session(region_name=REGION)


def evidence(scenario, action, detail):
    """Append one evidence line; secrets must never be passed in `detail`."""
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"| {stamp} | {scenario} | {action} | {detail} |\n"
    with open(EVIDENCE, "a", encoding="utf-8", newline="\n") as f:
        f.write(line)
    print(f"evidence: {scenario} {action}: {detail}")


def get_env(fn_name):
    lam = session().client("lambda")
    cfg = lam.get_function_configuration(FunctionName=fn_name)
    return cfg["Environment"]["Variables"]


def set_env(fn_name, env):
    lam = session().client("lambda")
    lam.update_function_configuration(FunctionName=fn_name, Environment={"Variables": env})
    waiter = lam.get_waiter("function_updated_v2")
    waiter.wait(FunctionName=fn_name)


def invoke(fn_name, payload=None):
    """Operator-side invoke. Returns (status_code, function_error, body)."""
    lam = session().client("lambda")
    resp = lam.invoke(FunctionName=fn_name, Payload=json.dumps(payload or {}).encode())
    body = resp["Payload"].read().decode("utf-8", errors="replace")[:400]
    return resp["StatusCode"], resp.get("FunctionError", ""), body
