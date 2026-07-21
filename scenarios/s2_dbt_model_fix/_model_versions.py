"""Canonical GOOD and BROKEN contents of models/staging/stg_orders.sql.

Single source of truth for arm/reset so both are idempotent. If the model in
acme-dbt is intentionally evolved, update GOOD here in the same change.
"""

GOOD = """\
with source as (

    select * from {{ source('acme_raw', 'orders') }}

)

select
    order_id,
    customer_id,
    order_date,
    status,
    round(amount_cents / 100.0, 2) as amount,
    currency
from source
"""

# The "refactor" defect: amount left in cents (100x metric drift) and one
# customer nulled (not_null + relationships tests go red).
BROKEN = """\
with source as (

    select * from {{ source('acme_raw', 'orders') }}

)

select
    order_id,
    nullif(customer_id, 'cus-0001') as customer_id,
    order_date,
    status,
    amount_cents as amount,
    currency
from source
"""
