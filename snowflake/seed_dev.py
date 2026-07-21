"""Seed ACME_DEV.RAW with deterministic orders/customers volume.

Idempotent: CREATE OR REPLACE + fixed rng seed → identical data every run.
Run as the admin user (env vars, see run_sql.py). The dbt project's sources
point at exactly these two tables.

    python snowflake/seed_dev.py
"""

import os
import random
from datetime import date, timedelta

import snowflake.connector

N_CUSTOMERS = 400
N_ORDERS = 5000
SEED = 7
START = date(2025, 7, 1)
DAYS = 365

SEGMENTS = ["new", "occasional", "loyal", "at_risk", "churned"]
STATUSES = ["delivered"] * 6 + ["shipped", "processing", "returned", "cancelled"]


def main():
    rng = random.Random(SEED)
    conn = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        role=os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN"),
        warehouse="ACME_WH_XS",
        database="ACME_DEV",
        schema="RAW",
        login_timeout=30,
    )
    cur = conn.cursor()

    cur.execute("""
        CREATE OR REPLACE TABLE ACME_DEV.RAW.CUSTOMERS (
            CUSTOMER_ID VARCHAR, EMAIL VARCHAR, FULL_NAME VARCHAR,
            SIGNED_UP_ON DATE, SEGMENT VARCHAR
        )""")
    customers = []
    for i in range(1, N_CUSTOMERS + 1):
        cid = f"cus-{i:04d}"
        customers.append((
            cid, f"user{i}@acme-example.com", f"Customer {i:04d}",
            (START - timedelta(days=rng.randint(30, 900))).isoformat(),
            rng.choice(SEGMENTS),
        ))
    cur.executemany("INSERT INTO ACME_DEV.RAW.CUSTOMERS VALUES (%s,%s,%s,%s,%s)", customers)

    cur.execute("""
        CREATE OR REPLACE TABLE ACME_DEV.RAW.ORDERS (
            ORDER_ID VARCHAR, CUSTOMER_ID VARCHAR, ORDER_DATE DATE,
            STATUS VARCHAR, AMOUNT_CENTS NUMBER, CURRENCY VARCHAR
        )""")
    orders = []
    for i in range(1, N_ORDERS + 1):
        orders.append((
            f"ord-{i:06d}", f"cus-{rng.randint(1, N_CUSTOMERS):04d}",
            (START + timedelta(days=rng.randint(0, DAYS - 1))).isoformat(),
            rng.choice(STATUSES), rng.randint(500, 250000), "USD",
        ))
    cur.executemany("INSERT INTO ACME_DEV.RAW.ORDERS VALUES (%s,%s,%s,%s,%s,%s)", orders)

    cur.execute("SELECT COUNT(*) FROM ACME_DEV.RAW.CUSTOMERS")
    n_cus = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM ACME_DEV.RAW.ORDERS")
    n_ord = cur.fetchone()[0]
    print(f"seeded ACME_DEV.RAW: customers={n_cus} orders={n_ord}")
    conn.close()


if __name__ == "__main__":
    main()
