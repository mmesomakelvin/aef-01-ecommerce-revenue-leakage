# Lumen & Loom — Revenue Leakage Review

Analytics Engineering Fellowship, **Engagement 01**.

A dbt project on Snowflake that reconciles a fictional e-commerce retailer's
reported revenue against what can actually be defended, and quantifies the gap.

**Headline: reported revenue overstates defensible revenue by $407,940 — 13.9%.**

Full client write-up: **[FINDINGS.md](FINDINGS.md)**

---

## The problem

Finance sums the payment gateway's successful transactions and reports
$2,940,566 for 2024. That figure includes payments logged twice, orders that
were cancelled but still charged, orders that never progressed past checkout,
and refunds recorded in the wrong period.

Nobody had measured the difference, because the annual total reconciles to the
bank perfectly. The errors only show up when you look at the composition.

## The answer

| Step | Line item | Amount |
|---|---|---|
| 1 | Gateway total: all successful payments | 2,940,565.58 |
| 2 | Less: duplicate payment webhooks | (41,396.82) |
| 3 | Less: cancelled orders that were charged | (131,272.28) |
| 4 | Less: placed orders that were charged | (66,728.17) |
| 5 | Less: charged with no shipping evidence | 0.00 |
| 6 | Less: refunds on recognised orders | (168,542.64) |
| 7 | **Defensible revenue** | **2,532,625.67** |

Plus four findings that carry no adjustment but change how the business should
operate — see [FINDINGS.md](FINDINGS.md) §2.4 through §2.8.

---

## Project structure

```
models/
  staging/       one model per source table — renaming and types only
  intermediate/  deduplication, then one revenue verdict per order
  marts/         the client-facing reports
tests/           singular tests, including the bridge reconciliation
```

| Model | Purpose |
|---|---|
| `stg_orders`, `stg_payments`, `stg_refunds`, `stg_shipping` | Cleaned source data. No filtering, no business logic |
| `int_payments_deduplicated` | Removes 642 duplicate gateway webhooks |
| `int_order_revenue` | One row per order, one revenue verdict each |
| `rpt_revenue_bridge` | The headline reconciliation |
| `rpt_revenue_bridge_by_currency` | The same bridge, arithmetically valid per currency |
| `rpt_revenue_by_month` | Shows monthly reporting is distorted while the year is correct |
| `rpt_payment_attempts` | Retry behaviour and uncollected demand |

**41 tests** cover uniqueness, completeness, referential integrity, permitted
values, and the arithmetic integrity of the bridge itself. One reports as a
warning by design — a real source-system defect that is tolerable and outside
our control to fix.

---

## Design decisions worth reading the code for

**The order of conditions in `int_order_revenue` is the revenue recognition
policy.** `case` evaluates top to bottom and stops at the first match, so
rearranging those five lines changes the reported revenue figure. That makes it
an accounting decision expressed in SQL, and it should be owned by Finance —
not by whoever last edited the model.

**A missing timestamp is not a missing event.** An early version treated orders
with no `shipped_at` as never shipped, writing off $213,433. But 640 of those
orders have a *delivery* date — the shipment happened, the carrier feed dropped
the record. The model now requires the absence of both before it writes
anything off.

**No currency conversion is applied.** Revenue spans USD, GBP and EUR with no
exchange-rate table in any source system. The choice of rate — transaction
date, month-end, or an internal hedged rate — materially changes the answer and
is the client's decision to make. `rpt_revenue_bridge_by_currency` reports each
currency separately rather than inventing a consolidated figure.

---

## Running it

Requires dbt 1.12 with the Snowflake adapter, and a Snowflake account with the
raw tables loaded by the
[fellowship's data generator](https://github.com/tripleaceme/analytics-engineering-fellowship).

Credentials are read from environment variables — nothing sensitive is written
to disk or committed:

```bash
export SNOWFLAKE_ACCOUNT="your-org-your-account"
export SNOWFLAKE_USER="your-user"
export SNOWFLAKE_PASSWORD="your-password"
export SNOWFLAKE_ROLE="ACCOUNTADMIN"
export SNOWFLAKE_WAREHOUSE="COMPUTE_WH"
export SNOWFLAKE_DATABASE="LUMEN_LOOM"
```

`~/.dbt/profiles.yml` reads those variables and writes to your own schema.

```bash
dbt debug              # confirm the connection
dbt run                # build all 10 models
dbt test               # run all 41 tests
dbt source freshness   # check the source feeds are current
dbt docs generate && dbt docs serve   # lineage graph and column documentation
```

---

## Note for other fellows

The data generator writes timestamps incorrectly on current library versions —
every date lands somewhere around the year 54 billion, and the load reports
success. The fix is one argument in `generate_data.py`:

```python
success, _, nrows, _ = write_pandas(
    conn, df, name, quote_identifiers=False, auto_create_table=False,
    use_logical_type=True
)
```

Without `use_logical_type=True`, timestamps are written to Parquet without unit
information and Snowflake misinterprets them. Row counts still match, every
model still builds, and every test still passes — which is its own lesson about
why counting rows is not verification.
