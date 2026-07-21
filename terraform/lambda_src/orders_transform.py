"""acme orders transform — the Lambda step of the dev batch pipeline.

Reads every CSV under s3://{RAW_BUCKET}/{INPUT_PREFIX}, projects columns
through COLUMN_MAP (logical field -> CSV header), converts amount_cents to a
decimal amount, and writes one curated JSONL per run to
s3://{CURATED_BUCKET}/{OUTPUT_PREFIX}.

COLUMN_MAP is deliberately config, not code: a wrong mapping is the classic
"upstream renamed a column / someone fat-fingered the console" failure, and it
makes the function fail LOUDLY (KeyError) — which is what scenario S1 arms.
"""

import csv
import io
import json
import os

import boto3

s3 = boto3.client("s3")


def handler(event, context):
    raw_bucket = os.environ["RAW_BUCKET"]
    curated_bucket = os.environ["CURATED_BUCKET"]
    input_prefix = os.environ.get("INPUT_PREFIX", "orders/")
    output_prefix = os.environ.get("OUTPUT_PREFIX", "orders/")
    column_map = json.loads(os.environ["COLUMN_MAP"])

    rows_out = 0
    out = io.StringIO()

    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=raw_bucket, Prefix=input_prefix):
        for obj in page.get("Contents", []):
            if not obj["Key"].endswith(".csv"):
                continue
            body = s3.get_object(Bucket=raw_bucket, Key=obj["Key"])["Body"].read().decode("utf-8")
            for row in csv.DictReader(io.StringIO(body)):
                record = {field: row[header] for field, header in column_map.items()}
                record["amount"] = round(int(record.pop("amount_cents")) / 100.0, 2)
                record["_source"] = f"s3://{raw_bucket}/{obj['Key']}"
                out.write(json.dumps(record) + "\n")
                rows_out += 1

    request_id = getattr(context, "aws_request_id", "local")
    out_key = f"{output_prefix.rstrip('/')}/curated_{request_id}.jsonl"
    s3.put_object(
        Bucket=curated_bucket,
        Key=out_key,
        Body=out.getvalue().encode("utf-8"),
        ContentType="application/x-ndjson",
    )
    return {"rows": rows_out, "output": f"s3://{curated_bucket}/{out_key}"}
