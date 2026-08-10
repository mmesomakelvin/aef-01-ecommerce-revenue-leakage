# Engagement 01 — Session-by-Session Teaching Guide

Build the entire revenue leakage pipeline from an empty folder, live, in four
sessions of roughly 90 minutes each, plus a setup session.

Every command and every query is written out in full. Nothing is assumed.

**How to use this:** each session has a *goal*, the *commands to type*, and —
most importantly — the **question to ask before revealing the answer**. The
questions are the teaching. The SQL is just how you answer them.

---

## Contents

- [Session 0 — Setup](#session-0--setup-60-min)
- [Session 1 — Raw data and the staging layer](#session-1--raw-data-and-the-staging-layer-90-min)
- [Session 2 — Finding the leaks](#session-2--finding-the-leaks-90-min)
- [Session 3 — Classification and the bridge](#session-3--classification-and-the-bridge-90-min)
- [Session 4 — Timing, testing and delivery](#session-4--timing-testing-and-delivery-90-min)
- [Known traps](#known-traps)

---

# Session 0 — Setup (60 min)

**Goal:** everyone reaches `dbt debug → All checks passed!`

Do this before the teaching starts, or students will spend session one
installing software instead of learning.

## 0.1 Install the tools

| Tool | Where | Check it worked |
|---|---|---|
| Python 3.11+ | python.org — **tick "Add Python to PATH"** | `python --version` |
| Git | git-scm.com | `git --version` |
| VS Code | code.visualstudio.com | it opens |

## 0.2 VS Code extensions

Search the Extensions panel (`Ctrl+Shift+X`) and install:

- **dbt Power User** (by Altimate) — SQL preview, lineage, autocomplete
- **Snowflake** (published by Snowflake) — query from inside VS Code
- **YAML** (by Red Hat) — catches indentation errors as you type
- **Python** (by Microsoft)
- **Better Jinja** — syntax highlighting for `{{ ref() }}`

> **Trap:** several extensions have near-identical names. Check the publisher
> and the install count. Do **not** install "Markdown Preview Mermaid Support" —
> it is deprecated and now built into VS Code.

## 0.3 Update pip, then install dbt

```powershell
python -m pip install --upgrade pip
pip install dbt-snowflake
```

**Why upgrade pip first:** one of dbt's dependencies ships as source code that
pip must compile. Old pip versions fail with `metadata-generation-failed`.

## 0.4 Fix the PATH

```powershell
dbt --version
```

If this says **"dbt is not recognized"**, the install worked but Windows can't
find the program. pip installed it to a folder that isn't on your PATH.

Permanent fix:

```powershell
[Environment]::SetEnvironmentVariable("Path",
  [Environment]::GetEnvironmentVariable("Path","User") +
  ";$env:APPDATA\Python\Python314\Scripts", "User")
```

Then **restart VS Code completely**. A new terminal tab is not enough — VS Code
copies the environment when the *application* starts.

Instant workaround for the current terminal only:

```powershell
$env:Path += ";$env:APPDATA\Python\Python314\Scripts"
```

> **Teaching point:** a program receives a *copy* of the environment at the
> moment it starts and never sees later changes. This single idea explains the
> PATH problem, the VS Code restart, and why the Snowflake password disappears
> when a terminal closes.

## 0.5 Snowflake account

Sign up at signup.snowflake.com. Choose **Standard**, **AWS**, and a region
close to you. **The region is permanent** — it becomes part of your account
identifier and cannot be changed later.

Your account identifier is in the browser URL:

```
app.snowflake.com/ngomgao/zp94304/
                  └─org──┘ └─acct─┘   →   ngomgao-zp94304
```

## 0.6 Create the database and schemas

New SQL worksheet, paste, select all, `Ctrl+Enter`:

```sql
CREATE DATABASE IF NOT EXISTS LUMEN_LOOM;
CREATE SCHEMA   IF NOT EXISTS LUMEN_LOOM.RAW;
CREATE SCHEMA   IF NOT EXISTS LUMEN_LOOM.DEV_YOURNAME;
```

Verify:

```sql
SHOW SCHEMAS IN DATABASE LUMEN_LOOM;
SHOW WAREHOUSES;
```

> **Explain the RAW/DEV split before moving on.** RAW holds source data and is
> never modified. DEV is your workshop and is entirely disposable. When a model
> is wrong you delete your schema and rebuild — RAW is never at risk. This is
> also why every student gets their own `DEV_` schema: twenty people can run
> identical code against identical data without ever colliding.

**For a class:** the instructor creates one account and one `DEV_` schema per
student. Individual student trials expire mid-cohort and produce a stream of
account-identifier confusion.

## 0.7 Load the data

```powershell
pip install -r "path\to\analytics-engineering-fellowship\case-studies\01-ecommerce-revenue-leakage\data_generator\requirements.txt"
```

**Fix the generator first** — see [Known traps](#known-traps). Open
`generate_data.py`, find `write_pandas(`, and add `use_logical_type=True`.

Rehearse without uploading:

```powershell
python "path\to\generate_data.py" --orders 50000 --seed 42 --dry-run
```

Expect: 50,000 / 51,656 / 4,876 / 42,811.

> **Stop here and ask:** "Why are there more payment rows than orders, and
> fewer shipping rows?" This one table is the whole case study in miniature.

Set credentials (these live only in this terminal session):

```powershell
$env:SNOWFLAKE_ACCOUNT="your-org-your-account"
$env:SNOWFLAKE_USER="YOUR_USER"
$env:SNOWFLAKE_ROLE="ACCOUNTADMIN"
$env:SNOWFLAKE_WAREHOUSE="COMPUTE_WH"
$env:SNOWFLAKE_DATABASE="LUMEN_LOOM"
$env:SNOWFLAKE_SCHEMA="RAW"
$env:SNOWFLAKE_PASSWORD="your-password"
```

If you are screen-sharing, hide the password instead:

```powershell
$s = Read-Host "Password" -AsSecureString
$env:SNOWFLAKE_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
$env:SNOWFLAKE_PASSWORD.Length   # prints a number, never the password
```

Load for real — same command, minus `--dry-run`:

```powershell
python "path\to\generate_data.py" --orders 50000 --seed 42
```

**Verify at the destination, not the source:**

```sql
SELECT 'ORDERS' AS tbl, COUNT(*) AS row_count FROM LUMEN_LOOM.RAW.RAW_ORDERS
UNION ALL SELECT 'PAYMENTS', COUNT(*) FROM LUMEN_LOOM.RAW.RAW_PAYMENTS
UNION ALL SELECT 'REFUNDS',  COUNT(*) FROM LUMEN_LOOM.RAW.RAW_REFUNDS
UNION ALL SELECT 'SHIPPING', COUNT(*) FROM LUMEN_LOOM.RAW.RAW_SHIPPING;
```

```sql
SELECT order_id, created_at, DATE_PART('year', created_at) AS yr
FROM LUMEN_LOOM.RAW.RAW_ORDERS LIMIT 5;
```

**Every year must read 2024.** If you see enormous or negative years, the
generator fix in [Known traps](#known-traps) was not applied.

## 0.8 Create the dbt project

```powershell
cd "C:\path\to\your\working\folder"
dbt init lumen_loom --skip-profile-setup
cd lumen_loom
Remove-Item -Recurse -Force "models\example"
New-Item -ItemType Directory -Force "models\staging","models\intermediate","models\marts"
```

**Why `--skip-profile-setup`:** without it, dbt interviews you and writes your
password into a file on disk. Credentials belong in environment variables.

## 0.9 Connection profile

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.dbt"
code "$env:USERPROFILE\.dbt\profiles.yml"
```

```yaml
lumen_loom:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      role: "{{ env_var('SNOWFLAKE_ROLE') }}"
      warehouse: "{{ env_var('SNOWFLAKE_WAREHOUSE') }}"
      database: "{{ env_var('SNOWFLAKE_DATABASE') }}"
      schema: DEV_YOURNAME
      threads: 4
```

> **Indentation is the syntax.** YAML has no brackets — spaces are the only
> thing telling the computer what belongs to what. `outputs:` at 2 spaces,
> `dev:` at 4, its settings at 6. Get this wrong and dbt reports
> `NoneType is not a container`, which sounds like a bug and is a typo.

## 0.10 Layer materialisations

```powershell
code "dbt_project.yml"
```

Replace the `models:` block at the bottom:

```yaml
models:
  lumen_loom:
    staging:
      +materialized: view
    intermediate:
      +materialized: view
    marts:
      +materialized: table
```

| Setting | Creates | Why here |
|---|---|---|
| `view` | A saved query, no stored data | Staging is thin; always current, cheap to rebuild |
| `table` | Real stored data | Marts are read repeatedly — pay once, read fast |

> `ephemeral` is the textbook choice for intermediate models — dbt pastes the
> SQL inline and builds nothing. **Use `view` for teaching**, because you
> cannot point at something that doesn't exist. Say this out loud; it's a real
> engineering trade-off, not a shortcut.

## 0.11 Prove the connection

```powershell
dbt debug
```

You want **`All checks passed!`**

> **Why this before anything else:** it separates connection problems from SQL
> problems. Skip it, and a failure later leaves you unsure whether your SQL is
> wrong or you simply never logged in.

---

# Session 1 — Raw data and the staging layer (90 min)

**Goal:** four staging models built, and students understand *why* staging is
forbidden from doing anything interesting.

## 1.1 Look before you write (15 min)

```sql
SELECT * FROM LUMEN_LOOM.RAW.RAW_ORDERS LIMIT 20;
DESCRIBE TABLE LUMEN_LOOM.RAW.RAW_ORDERS;
DESCRIBE TABLE LUMEN_LOOM.RAW.RAW_PAYMENTS;
```

> **Habit to drill:** never write SQL against a column you haven't looked at.

## 1.2 The question that frames everything (15 min)

```sql
SELECT order_status, COUNT(*) AS orders, SUM(order_amount) AS value
FROM LUMEN_LOOM.RAW.RAW_ORDERS
GROUP BY order_status
ORDER BY orders DESC;
```

| Status | Orders | Value |
|---|---|---|
| completed | 32,127 | $2,095,456 |
| confirmed | 9,399 | $605,712 |
| cancelled | 4,515 | $295,282 |
| placed | 3,959 | $262,041 |

### ❓ Ask before revealing

> **"Which of these four is revenue?"**

Let them argue. `completed` is obvious. `cancelled` is obvious. But `confirmed`
and `placed` together are **$867,753 — 27% of the book** — and a status column
alone cannot resolve them.

Then the killer follow-up:

> **"A cancelled order is only not-revenue if the money went back. Does this
> table tell you whether it did?"**

It doesn't. **You cannot answer the question from `RAW_ORDERS`.** That's why
you build a pipeline instead of writing one clever query.

## 1.3 Source definitions (10 min)

```powershell
code "models\staging\sources.yml"
```

```yaml
version: 2

sources:
  - name: raw
    database: LUMEN_LOOM
    schema: RAW
    description: "Raw operational feeds, as emitted by the source systems."
    tables:
      - name: raw_orders
        description: "One row per order. Status reflects current lifecycle state."
        config:
          loaded_at_field: updated_at
          freshness:
            warn_after: {count: 36, period: hour}
            error_after: {count: 48, period: hour}

      - name: raw_payments
        description: "One row per payment ATTEMPT (includes failures and retries)."
        config:
          loaded_at_field: attempted_at
          freshness:
            warn_after: {count: 36, period: hour}
            error_after: {count: 48, period: hour}

      - name: raw_refunds
        description: "One row per refund. Can be partial; often a later month than the order."
        config:
          loaded_at_field: processed_at
          freshness:
            warn_after: {count: 36, period: hour}
            error_after: {count: 48, period: hour}

      - name: raw_shipping
        description: "One row per shipment. Timestamps go missing on carrier API timeouts."
        config:
          loaded_at_field: shipped_at
          freshness:
            warn_after: {count: 72, period: hour}
            error_after: {count: 96, period: hour}
```

**What a `sources.yml` is:** dbt's address book for data it didn't create. Two
payoffs — change the location once instead of in fifty files, and dbt learns
the dependency graph so it builds things in the right order automatically.

**Why shipping gets a looser freshness window:** its timestamp column is
legitimately nullable. Thresholds come from how a table actually behaves, not
copied across.

## 1.4 First model (20 min)

```powershell
code "models\staging\stg_orders.sql"
```

```sql
with source as (

    select * from {{ source('raw', 'raw_orders') }}

),

renamed as (

    select
        order_id,
        customer_id,
        lower(order_status)  as order_status,
        order_amount,
        upper(currency)      as currency,
        created_at           as ordered_at,
        updated_at           as status_updated_at

    from source

)

select * from renamed
```

```powershell
dbt run
```

### Teaching beats

- **`{{ source(...) }}`** is replaced at run time with the real table name.
- **You wrote a `SELECT`. dbt wrote the `CREATE`.** That is the core of what
  the tool does.
- **`lower(order_status)`** — source systems are inconsistent; `Completed` and
  `completed` would silently split your totals.
- **`created_at as ordered_at`** — rename to say what it *means*.
- **What's absent: no filtering, no joins, no business rules.** Staging does
  not decide what counts as revenue.

## 1.5 The other three (25 min)

Same shape every time. Let students write `stg_refunds` and `stg_shipping`
themselves after you demonstrate `stg_payments`.

```sql
-- models/staging/stg_payments.sql
with source as (

    select * from {{ source('raw', 'raw_payments') }}

),

renamed as (

    select
        payment_id,
        order_id,
        lower(payment_status)  as payment_status,
        amount                 as payment_amount,
        upper(currency)        as currency,
        lower(payment_method)  as payment_method,
        gateway_fee,
        attempted_at,
        processed_at

    from source

)

select * from renamed
```

```sql
-- models/staging/stg_refunds.sql
with source as (

    select * from {{ source('raw', 'raw_refunds') }}

),

renamed as (

    select
        refund_id,
        order_id,
        payment_id,
        refund_amount,
        upper(currency)       as currency,
        lower(refund_reason)  as refund_reason,
        lower(refund_status)  as refund_status,
        requested_at,
        processed_at          as refunded_at

    from source

)

select * from renamed
```

```sql
-- models/staging/stg_shipping.sql
with source as (

    select * from {{ source('raw', 'raw_shipping') }}

),

renamed as (

    select
        shipment_id,
        order_id,
        lower(carrier)  as carrier,
        shipping_cost,
        lower(status)   as shipment_status,
        shipped_at,
        delivered_at

    from source

)

select * from renamed
```

> **The renames that matter:** `processed_at → refunded_at` and
> `status → shipment_status`. Four tables each have a `status` and two have a
> `processed_at`. **Rename at the door**, before the collision can happen.

```powershell
dbt run
```

## 1.6 Close the session

Point at the log. Models started at the same second and finished together —
that's `threads: 4`. dbt built independent models in parallel without being
told to.

**Homework:** *"Tomorrow we find out how much money is missing. Write down
your guess now."*

---

# Session 2 — Finding the leaks (90 min)

**Goal:** three findings, quantified, and the fan-out join understood.

## 2.1 Duplicates (20 min)

### ❓ Ask before running

> **"An order should have exactly one successful payment. Does it?"**

```sql
with success_counts as (

    select
        order_id,
        count(*)            as successful_payments,
        sum(payment_amount) as total_charged
    from LUMEN_LOOM.DEV_YOURNAME.STG_PAYMENTS
    where payment_status = 'succeeded'
    group by order_id

)

select
    count(*)                                                                      as orders_double_logged,
    sum(successful_payments - 1)                                                  as duplicate_rows,
    round(sum(total_charged * (successful_payments - 1) / successful_payments), 2) as overstated_revenue
from success_counts
where successful_payments > 1;
```

**Result: 642 orders, 642 duplicate rows, $41,396.82.**

> Exactly one extra per order. Too regular to be random — this is a systematic
> technical fault, which is what makes it findable and fixable.

## 2.2 Deduplicate (25 min)

```powershell
code "models\intermediate\int_payments_deduplicated.sql"
```

```sql
with successful_payments as (

    select * from {{ ref('stg_payments') }}
    where payment_status = 'succeeded'

),

ranked as (

    select
        *,
        row_number() over (
            partition by order_id
            order by processed_at, payment_id
        ) as payment_rank

    from successful_payments

)

select
    payment_id,
    order_id,
    payment_amount,
    currency,
    payment_method,
    gateway_fee,
    attempted_at,
    processed_at

from ranked
where payment_rank = 1
```

### Teaching beats

- **`ref()` vs `source()`** — `source()` points at data dbt didn't make;
  `ref()` points at data dbt did. `ref()` is simultaneously a reference *and* a
  dependency declaration.
- **`row_number() over (partition by ... order by ...)`** — read it as a
  sentence: *deal the rows into piles, one per order; sort each pile; number
  them.* Then keep number 1.
- **Why not `SELECT DISTINCT`** — this lets you choose *which* copy survives.
- **`payment_id` as tie-breaker** — without it, ties resolve randomly and the
  model returns different data on different runs.

```powershell
dbt run
```

**Prove it:**

```sql
SELECT
    (SELECT COUNT(*) FROM LUMEN_LOOM.DEV_YOURNAME.STG_PAYMENTS
     WHERE payment_status = 'succeeded')                                    AS before_dedup,
    (SELECT COUNT(*) FROM LUMEN_LOOM.DEV_YOURNAME.INT_PAYMENTS_DEDUPLICATED) AS after_dedup;
```

**45,172 → 44,530. Exactly 642.**

> Anyone can write SQL that removes rows. Showing it removed *precisely* the
> rows you identified, and no others, is what makes it trustworthy.

## 2.3 The uncomfortable question (20 min)

```sql
select
    o.order_status,
    count(*)                         as orders_charged,
    round(sum(p.payment_amount), 2)  as cash_collected
from LUMEN_LOOM.DEV_YOURNAME.STG_ORDERS o
join LUMEN_LOOM.DEV_YOURNAME.INT_PAYMENTS_DEDUPLICATED p
  on o.order_id = p.order_id
group by o.order_status
order by cash_collected desc;
```

### ❓ Ask before running

> **"How much money did we collect on orders we cancelled?"**

Most people say zero.

| Status | Orders charged | Cash | Share of that status |
|---|---|---|---|
| cancelled | 2,024 | $131,272 | **45% of all cancellations** |
| placed | 980 | $66,728 | **25% of all placed orders** |

> **45% and 25% are far too clean to be accidents.** A system is behaving
> consistently — this is a process defect, not data entry error.

**Then teach the fan-out join.** It is safe to join here *only because*
`int_payments_deduplicated` has one row per order. Join to `stg_payments`
instead and the 642 duplicates each pull their order row through twice.

> **A fan-out join never throws an error.** It is the most common way revenue
> gets overstated in real companies.

## 2.4 Where did it go? (25 min)

```sql
with charged as (

    select
        o.order_id,
        o.order_status,
        p.payment_amount
    from LUMEN_LOOM.DEV_YOURNAME.STG_ORDERS o
    join LUMEN_LOOM.DEV_YOURNAME.INT_PAYMENTS_DEDUPLICATED p
      on o.order_id = p.order_id

),

refunded as (

    select
        order_id,
        sum(refund_amount) as refund_amount
    from LUMEN_LOOM.DEV_YOURNAME.STG_REFUNDS
    where refund_status = 'completed'
    group by order_id

)

select
    c.order_status,
    count(*)                                                       as orders,
    round(sum(c.payment_amount), 2)                                as charged,
    round(sum(coalesce(r.refund_amount, 0)), 2)                    as refunded,
    round(sum(c.payment_amount - coalesce(r.refund_amount, 0)), 2) as still_held
from charged c
left join refunded r
  on c.order_id = r.order_id
group by c.order_status
order by still_held desc;
```

### Three things to teach from this query

1. **`refunded` aggregates *before* joining.** Collapse to one row per key,
   then join. Make it a reflex.
2. **`left join`, not `join`** — a plain join drops every order that was never
   refunded, which is exactly the population you're looking for.
3. **`coalesce(r.refund_amount, 0)`** — in SQL, blank is not zero; it is
   *unknown*, and unknown poisons every calculation it touches.
   `payment_amount - NULL` returns NULL.

| Status | Charged | Refunded | Still held |
|---|---|---|---|
| cancelled | $131,272 | $86,844 | **$44,428** (66% returned) |
| placed | $66,728 | $4,450 | **$62,278** (6.7% returned) |

> **The two rows tell different stories.** Cancelled: someone is trying, the
> process is leaky. Placed: nobody is trying — and 6.7% happens to match the
> ordinary returns rate, meaning **no cancellation refunds are occurring at
> all**. Those customers may not know they were charged.

---

# Session 3 — Classification and the bridge (90 min)

**Goal:** one verdict per order, and the bridge finance can argue with.

## 3.1 Check the grain, always (10 min)

```sql
select
    count(*)                  as shipping_rows,
    count(distinct order_id)  as distinct_orders
from LUMEN_LOOM.DEV_YOURNAME.STG_SHIPPING;
```

**42,811 = 42,811.** Safe to join.

> **Before joining any table, ask "one row per what?"** Getting the *grain*
> wrong is the number one cause of wrong numbers in analytics.

## 3.2 Did the goods go out? (20 min)

```sql
with charged as (

    select
        o.order_id,
        o.order_status,
        p.payment_amount
    from LUMEN_LOOM.DEV_YOURNAME.STG_ORDERS o
    join LUMEN_LOOM.DEV_YOURNAME.INT_PAYMENTS_DEDUPLICATED p
      on o.order_id = p.order_id

)

select
    c.order_status,
    count(*)                                                                       as paid_orders,
    count(s.order_id)                                                              as has_shipment_row,
    count(s.shipped_at)                                                            as has_ship_date,
    count(s.delivered_at)                                                          as has_delivery_date,
    round(sum(case when s.shipped_at is null then c.payment_amount else 0 end), 2) as cash_never_shipped
from charged c
left join LUMEN_LOOM.DEV_YOURNAME.STG_SHIPPING s
  on c.order_id = s.order_id
group by c.order_status
order by cash_never_shipped desc;
```

**`count(*)` counts rows; `count(column)` counts non-blank values.** Side by
side, they show exactly where the data thins out.

**`sum(case when ... then amount else 0 end)`** — a running total that only
picks up the rows you care about. The most useful pattern in analytics SQL.

### ❓ Ask before running

> **"How many `completed` orders should be missing a ship date?"**

Zero. You cannot complete an order you never sent.

**2,492 are missing one — $164,870.**

### The impossible finding

Look at every row: `has_delivery_date` is **larger** than `has_ship_date`.

**640 orders were delivered before they were shipped.**

> Give this a full minute of silence. Nothing in the real world produces it.
> And **no `count(*)` would ever have revealed it** — it only appears when you
> compare two columns that must have a logical relationship and find they
> don't.

## 3.3 One verdict per order (30 min)

```powershell
code "models\intermediate\int_order_revenue.sql"
```

```sql
with orders as (

    select * from {{ ref('stg_orders') }}

),

payments as (

    select * from {{ ref('int_payments_deduplicated') }}

),

refunds as (

    select
        order_id,
        sum(refund_amount) as refund_amount,
        min(refunded_at)   as first_refunded_at
    from {{ ref('stg_refunds') }}
    where refund_status = 'completed'
    group by order_id

),

shipping as (

    select * from {{ ref('stg_shipping') }}

),

joined as (

    select
        o.order_id,
        o.customer_id,
        o.order_status,
        o.currency,
        o.order_amount,
        o.ordered_at,

        p.payment_amount,
        p.gateway_fee,
        p.processed_at                as paid_at,

        coalesce(r.refund_amount, 0)  as refund_amount,
        r.first_refunded_at           as refunded_at,

        s.shipped_at,
        s.delivered_at

    from orders o
    left join payments p on o.order_id = p.order_id
    left join refunds  r on o.order_id = r.order_id
    left join shipping s on o.order_id = s.order_id

),

classified as (

    select
        *,
        case
            when payment_amount is null     then 'never_charged'
            when order_status = 'cancelled' then 'cancelled_but_charged'
            when order_status = 'placed'    then 'placed_but_charged'
            when shipped_at is null
             and delivered_at is null       then 'charged_not_shipped'
            else                                 'recognisable'
        end as revenue_category
    from joined

)

select
    *,
    case
        when revenue_category = 'recognisable'
        then payment_amount - refund_amount
        else 0
    end as recognised_revenue

from classified
```

### The two ideas in this model

**1. `orders` is the base and every join is a `left join`.** All 50,000 orders
survive. Nothing can go missing without you seeing it.

**2. The order of the `case` conditions is the business rule.** `case` checks
top to bottom and stops at the first match, so every order lands in exactly one
bucket — the most serious one that applies. **This is why you cannot add up the
individual findings**; they overlap, and the `case` resolves the overlap by
construction.

> **Rearranging those five lines changes the company's revenue number.** That
> makes it an accounting policy written in SQL, and it should be owned by
> Finance — not by whoever last edited the model.

```powershell
dbt run
```

```sql
select
    revenue_category,
    count(*)                                   as orders,
    round(sum(coalesce(payment_amount, 0)), 2) as cash_collected,
    round(sum(refund_amount), 2)               as refunded,
    round(sum(recognised_revenue), 2)          as recognised
from LUMEN_LOOM.DEV_YOURNAME.INT_ORDER_REVENUE
group by revenue_category
order by cash_collected desc;
```

### 🔴 The most important teaching moment in the engagement

Build the model **first without** the `and delivered_at is null` line. It gives
**20.7%** leakage. The brief predicts 8–12%.

> **"Your answer is nearly double what the client expects. What do you do?"**

Check your work before you present it. The suspect is `charged_not_shipped` —
$213,433 written off on orders with no ship date.

> **"Does 'no ship date' mean it never shipped?"**

No — 640 of them have a *delivery* date. **The model was treating missing data
as a business failure.**

Add the line. Leakage drops to **13.9%**, and the bucket empties entirely.

> **A rule that never fires is itself a finding.** It means the carrier feed
> doesn't lose shipments, it loses ship *timestamps*. Keep the rule anyway — it
> is a tripwire for when the feed degrades further.

**The transferable lesson:** *"the field is empty" and "the thing didn't
happen" are different claims.* For every null you act on, ask: **missing
event, or missing record of an event?** Then look for corroborating evidence
elsewhere.

## 3.4 The bridge (20 min)

```powershell
code "models\marts\rpt_revenue_bridge.sql"
```

```sql
with orders as (

    select * from {{ ref('int_order_revenue') }}

),

agg as (

    select
        sum(case when revenue_category = 'cancelled_but_charged' then payment_amount else 0 end) as cancelled_charged,
        sum(case when revenue_category = 'placed_but_charged'    then payment_amount else 0 end) as placed_charged,
        sum(case when revenue_category = 'charged_not_shipped'   then payment_amount else 0 end) as not_shipped,
        sum(case when revenue_category = 'recognisable'          then refund_amount  else 0 end) as refunds_on_good,
        sum(case when revenue_category = 'recognisable'
                 then coalesce(gateway_fee, 0) else 0 end)                                       as fees_recognised,
        sum(case when revenue_category <> 'recognisable'
                 then coalesce(gateway_fee, 0) else 0 end)                                       as fees_wasted,
        sum(recognised_revenue)                                                                  as recognised
    from orders

),

gateway as (

    select sum(payment_amount) as gateway_total
    from {{ ref('stg_payments') }}
    where payment_status = 'succeeded'

),

deduped as (

    select sum(payment_amount) as deduped_total
    from {{ ref('int_payments_deduplicated') }}

)

select 1 as step, 'Gateway total: all successful payments' as line_item,
       round(g.gateway_total, 2) as amount
from gateway g

union all
select 2, 'Less: duplicate payment webhooks',
       round(-(g.gateway_total - d.deduped_total), 2)
from gateway g cross join deduped d

union all
select 3, 'Less: cancelled orders that were charged', round(-a.cancelled_charged, 2) from agg a
union all
select 4, 'Less: placed orders that were charged',    round(-a.placed_charged, 2)    from agg a
union all
select 5, 'Less: charged, no shipping evidence',      round(-a.not_shipped, 2)       from agg a
union all
select 6, 'Less: refunds on recognised orders',       round(-a.refunds_on_good, 2)   from agg a
union all
select 7, 'Defensible revenue (mixed currency)',      round(a.recognised, 2)         from agg a

union all
select 8, 'Less: payment processing fees on recognised revenue',
       round(-a.fees_recognised, 2) from agg a
union all
select 9, 'Revenue net of payment processing costs',
       round(a.recognised - a.fees_recognised, 2) from agg a
union all
select 10, 'Memo: fees paid on revenue that was not recognised (sunk)',
       round(-a.fees_wasted, 2) from agg a

order by step
```

> **Why a bridge beats a corrected number.** A single figure on a slide invites
> one response: *"that's wrong."* A bridge invites *"explain line 3."* One is a
> conversation; the other is a fight. And the client can accept four of your
> six adjustments and still use the work.

**Step 10 is labelled "Memo"** because it sits outside the arithmetic. Mixing
it into the walk would break the reconciliation. Finance uses this convention
for exactly that reason.

> **Step 10 is a different kind of number.** The $407,940 overstatement is an
> *accounting* correction — money never really earned. The $6,643 of sunk fees
> is an *actual cash loss*. Separate those ideas explicitly.

## 3.5 The problem that invalidates the total (10 min)

```sql
select
    currency,
    count(*)                          as orders,
    round(sum(recognised_revenue), 2) as recognised
from LUMEN_LOOM.DEV_YOURNAME.INT_ORDER_REVENUE
where recognised_revenue > 0
group by currency
order by recognised desc;
```

**USD $1,823,001 · GBP $357,981 · EUR $351,643 — 28% non-USD.**

> **"$2,532,625.67 of what?"** You have been adding three currencies as though
> they were the same thing. And **there is no exchange-rate table anywhere in
> this data.** You cannot fix it with better SQL.

The correct deliverable is not a converted number. It's: *"here is revenue by
currency, and we cannot consolidate until you give us a rate table and tell us
which date's rate applies."*

> **Knowing when to stop and ask is a skill, not a failure.** A junior analyst
> converts at today's Google rate and delivers a confident number. A senior one
> recognises the choice of rate is a finance policy decision worth tens of
> thousands and refuses to make it silently. **The deliverable is the question.**

Then build the valid version:

```sql
-- models/marts/rpt_revenue_bridge_by_currency.sql
with orders as (

    select * from {{ ref('int_order_revenue') }}

),

gateway as (

    select currency, sum(payment_amount) as gateway_total
    from {{ ref('stg_payments') }}
    where payment_status = 'succeeded'
    group by currency

),

deduped as (

    select currency, sum(payment_amount) as deduped_total
    from {{ ref('int_payments_deduplicated') }}
    group by currency

),

agg as (

    select
        currency,
        sum(case when revenue_category = 'cancelled_but_charged' then payment_amount else 0 end) as cancelled_charged,
        sum(case when revenue_category = 'placed_but_charged'    then payment_amount else 0 end) as placed_charged,
        sum(case when revenue_category = 'charged_not_shipped'   then payment_amount else 0 end) as not_shipped,
        sum(case when revenue_category = 'recognisable'          then refund_amount  else 0 end) as refunds_on_good,
        sum(recognised_revenue)                                                                  as recognised
    from orders
    group by currency

)

select
    g.currency,
    round(g.gateway_total, 2)                       as gateway_total,
    round(-(g.gateway_total - d.deduped_total), 2)  as duplicate_webhooks,
    round(-a.cancelled_charged, 2)                  as cancelled_but_charged,
    round(-a.placed_charged, 2)                     as placed_but_charged,
    round(-a.not_shipped, 2)                        as no_shipping_evidence,
    round(-a.refunds_on_good, 2)                    as refunds,
    round(a.recognised, 2)                          as defensible_revenue,
    round(g.gateway_total - a.recognised, 2)        as overstatement

from gateway g
join deduped d on g.currency = d.currency
join agg     a on g.currency = a.currency
order by defensible_revenue desc
```

**Result: 14.0% USD, 13.7% GBP, 13.5% EUR.**

> **Uniform rates rule something out.** If the cause were local process
> variation, the rates would diverge. They don't — so this is one shared
> platform defect, and one fix addresses all three markets. **A finding can be
> valuable for what it eliminates.**

---

# Session 4 — Timing, testing and delivery (90 min)

**Goal:** the timing finding, a test that fails on purpose, and a deliverable.

## 4.1 The finding nobody has ever caught (25 min)

### ❓ Ask before building

> **"A customer buys in January and is refunded in March. Which month loses
> the money?"**

March. So January is overstated and March is understated — **and the year is
perfect.**

```powershell
code "models\marts\rpt_revenue_by_month.sql"
```

```sql
with recognised as (

    select * from {{ ref('int_order_revenue') }}
    where revenue_category = 'recognisable'

),

refunds as (

    select
        order_id,
        refund_amount,
        refunded_at
    from {{ ref('stg_refunds') }}
    where refund_status = 'completed'

),

sales as (

    select
        date_trunc('month', paid_at) as month,
        sum(payment_amount)          as gross_revenue
    from recognised
    group by 1

),

refunds_as_booked as (

    select
        date_trunc('month', f.refunded_at) as month,
        sum(f.refund_amount)               as refunds
    from refunds f
    join recognised o on o.order_id = f.order_id
    group by 1

),

refunds_matched as (

    select
        date_trunc('month', o.paid_at) as month,
        sum(f.refund_amount)           as refunds
    from refunds f
    join recognised o on o.order_id = f.order_id
    group by 1

),

months as (

    select month from sales
    union
    select month from refunds_as_booked

)

select
    mo.month,
    round(coalesce(s.gross_revenue, 0), 2)                          as gross_revenue,
    round(coalesce(b.refunds, 0), 2)                                as refunds_as_booked,
    round(coalesce(m.refunds, 0), 2)                                as refunds_matched_to_sale,
    round(coalesce(s.gross_revenue, 0) - coalesce(b.refunds, 0), 2) as net_as_reported,
    round(coalesce(s.gross_revenue, 0) - coalesce(m.refunds, 0), 2) as net_matched,
    round(coalesce(b.refunds, 0) - coalesce(m.refunds, 0), 2)       as distortion
from months mo
left join sales             s on mo.month = s.month
left join refunds_as_booked b on mo.month = b.month
left join refunds_matched   m on mo.month = m.month
order by mo.month
```

**The two refund CTEs are identical except for one column. That's the lesson.**
One groups by when the refund happened (what's reported today); the other by
when the sale happened (what should be reported).

**`months` uses `union`, not a plain join** — refunds processed in early 2025
have no matching sales month and a plain join would silently drop them.

### The three things to show

| Month | Net as reported | Net matched | Distortion |
|---|---|---|---|
| Jan 2024 | 219,019 | 211,857 | **(7,163)** |
| Jan 2025 | **(4,825)** | 0 | 4,825 |
| Feb 2025 | **(1,411)** | 0 | 1,411 |

1. **Negative revenue in two months where nothing was sold.** $6,236 of 2024
   refunds landing after 2024 closed.
2. **January is structurally overstated by $7,163** — the first period of any
   window exports its refunds and imports none. Same thing happens on a new
   product line or a new market.
3. **Sum the distortion column: exactly zero.** Every month is wrong. The year
   is right. **That is why nobody caught it** — the annual figure reconciles to
   the bank perfectly.

> **This finding is arguably worth more than the $407,940.** Marketing ROI,
> commissions, forecast accuracy, month-on-month growth — all built on numbers
> that are individually wrong and collectively fine.

## 4.2 Tests (25 min)

```powershell
code "models\staging\schema.yml"
```

```yaml
version: 2

models:
  - name: stg_orders
    description: "One row per order, cleaned and renamed."
    columns:
      - name: order_id
        data_tests:
          - unique
          - not_null
      - name: order_status
        data_tests:
          - accepted_values:
              arguments:
                values: ['completed', 'confirmed', 'cancelled', 'placed']
      - name: order_amount
        data_tests:
          - not_null

  - name: stg_payments
    description: "One row per payment ATTEMPT. Contains duplicates by design."
    columns:
      - name: payment_id
        data_tests:
          - unique
          - not_null
      - name: order_id
        data_tests:
          - not_null
          - relationships:
              arguments:
                to: ref('stg_orders')
                field: order_id
```

```powershell
dbt test
```

| Test | Asks |
|---|---|
| `unique` | Is this really one row per thing? The grain question, automated |
| `not_null` | Is this ever missing? |
| `accepted_values` | Has a new value appeared my `case` doesn't handle? |
| `relationships` | Does every payment point at an order that exists? |

> **`accepted_values` is the quiet hero.** Your revenue rule is a `case` listing
> four statuses. If the business adds a fifth — `returned`, say — your `else`
> books it as revenue. Nothing errors. The number just goes wrong.

> **Note where the tests live.** `payment_id` is unique on `stg_payments`;
> `order_id` is not — and testing that it were would fail, correctly.
> **Test the grain you have, not the grain you wish for.**

### The singular test

```powershell
code "tests\assert_bridge_balances.sql"
```

```sql
with bridge as (

    select * from {{ ref('rpt_revenue_bridge') }}

),

totals as (

    select
        sum(case when step < 7 then amount else 0 end) as sum_of_steps,
        max(case when step = 7 then amount end)        as stated_total
    from bridge

)

select *
from totals
where abs(sum_of_steps - stated_total) > 0.01
```

> **A dbt test is a query that should return nothing.** Rows returned =
> failures found. You don't describe what's correct — you describe what's
> *wrong* and assert that nothing matches.

**`abs(...) > 0.01`** — a cent of tolerance. Demanding exact equality gives you
a test that fails randomly, which is worse than no test, because people learn
to ignore it.

> **This one test is worth more than the other seventeen combined.** They check
> that columns look sane. This checks that your headline number is internally
> consistent.

## 4.3 A test that fails on purpose (20 min)

```powershell
code "tests\assert_order_timestamps_sane.sql"
```

```sql
select
    order_id,
    order_status,
    ordered_at,
    status_updated_at,
    datediff('hour', ordered_at, status_updated_at) as hours_difference

from {{ ref('stg_orders') }}
where status_updated_at < ordered_at
```

```powershell
dbt test --select assert_order_timestamps_sane
```

**`FAIL 100`** — 1 in every 500 orders. An order updated before it was created.

### ❓ Now the real question

> **"This will fail on every run, forever, and we cannot fix it. What do you
> do with it?"**

Add one line at the top:

```sql
{{ config(severity = 'warn') }}
```

| Severity | Behaviour | Use when |
|---|---|---|
| `error` (default) | Run fails, pipeline stops | Data is unusable downstream |
| `warn` | Reports, run continues | Defect is real but tolerable |

> **A permanently failing test is worse than no test**, because it trains the
> team to ignore red lights — including the ones that matter. But don't delete
> it either: 1 in 500 is tolerable, 1 in 5 is not, and the warning is your
> thermometer.

> ⚠️ **Say this explicitly:** downgrading to `warn` is a decision to be made
> deliberately and recorded. The failure mode in real teams is downgrading
> tests to make the build green.

## 4.4 Freshness, docs, delivery (20 min)

```powershell
dbt source freshness
```

All four sources report **`ERROR STALE`** — the data is from 2024.

> **This is the failure mode freshness exists to catch, and it's the nastiest
> one in production.** When a feed dies, *nothing breaks*. Every model builds.
> Every test passes. The dashboards render. They just quietly show last
> Tuesday's numbers until someone notices. **Freshness is the only check that
> catches a pipeline succeeding perfectly at doing nothing.**

```powershell
dbt docs generate
dbt docs serve
```

Click the blue circle bottom-right for the lineage graph.

> **Nobody drew that diagram.** dbt inferred it entirely from your `ref()` and
> `source()` calls, so it cannot go out of date — it *is* the code. Show
> students any company's hand-drawn architecture diagram and ask when it was
> last accurate.

Trace a number backwards live: bridge → int_order_revenue → stg_payments →
raw_payments. **Four clicks from a board-level figure to a raw column.**

### The deliverable

Write `FINDINGS.md`. Every finding gets a **number**, a **recommendation**, and
an **owner**.

> **A finding without an action is a complaint.**

### Version control

```powershell
git init -b main
```

`.gitignore`:

```
target/
dbt_packages/
logs/
.user.yml

# never commit credentials
.env
*.env
profiles.yml
```

```powershell
git add .
git status          # READ THIS before committing
git commit -m "Engagement 01: revenue leakage pipeline, tests and findings"
```

> **Git remembers everything.** Commit a password once, delete it next commit,
> and it's still in the history for anyone who clones. Bots scan public GitHub
> for exactly this and find live credentials within minutes. `.gitignore` is
> the only cheap moment to get this right.

---

# Known traps

Things that will cost you class time if you don't know them in advance.

### The generator writes broken timestamps

**Every date lands around the year 54 billion and the load reports success.**
Row counts match. Models build. Tests pass.

Fix in `generate_data.py`:

```python
success, _, nrows, _ = write_pandas(
    conn, df, name, quote_identifiers=False, auto_create_table=False,
    use_logical_type=True
)
```

Without `use_logical_type=True`, timestamps are written to Parquet with no unit
information and Snowflake misinterprets them.

> **This is the best accidental lesson in the whole engagement.** Five green
> lights and the data was garbage. The only thing that caught it was a human
> looking at ten rows. **Row counts tell you how much arrived, never whether
> it's right.**

### `dbt is not recognized`

The install worked; Windows can't find the program. See §0.4. **A new terminal
tab is not enough** — VS Code caches the environment at application start.

### `NoneType is not a container`

YAML indentation in `profiles.yml`. `outputs:` at 2 spaces, `dev:` at 4, its
settings at 6. See §0.9.

### `ROWS` is a reserved word

`COUNT(*) AS rows` fails in Snowflake. Rename to `row_count` rather than
quoting `"ROWS"` — quoting also locks the capitalisation and causes join
failures later.

### Snowflake Copilot rewrites your worksheet

It will offer to create dbt-managed objects by hand. **Disable it before class.**
If dbt builds it, you never touch it by hand — worksheets are for *looking*,
not *building*.

### Environment variables die with the terminal

Every new session needs them re-set. That's the correct trade-off for keeping
passwords off disk. Tell students on day one so it isn't mistaken for a bug.

### The Pydantic warning

```
UserWarning: Core Pydantic V1 functionality isn't compatible with Python 3.14
```

Cosmetic. Silence with `$env:PYTHONWARNINGS = "ignore"`.

> **Teach the difference between a warning and an error.** A warning means
> "this ran fine, but heads up." An error means "this did not run." The tell is
> what comes *after*.

---

# Session timing at a glance

| Session | Content | Builds |
|---|---|---|
| 0 | Setup, Snowflake, data load | — |
| 1 | Raw data, staging layer | 4 models |
| 2 | Duplicates, dedup, cancelled/placed charges | +1 model |
| 3 | Grain, shipping, classification, bridge, currency | +3 models |
| 4 | Monthly timing, tests, freshness, docs, git | +1 model, 41 tests |

**Total: 10 models, 41 tests, 8 findings, one client memo.**
