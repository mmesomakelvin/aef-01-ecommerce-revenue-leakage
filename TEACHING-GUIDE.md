# Engagement 01 — Complete Session-by-Session Build Guide

Build the entire revenue leakage pipeline from an empty folder, live, in four
sessions of roughly 90 minutes, plus a setup session.

**Nothing is assumed.** Every terminal command, every SQL query, every file
path and every expected result is written out.

---

## How to read this guide

Every step follows the same shape:

> **WHERE** — Terminal, Snowflake worksheet, or a file in VS Code
> **FILE** — the exact path, when a file is involved
> **TYPE** — exactly what to enter
> **EXPECT** — what you should see
> **WHY** — what it's for, in plain English

The **❓ ASK** blocks are the teaching. They are questions to put to the class
*before* revealing the answer. The SQL is just how you answer them.

Two conventions throughout:

- Replace `DEV_YOURNAME` with your own schema name everywhere it appears.
- Terminal commands are PowerShell on Windows. On Mac/Linux, `$env:X="y"`
  becomes `export X="y"` and `\` in paths becomes `/`.

---

## Contents

| | Session | Builds |
|---|---|---|
| [0](#session-0--setup) | Setup: install → Snowflake → data loaded | — |
| [1](#session-1--raw-data-and-the-staging-layer) | Raw data and the staging layer | 4 models |
| [2](#session-2--finding-the-leaks) | Finding the leaks | +1 model |
| [3](#session-3--classification-and-the-bridge) | Classification and the bridge | +3 models |
| [4](#session-4--timing-testing-and-delivery) | Timing, testing and delivery | +2 models, 41 tests |
| [—](#appendix-a--complete-file-map) | Appendix A: complete file map | |
| [—](#appendix-b--every-command-in-order) | Appendix B: every command in order | |
| [—](#appendix-c--known-traps) | Appendix C: known traps | |

---

# Session 0 — Setup

**Goal:** every student reaches `dbt debug → All checks passed!` with data
loaded in Snowflake.

Do this before the teaching starts. Otherwise session one is spent installing
software.

---

### 0.1 — Install the three tools

> **WHERE** Web browser, then Terminal
> **WHY** Python runs dbt. Git tracks your work. VS Code is where you write.

| Tool | Get it from | Note |
|---|---|---|
| Python 3.11+ | python.org | **Tick "Add Python to PATH"** on the first screen |
| Git | git-scm.com | Accept all defaults |
| VS Code | code.visualstudio.com | Tick "Add to PATH" so `code` works in the terminal |

Verify each one:

> **TYPE**
> ```powershell
> python --version
> git --version
> ```
> **EXPECT** `Python 3.14.0` and `git version 2.x.x`

**Diagnostic to teach right now:** if you mistype a flag, e.g. `python --verson`,
you get a *usage message*. That means the program **is installed** and simply
didn't understand you. `'python' is not recognized` means something completely
different — the program can't be found at all.

---

### 0.2 — VS Code extensions

> **WHERE** VS Code → Extensions panel (`Ctrl+Shift+X`)

| Search for | Install the one published by | What it gives you |
|---|---|---|
| `dbt Power User` | **Altimate** | SQL preview, lineage, autocomplete for `ref()` |
| `Snowflake` | **Snowflake** | Run queries without leaving VS Code |
| `YAML` | **Red Hat** | Catches indentation errors as you type |
| `Python` | **Microsoft** | Python support |
| `Better Jinja` | Samuel Colvin | Highlights `{{ ref() }}` correctly |

> ⚠️ **Check the publisher, not just the name.** There are near-identical
> extensions called "dbt Databricks Power User" and "dbt BigQuery Power User".
> The one you want has ~488K installs and a verified Altimate badge.

> ⚠️ **Do NOT install "Markdown Preview Mermaid Support."** It is deprecated —
> Mermaid rendering is built into VS Code 1.121+.

---

### 0.3 — Upgrade pip, then install dbt

> **WHERE** Terminal
> **TYPE**
> ```powershell
> python -m pip install --upgrade pip
> ```
> **EXPECT** `Successfully installed pip-26.x`
> **WHY** One of dbt's dependencies (`dbt-core-experimental-parser`) ships as
> source code that pip must compile on the spot. Old pip versions fail with
> `metadata-generation-failed`. Upgrading first avoids a confusing error.

> **TYPE**
> ```powershell
> pip install dbt-snowflake
> ```
> **EXPECT** ~53 packages installed, ending `Successfully installed ...`
> **WHY** `dbt-snowflake` pulls in `dbt-core` (the engine) plus the Snowflake
> adapter (the translator). One command gets both.

> **TYPE**
> ```powershell
> dbt --version
> ```
> **EXPECT**
> ```
> Core:
>   - installed: 1.12.0
> Plugins:
>   - snowflake: 1.12.0
> ```

If instead you see **`The term 'dbt' is not recognized`**, go to 0.4.

---

### 0.4 — Fix the PATH (only if `dbt` is not recognized)

**What happened:** the install succeeded. pip put `dbt.exe` in a folder Windows
doesn't search. You'll have seen `Defaulting to user installation because
normal site-packages is not writeable` during the install — that line is the
clue.

**What PATH is:** a list of folders Windows searches when you type a command
name. If the program isn't in one of those folders, Windows reports it as
missing even though it's sitting on the disk.

> **WHERE** Terminal
> **TYPE** (permanent fix — one line, wrapped for readability)
> ```powershell
> [Environment]::SetEnvironmentVariable("Path",
>   [Environment]::GetEnvironmentVariable("Path","User") +
>   ";$env:APPDATA\Python\Python314\Scripts", "User")
> ```
> **EXPECT** No output. Silence means success.

> ⚠️ **Now close VS Code completely and reopen it.** A new terminal *tab* is
> not enough.

> **TYPE** (instant workaround for the current terminal only)
> ```powershell
> $env:Path += ";$env:APPDATA\Python\Python314\Scripts"
> ```

> 🎓 **The single idea worth teaching here:** *a program receives a copy of the
> environment at the moment it starts, and never sees later changes.* VS Code
> copied the PATH when it launched, so it can't see your edit — every terminal
> it opens inherits the stale copy. This same fact explains why the Snowflake
> password vanishes when a terminal closes (0.10).

---

### 0.5 — Create a Snowflake account

> **WHERE** signup.snowflake.com

| Field | Choose | Why |
|---|---|---|
| Edition | **Standard** | Trial credit is the same; Standard has everything dbt needs |
| Cloud provider | **AWS** | Default, most regions, most documentation assumes it |
| Region | **Nearest to you** | ⚠️ **Permanent — cannot be changed after signup** |

Activate via the email link, then set a password.

**Find your account identifier — you need it in 0.10.** It's in the browser URL:

```
app.snowflake.com/ngomgao/zp94304/#/homepage
                  └─org──┘ └─acct─┘
```

**Your identifier is `org-account`**, e.g. `ngomgao-zp94304`. Write it down.

---

### 0.6 — Create the database and schemas

> **WHERE** Snowflake → left sidebar → **Projects** → **Workspaces** → **+** → **SQL file**
> **TYPE**
> ```sql
> CREATE DATABASE IF NOT EXISTS LUMEN_LOOM;
> CREATE SCHEMA   IF NOT EXISTS LUMEN_LOOM.RAW;
> CREATE SCHEMA   IF NOT EXISTS LUMEN_LOOM.DEV_YOURNAME;
> ```
> Select all three lines, press **Ctrl+Enter**.
> **EXPECT** `Schema DEV_YOURNAME successfully created.`

> ⚠️ Snowflake runs only what is **selected**. With nothing selected it runs
> just the line the cursor is on.

**Verify:**

> **TYPE**
> ```sql
> SHOW SCHEMAS IN DATABASE LUMEN_LOOM;
> SHOW WAREHOUSES;
> ```
> **EXPECT** `RAW`, `DEV_YOURNAME`, plus Snowflake's own `PUBLIC` and
> `INFORMATION_SCHEMA`. And a warehouse, normally `COMPUTE_WH`, marked
> `SUSPENDED` with `auto_resume = true`.

**`SUSPENDED` is correct, not a problem.** A warehouse is the compute engine.
You pay only while it runs; it sleeps after 5 minutes idle and wakes itself the
instant a query arrives.

> 🎓 **Explain the RAW/DEV split before moving on.**
> - **Database** = a drive. **Schema** = a folder. **Table** = a file.
> - `RAW` holds source data and is **never modified**. It's evidence.
> - `DEV_YOURNAME` is your workshop and is **entirely disposable**.
>
> The rule: **raw data is read-only; everything else is rebuildable.** When a
> model is wrong you drop your schema and rebuild — RAW is never at risk. It's
> also why every student gets their own `DEV_` schema: twenty people can run
> identical code against identical data and never collide.

**For a class:** the instructor creates one account and one `DEV_` schema per
student. Individual student trials expire mid-cohort and generate a constant
stream of account-identifier confusion.

```sql
CREATE SCHEMA IF NOT EXISTS LUMEN_LOOM.DEV_AMARA;
CREATE SCHEMA IF NOT EXISTS LUMEN_LOOM.DEV_CHIDI;
-- one line per student
```

---

### 0.7 — Fix the data generator (do this first)

> **WHERE** VS Code
> **FILE** `analytics-engineering-fellowship/case-studies/01-ecommerce-revenue-leakage/data_generator/generate_data.py`
> **TYPE** (terminal, to open it)
> ```powershell
> code "C:\path\to\analytics-engineering-fellowship\case-studies\01-ecommerce-revenue-leakage\data_generator\generate_data.py"
> ```

Press **Ctrl+F**, search for `auto_create_table`. There is exactly one match.

**Find:**
```python
        success, _, nrows, _ = write_pandas(
            conn, df, name, quote_identifiers=False, auto_create_table=False
        )
```

**Change to:**
```python
        success, _, nrows, _ = write_pandas(
            conn, df, name, quote_identifiers=False, auto_create_table=False,
            use_logical_type=True
        )
```

Save with **Ctrl+S**.

> **WHY** `write_pandas` has a parameter `use_logical_type` that defaults to
> `False`. With it off, timestamps are written to Parquet as bare integers with
> no unit attached, and Snowflake guesses wrong — **every date lands around the
> year 54 billion.** Snowflake's own documentation says this flag is required
> for timestamps to store correctly.

> ⚠️ **Note the comma** you added after `auto_create_table=False`. Arguments are
> a comma-separated list; without it Python refuses to run the file.

---

### 0.8 — Install the generator's packages

> **WHERE** Terminal (any folder — the path is absolute)
> **TYPE**
> ```powershell
> pip install -r "C:\path\to\analytics-engineering-fellowship\case-studies\01-ecommerce-revenue-leakage\data_generator\requirements.txt"
> ```
> **EXPECT** Three packages resolved: `pandas`, `numpy`,
> `snowflake-connector-python[pandas]`. Two are probably already satisfied from
> the dbt install.

> **WHY `-r`** means "read the package list from this file" instead of typing
> names. A `requirements.txt` is a project saying *here is everything I need to
> run* — one command, identical environment, no "works on my machine".

| Package | Job |
|---|---|
| `pandas` | Holds the fake data as tables in memory |
| `numpy` | Generates the random numbers |
| `snowflake-connector-python` | Pushes the finished tables to Snowflake |

---

### 0.9 — Rehearse without uploading

> **WHERE** Terminal
> **TYPE**
> ```powershell
> python "C:\path\to\...\data_generator\generate_data.py" --orders 50000 --seed 42 --dry-run
> ```
> **EXPECT**
> ```
> Row counts:
>   RAW_ORDERS         50,000
>   RAW_PAYMENTS       51,656
>   RAW_REFUNDS         4,876
>   RAW_SHIPPING       42,811
>
> --dry-run set: skipping Snowflake load.
> ```

**Breaking down the command:**

| Part | Meaning |
|---|---|
| `python` | Start Python; everything after is what you're handing it |
| `"C:\...\generate_data.py"` | The file to run. Quoted because the path has spaces |
| `--orders 50000` | How much data to invent — about a year for a mid-size retailer |
| `--seed 42` | **Locks the randomness.** Same seed → byte-identical data on every machine |
| `--dry-run` | Build it, print a summary, **stop before uploading** |

> 🎓 **`--seed` is the concept students find least intuitive and most useful.**
> Ask: *how do you write a test for code that produces random output?* You
> can't assert an answer that changes every run. Seeding is the industry-wide
> answer — ML experiments, simulations, load testing, this generator.
> **Reproducible randomness** sounds like a contradiction and is a foundational
> tool. It's also what makes this exercise gradeable: a different answer means
> a different *method*, not different data.

### ❓ ASK — before moving on

> **"Why are there more payment rows than orders, and fewer shipping rows?"**

| Table | Rows | Why not 50,000? |
|---|---|---|
| `RAW_ORDERS` | 50,000 | The baseline |
| `RAW_PAYMENTS` | **51,656** | *More* — retries, failed attempts, duplicate webhooks |
| `RAW_SHIPPING` | **42,811** | *Fewer* — cancelled orders never ship |
| `RAW_REFUNDS` | 4,876 | ~10% came back |

**Payments exceed orders by 1,656.** A student who joins orders to payments and
sums has already overstated revenue before doing anything else. **This one
table is the whole case study in miniature.**

---

### 0.10 — Set your credentials

> **WHERE** Terminal
> **TYPE**
> ```powershell
> $env:SNOWFLAKE_ACCOUNT="your-org-your-account"
> $env:SNOWFLAKE_USER="YOUR_USERNAME"
> $env:SNOWFLAKE_ROLE="ACCOUNTADMIN"
> $env:SNOWFLAKE_WAREHOUSE="COMPUTE_WH"
> $env:SNOWFLAKE_DATABASE="LUMEN_LOOM"
> $env:SNOWFLAKE_SCHEMA="RAW"
> ```
> **EXPECT** No output. Setting a variable is silent.

> ⚠️ **No spaces inside a variable name.** `SNOWFLAKE_ USER` produces
> `Unexpected token 'USER'`. Spaces around `=` are fine; spaces inside the name
> are not.

**Then the password.** If you are screen-sharing, use the hidden version:

> **TYPE**
> ```powershell
> $s = Read-Host "Password" -AsSecureString
> $env:SNOWFLAKE_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
> ```
> It prompts `Password:` — type it, press Enter. **Nothing appears. That's the
> point.**

Otherwise, plainly:

> ```powershell
> $env:SNOWFLAKE_PASSWORD="your-password"
> ```

**Verify without exposing anything:**

> **TYPE**
> ```powershell
> $env:SNOWFLAKE_ACCOUNT; $env:SNOWFLAKE_USER; $env:SNOWFLAKE_PASSWORD.Length
> ```
> **EXPECT** Your account, your username, and **a number** — the password's
> length. Never the password itself. A number means it stored.

**Where each value came from:**

| Variable | Source |
|---|---|
| `ACCOUNT` | The Snowflake URL (0.5) |
| `USER` | Bottom-left of Snowflake |
| `ROLE` | Bottom-left, under your name |
| `WAREHOUSE` | `SHOW WAREHOUSES` (0.6) |
| `DATABASE` / `SCHEMA` | You created them (0.6) |

> 🎓 **These live only in this terminal.** Close it and they're gone. That's
> the correct trade-off for keeping passwords off disk — the number one way
> real credentials leak is a config file committed to GitHub. Tell students on
> day one so it isn't mistaken for a bug.

> ⚠️ **PowerShell 5.1 note:** `ConvertFrom-SecureString -AsPlainText` does not
> exist in Windows PowerShell 5.1 (only PowerShell 7). Use the two-line
> `[Runtime.InteropServices.Marshal]` version above.

---

### 0.11 — Load the data for real

> **WHERE** Terminal
> **TYPE** — the same command as 0.9, **minus `--dry-run`**
> ```powershell
> python "C:\path\to\...\data_generator\generate_data.py" --orders 50000 --seed 42
> ```
> **EXPECT**
> ```
> Loading to Snowflake ...
>   → RAW_ORDERS: 50,000 rows
>   → RAW_PAYMENTS: 51,656 rows
>   → RAW_REFUNDS: 4,876 rows
>   → RAW_SHIPPING: 42,811 rows
>
> Done. Raw tables are live in your sandbox. Happy modeling.
> ```

Row counts must be **identical** to the dry run. Same seed, same data.

> **Safe to re-run** any time. The script uses `CREATE OR REPLACE TABLE` — the
> old version is thrown away and rebuilt. No duplicates, nothing to clean up
> first.

---

### 0.12 — Verify at the destination

> **WHERE** Snowflake worksheet
> **TYPE**
> ```sql
> SELECT 'ORDERS' AS tbl, COUNT(*) AS row_count FROM LUMEN_LOOM.RAW.RAW_ORDERS
> UNION ALL SELECT 'PAYMENTS', COUNT(*) FROM LUMEN_LOOM.RAW.RAW_PAYMENTS
> UNION ALL SELECT 'REFUNDS',  COUNT(*) FROM LUMEN_LOOM.RAW.RAW_REFUNDS
> UNION ALL SELECT 'SHIPPING', COUNT(*) FROM LUMEN_LOOM.RAW.RAW_SHIPPING;
> ```
> **EXPECT** 50,000 / 51,656 / 4,876 / 42,811

> **WHY bother, when the script already said success?** Because the script
> reports what it **sent**. This asks Snowflake what it **received**. Two
> different claims. Get students into this habit early: *"the pipeline said
> success" is not the same as "the data is there."*

> ⚠️ **`ROWS` is a reserved word in Snowflake.** `COUNT(*) AS rows` fails.
> Rename to `row_count` rather than quoting `"ROWS"` — quoting also locks the
> capitalisation and causes join failures later.

---

### 0.13 — Verify the timestamps

> **WHERE** Snowflake worksheet
> **TYPE**
> ```sql
> SELECT order_id, created_at, DATE_PART('year', created_at) AS yr
> FROM LUMEN_LOOM.RAW.RAW_ORDERS
> LIMIT 5;
> ```
> **EXPECT** Readable 2024 dates and `2024` in every row.

**If you see `Invalid date` or years like `-28237` or `12402`,** the fix in 0.7
was not applied. Re-apply it and re-run 0.11.

> 🎓 **The most valuable accidental lesson in the engagement.** When this bug is
> live, *every automated signal says success*: the script prints "Done", row
> counts match exactly on all four tables, dbt connects and builds, tests pass.
> **Five green lights, and every date is garbage.** The only thing that catches
> it is a human looking at ten rows.
>
> **Row counts tell you how much arrived. Never whether it's right.**

---

### 0.14 — Create the dbt project

> **WHERE** Terminal
> **TYPE**
> ```powershell
> cd "C:\Users\YOU\Documents\Ecommerce Revenue Leakage Project"
> dbt init lumen_loom --skip-profile-setup
> cd lumen_loom
> ```
> **EXPECT** A new `lumen_loom` folder containing `dbt_project.yml`, `models/`,
> `tests/`, `macros/` and more.

> **WHY `--skip-profile-setup`** — without it, dbt runs an interactive interview
> asking for your account and password, and **writes your password into a file
> on disk**. We're not doing that; credentials stay in environment variables.

> **WHY the name `lumen_loom`** — that's the fictional client, and the
> fellowship's starter files expect it. Consistency means their examples match
> yours.

**Clear out the demo files and create the layer folders:**

> **TYPE**
> ```powershell
> Remove-Item -Recurse -Force "models\example"
> New-Item -ItemType Directory -Force "models\staging","models\intermediate","models\marts"
> ```
> **EXPECT** Three folders listed.

> **WHY delete `models/example`** — `dbt init` drops in two toy models that
> point at nothing real and will fail on your first run.

| Folder | Job | Rule of thumb |
|---|---|---|
| `staging` | One model per source table. Rename, fix types. **No joins, no logic** | "Make it clean" |
| `intermediate` | The hard thinking. Deduplicate, classify | "Make it correct" |
| `marts` | The final answer the business reads | "Make it useful" |

> 🎓 **Each layer is only allowed to do its own kind of work.** When a number
> comes out wrong, you know which layer to look in. That's the entire reason
> the structure exists.

---

### 0.15 — Connection profile

> **WHERE** Terminal, then VS Code
> **TYPE**
> ```powershell
> New-Item -ItemType Directory -Force "$env:USERPROFILE\.dbt"
> code "$env:USERPROFILE\.dbt\profiles.yml"
> ```
> **EXPECT** A blank file opens in VS Code.

> **WHY a folder starting with a dot** — Windows Explorer refuses to create
> those (the dot means "hidden" on Unix systems, and dbt follows that
> convention). The terminal has no such objection.

> **WHY outside the project** — connection details are personal to you. Your
> project folder goes to GitHub; your credentials must not travel with it.

> **FILE** `C:\Users\YOU\.dbt\profiles.yml`
> **TYPE**
> ```yaml
> lumen_loom:
>   target: dev
>   outputs:
>     dev:
>       type: snowflake
>       account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
>       user: "{{ env_var('SNOWFLAKE_USER') }}"
>       password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
>       role: "{{ env_var('SNOWFLAKE_ROLE') }}"
>       warehouse: "{{ env_var('SNOWFLAKE_WAREHOUSE') }}"
>       database: "{{ env_var('SNOWFLAKE_DATABASE') }}"
>       schema: DEV_YOURNAME
>       threads: 4
> ```
> Save with **Ctrl+S**.

**Line by line:**

| Line | Meaning |
|---|---|
| `lumen_loom:` | The profile name. **Must match** `profile:` in `dbt_project.yml` |
| `target: dev` | Which settings to use by default. Add a `prod:` block later |
| `type: snowflake` | Which database dialect to speak |
| `{{ env_var('...') }}` | **"Go read this off the terminal."** Password never touches disk |
| `schema: DEV_YOURNAME` | Where dbt **writes**. Hard-coded on purpose — see below |
| `threads: 4` | Build up to 4 independent models simultaneously |

> ⚠️ **`schema:` is hard-coded, not read from `SNOWFLAKE_SCHEMA`.** That
> variable says `RAW`, which was right for the generator. **dbt must never
> write into RAW.** It reads from RAW and writes to DEV.

> ⚠️ **Indentation is the syntax, not decoration.** YAML has no brackets —
> spaces are the only thing telling the computer what belongs to what.

| Indent | Line | Belongs to |
|---|---|---|
| 0 | `lumen_loom:` | the file |
| 2 | `outputs:` | the profile |
| 4 | `dev:` | outputs |
| 6 | `type:`, `account:` … | dev |

**If `dev:` ends up at 2 spaces instead of 4**, `outputs` is empty and dbt
reports `TypeError: argument of type 'NoneType' is not a container` — which
sounds like a bug and is a typo. Fix: select `dev:` and everything below it,
press **Tab** once.

**Use spaces, never Tab, inside the YAML.** Copy-paste rather than retyping.

**Check what actually saved:**

> **TYPE**
> ```powershell
> Get-Content "$env:USERPROFILE\.dbt\profiles.yml"
> ```

---

### 0.16 — Layer materialisations

> **WHERE** VS Code
> **FILE** `lumen_loom/dbt_project.yml`
> **TYPE**
> ```powershell
> code "dbt_project.yml"
> ```

Scroll to the bottom. **Replace the entire `models:` block** (which mentions
`example`) with:

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

Save.

| Setting | What dbt creates | Why here |
|---|---|---|
| `view` | A saved query. Runs fresh each read. Stores no data | Staging is thin renaming — cheap to re-run, always current |
| `table` | Real, physical, written once | Marts are read repeatedly — pay once, read fast |
| `ephemeral` | **Nothing.** SQL is pasted inline | Textbook choice for intermediate, but see below |

The `+` prefix marks it as a setting rather than a folder name.

> 🎓 **`ephemeral` is the textbook choice for intermediate models. Use `view`
> for teaching**, because you cannot point at something that doesn't exist and
> say "look, the duplicates are gone." Say this out loud — it's a real
> engineering trade-off (*ephemeral is cleaner, view is inspectable*), and real
> teams switch a model to `view` precisely when they need to debug it.

> 🎓 **The cost/freshness trade-off is the lesson.** A view is always current
> but recomputes on every read. A table is instant but frozen until the next
> run. No correct answer — only the right answer *for that layer*.

---

### 0.17 — Prove the connection

> **WHERE** Terminal, inside `lumen_loom/`
> **TYPE**
> ```powershell
> dbt debug
> ```
> **EXPECT**
> ```
> Configuration:
>   profiles.yml file [OK found and valid]
>   dbt_project.yml file [OK found and valid]
> Connection:
>   account: your-org-your-account
>   user: YOUR_USERNAME
>   database: LUMEN_LOOM
>   warehouse: COMPUTE_WH
>   role: ACCOUNTADMIN
>   schema: DEV_YOURNAME
>   Connection test: [OK connection ok]
>
> All checks passed!
> ```

> **WHY this before anything else** — it separates *connection* problems from
> *SQL* problems. Skip it, and a failure later leaves you unsure whether your
> SQL is wrong or you simply never logged in.

**Read the Connection block back to the class.** Every value there was pulled
from an environment variable. Nothing was written to a file.

**Session 0 is complete.**

---

# Session 1 — Raw data and the staging layer

**Goal:** four staging models built, and students understand *why* staging is
forbidden from doing anything interesting.

---

### 1.1 — Look before you write (10 min)

> **WHERE** Snowflake worksheet
> **TYPE**
> ```sql
> SELECT * FROM LUMEN_LOOM.RAW.RAW_ORDERS LIMIT 20;
> ```
> **EXPECT** 20 rows: order IDs, customer IDs, statuses, amounts, three
> currencies, timestamps.

> **WHY** Never write SQL against a column you haven't looked at. Point out the
> mixed currencies now — it becomes a finding in Session 3.

**Get the full column lists for all four tables:**

> **TYPE** (run one at a time — click the line, Ctrl+Enter)
> ```sql
> DESCRIBE TABLE LUMEN_LOOM.RAW.RAW_ORDERS;
> DESCRIBE TABLE LUMEN_LOOM.RAW.RAW_PAYMENTS;
> DESCRIBE TABLE LUMEN_LOOM.RAW.RAW_REFUNDS;
> DESCRIBE TABLE LUMEN_LOOM.RAW.RAW_SHIPPING;
> ```

**Reference — the four tables:**

| `RAW_ORDERS` | `RAW_PAYMENTS` | `RAW_REFUNDS` | `RAW_SHIPPING` |
|---|---|---|---|
| ORDER_ID | PAYMENT_ID | REFUND_ID | SHIPMENT_ID |
| CUSTOMER_ID | ORDER_ID | ORDER_ID | ORDER_ID |
| ORDER_STATUS | PAYMENT_STATUS | PAYMENT_ID | CARRIER |
| ORDER_AMOUNT | AMOUNT | REFUND_AMOUNT | SHIPPING_COST |
| CURRENCY | CURRENCY | CURRENCY | STATUS |
| CREATED_AT | PAYMENT_METHOD | REFUND_REASON | SHIPPED_AT |
| UPDATED_AT | GATEWAY_FEE | REFUND_STATUS | DELIVERED_AT |
| | ATTEMPTED_AT | REQUESTED_AT | |
| | PROCESSED_AT | PROCESSED_AT | |

> ⚠️ **Spot the collisions now.** Four tables have a `STATUS`-type column. Two
> have `PROCESSED_AT`. These must be renamed at the staging boundary or they
> will collide in joins later.

---

### 1.2 — The question that frames everything (15 min)

> **WHERE** Snowflake worksheet
> **TYPE**
> ```sql
> SELECT order_status, COUNT(*) AS orders, SUM(order_amount) AS value
> FROM LUMEN_LOOM.RAW.RAW_ORDERS
> GROUP BY order_status
> ORDER BY orders DESC;
> ```
> **EXPECT**

| Status | Orders | Value | Share |
|---|---|---|---|
| completed | 32,127 | $2,095,456 | 64.3% |
| confirmed | 9,399 | $605,712 | 18.6% |
| cancelled | 4,515 | $295,282 | 9.1% |
| placed | 3,959 | $262,041 | 8.0% |

**Total order book: $3,258,491**

### ❓ ASK — before any SQL is written

> **"Which of these four is revenue?"**

Let them argue. `completed` is obvious. `cancelled` is obvious. But **`confirmed`
and `placed` together are $867,753 — 27% of the book** — and a status column
alone cannot resolve them.

Then the follow-up that decides the whole engagement:

> **"A cancelled order is only *not* revenue if the money went back. Does this
> table tell you whether it did?"**

It doesn't. **You cannot answer the question from `RAW_ORDERS`.** That is why
you build a pipeline instead of writing one clever query.

---

### 1.3 — Source definitions (10 min)

> **WHERE** VS Code
> **FILE** `models/staging/sources.yml`
> **TYPE**
> ```powershell
> code "models\staging\sources.yml"
> ```

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

**Verify it saved:**
```powershell
Get-Content "models\staging\sources.yml"
```

| Line | Meaning |
|---|---|
| `version: 2` | Config format version. Always 2 |
| `- name: raw` | The nickname used in SQL: `source('raw', 'raw_orders')` |
| `database` / `schema` | The real address in Snowflake |
| `loaded_at_field` | Which column says when the row arrived |
| `freshness` | How stale is too stale. Used in Session 4 |

> **What a `sources.yml` is:** dbt's address book for data it didn't create.
> Your raw tables were loaded by Python, so dbt has no idea they exist. Two
> payoffs — **change the location in one file** instead of fifty, and **dbt
> learns the dependency graph** so it builds in the right order automatically.

> **Why shipping gets 72/96 instead of 36/48:** its timestamp column is
> legitimately nullable (carrier timeouts). A feed that goes quiet for good
> reasons needs a looser threshold. **Thresholds come from how a table actually
> behaves, not copied across.**

> 🎓 **Read the descriptions aloud.** The fellowship planted the entire plot in
> them: *"payment ATTEMPT (includes failures and retries)"*, *"can be partial;
> often a later month"*, *"timestamps go missing"*. Nothing here is an accident.

---

### 1.4 — First model (20 min)

> **WHERE** VS Code
> **FILE** `models/staging/stg_orders.sql`
> **TYPE**
> ```powershell
> code "models\staging\stg_orders.sql"
> ```

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

Save with **Ctrl+S**. Check the tab is named `stg_orders.sql`, not `Untitled-1`.

> **WHERE** Terminal
> **TYPE**
> ```powershell
> dbt run
> ```
> **EXPECT**
> ```
> 1 of 1 OK created sql view model DEV_YOURNAME.stg_orders [SUCCESS 1 in 1.7s]
> Done. PASS=1 WARN=0 ERROR=0
> ```

**Verify in Snowflake:**
```sql
SELECT * FROM LUMEN_LOOM.DEV_YOURNAME.STG_ORDERS LIMIT 10;
```

### Teaching beats

**`{{ source('raw', 'raw_orders') }}`** — double curly braces mean "look this
up." At run time dbt replaces it with `LUMEN_LOOM.RAW.RAW_ORDERS`.

**`with source as (...)`** — a named step. Read it as *"first do this bit and
call it `source`."* Makes SQL read top-to-bottom like instructions instead of
inside-out.

**You wrote a `SELECT`. dbt wrote the `CREATE`.** That is the core of what the
tool does — you describe the shape of the data you want; dbt handles naming,
placing and rebuilding it.

**`lower(order_status)`** — source systems are inconsistent. `Completed` and
`completed` would silently split your totals.

**`created_at as ordered_at`** — rename to say what it *means*. Every table has
a `created_at`; only this one has an `ordered_at`.

**What's deliberately absent: no filtering, no joins, no business rules.**
Staging does not decide what counts as revenue.

---

### 1.5 — The other three (30 min)

Demonstrate `stg_payments`. Let students write `stg_refunds` and
`stg_shipping` themselves — the shape is identical.

> **FILE** `models/staging/stg_payments.sql`

```sql
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

> **FILE** `models/staging/stg_refunds.sql`

```sql
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

> **FILE** `models/staging/stg_shipping.sql`

```sql
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

> **TYPE**
> ```powershell
> dbt run
> ```
> **EXPECT** `PASS=4`

### The three renames that matter

| From | To | Why |
|---|---|---|
| `amount` | `payment_amount` | Meaningless once it sits beside `order_amount` in a join |
| `processed_at` | `refunded_at` | Both payments and refunds have `processed_at` — two different events |
| `status` | `shipment_status` | Four tables have a status. Four columns named `status` is a guaranteed bug |

> 🎓 **Rename at the door, before the collision can happen.** You can't fix a
> name collision after the join — by then you have two columns with the same
> name and no way to tell which is which.

**Note what you did NOT do:** you know `stg_payments` contains failed attempts
and duplicate webhooks. **Resist removing them here.** Staging renames; it
doesn't judge. Those decisions belong in the intermediate layer where they can
be explained and tested.

---

### 1.6 — Close the session

Point at the `dbt run` log. Models started at the same second and finished
together — that's `threads: 4`. dbt built independent models in parallel
without being told to.

**Homework:** *"Tomorrow we find out how much money is missing. Write your
guess down now."*

---

# Session 2 — Finding the leaks

**Goal:** three findings quantified, and the fan-out join understood.

---

### 2.1 — Duplicates (20 min)

### ❓ ASK — before running

> **"An order should have exactly one successful payment. Does it?"**

> **WHERE** Snowflake worksheet
> **TYPE**
> ```sql
> with success_counts as (
>
>     select
>         order_id,
>         count(*)            as successful_payments,
>         sum(payment_amount) as total_charged
>     from LUMEN_LOOM.DEV_YOURNAME.STG_PAYMENTS
>     where payment_status = 'succeeded'
>     group by order_id
>
> )
>
> select
>     count(*)                                                                      as orders_double_logged,
>     sum(successful_payments - 1)                                                  as duplicate_rows,
>     round(sum(total_charged * (successful_payments - 1) / successful_payments), 2) as overstated_revenue
> from success_counts
> where successful_payments > 1;
> ```
> **EXPECT** `642 | 642 | 41396.82`

**Reading the query:**

| Clause | Doing |
|---|---|
| `where payment_status = 'succeeded'` | Ignore failed attempts — noise, not money |
| `group by order_id` | Collapse to one row per order |
| `where successful_payments > 1` | Keep only orders that succeeded more than once |
| `total_charged * (n-1) / n` | The phantom money. $60 logged twice = $120, half is fake |

> **Say this before pressing Run:** *"Finance summed the payments table and got
> a revenue number. If this returns anything above zero, that number is wrong —
> and nobody in the company knows by how much."*

**Result: 642 orders, 642 duplicate rows, $41,396.82.**

> 🎓 **Exactly one extra per order.** Too regular to be random. This is a
> systematic technical fault — a webhook delivered twice — which is precisely
> what makes it findable and fixable.

---

### 2.2 — Deduplicate (25 min)

> **WHERE** VS Code
> **FILE** `models/intermediate/int_payments_deduplicated.sql`
> **TYPE**
> ```powershell
> code "models\intermediate\int_payments_deduplicated.sql"
> ```

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

> **TYPE**
> ```powershell
> dbt run
> ```
> **EXPECT** `PASS=3`. Watch the log — `stg_payments` finishes, *then*
> `int_payments_deduplicated` starts.

### Teaching beats

**`{{ ref('stg_payments') }}`** — the partner to `source()`. `source()` points
at data dbt **didn't** make; **`ref()` points at data dbt did.** It is
simultaneously a reference *and* a dependency declaration. dbt now knows the
build order and you never wrote it down.

**`row_number() over (partition by order_id order by processed_at, payment_id)`**
— read it as a sentence:

| Part | Meaning |
|---|---|
| `partition by order_id` | Deal the rows into piles, one pile per order |
| `order by processed_at, payment_id` | Sort each pile by when it settled |
| `row_number()` | Number them 1, 2, 3 within each pile |
| `where payment_rank = 1` | Keep the first from every pile |

**Why not `SELECT DISTINCT`** — same row count, but this lets you choose *which*
copy survives: the earliest genuine settlement, not an arbitrary one.

**Why `payment_id` as a tie-breaker** — if two duplicates settled in the same
second, `processed_at` alone can't decide, and the winner is random. **The model
would return different data on different runs.** Always break the tie.

**Prove it worked:**

> **WHERE** Snowflake worksheet
> **TYPE**
> ```sql
> SELECT
>     (SELECT COUNT(*) FROM LUMEN_LOOM.DEV_YOURNAME.STG_PAYMENTS
>      WHERE payment_status = 'succeeded')                                    AS before_dedup,
>     (SELECT COUNT(*) FROM LUMEN_LOOM.DEV_YOURNAME.INT_PAYMENTS_DEDUPLICATED) AS after_dedup;
> ```
> **EXPECT** `45172 | 44530` — a difference of **exactly 642**.

> 🎓 **Why show both numbers, not just the new one.** Anyone can write SQL that
> removes rows. Showing it removed *precisely* the rows you identified, and no
> others, is what makes it trustworthy. **If the gap were bigger than 642, the
> dedup would be eating real payments.**

> ⚠️ **Note the second number: 44,530 paid orders out of 50,000.** So 5,470
> orders never produced money at all. Hold that thought until Session 4.

> ⚠️ **`intermediate` must be set to `view` in `dbt_project.yml`.** If it's
> `ephemeral`, dbt builds nothing and this query fails with *"Object does not
> exist"*. See 0.16.

---

### 2.3 — The uncomfortable question (20 min)

### ❓ ASK — before running

> **"How much money did we collect on orders we cancelled?"**

Most people say zero.

> **WHERE** Snowflake worksheet
> **TYPE**
> ```sql
> select
>     o.order_status,
>     count(*)                         as orders_charged,
>     round(sum(p.payment_amount), 2)  as cash_collected
> from LUMEN_LOOM.DEV_YOURNAME.STG_ORDERS o
> join LUMEN_LOOM.DEV_YOURNAME.INT_PAYMENTS_DEDUPLICATED p
>   on o.order_id = p.order_id
> group by o.order_status
> order by cash_collected desc;
> ```
> **EXPECT**

| Status | Orders charged | Cash | Share of that status |
|---|---|---|---|
| completed | 32,127 | $2,095,456 | — |
| confirmed | 9,399 | $605,712 | — |
| **cancelled** | **2,024** | **$131,272** | **45% of all cancellations** |
| **placed** | **980** | **$66,728** | **25% of all placed orders** |

**Total cash after dedup: $2,899,168.76**

> 🎓 **45% and 25% are far too clean to be accidents.** A system is behaving
> consistently. This is a *process* defect — somebody's cancellation flow
> doesn't talk to the payment gateway — not data-entry error.

### The fan-out join — teach this now

**It is safe to join here *only because* `int_payments_deduplicated` has one row
per order.** Had you joined to `stg_payments` instead, the 642 duplicates would
each have pulled their order row through twice, and your totals would be wrong.

> ⚠️ **A fan-out join never throws an error.** Join to a table with duplicates
> and every duplicate silently multiplies the other side. It is the single most
> common way revenue gets overstated in real companies.

---

### 2.4 — Where did the money go? (25 min)

> **WHERE** Snowflake worksheet
> **TYPE**
> ```sql
> with charged as (
>
>     select
>         o.order_id,
>         o.order_status,
>         p.payment_amount
>     from LUMEN_LOOM.DEV_YOURNAME.STG_ORDERS o
>     join LUMEN_LOOM.DEV_YOURNAME.INT_PAYMENTS_DEDUPLICATED p
>       on o.order_id = p.order_id
>
> ),
>
> refunded as (
>
>     select
>         order_id,
>         sum(refund_amount) as refund_amount
>     from LUMEN_LOOM.DEV_YOURNAME.STG_REFUNDS
>     where refund_status = 'completed'
>     group by order_id
>
> )
>
> select
>     c.order_status,
>     count(*)                                                       as orders,
>     round(sum(c.payment_amount), 2)                                as charged,
>     round(sum(coalesce(r.refund_amount, 0)), 2)                    as refunded,
>     round(sum(c.payment_amount - coalesce(r.refund_amount, 0)), 2) as still_held
> from charged c
> left join refunded r
>   on c.order_id = r.order_id
> group by c.order_status
> order by still_held desc;
> ```

> ⚠️ **Watch for a truncated paste.** If the last `as` has no name after it,
> Snowflake fails and points at `from` on the *next* line. **The error location
> is where the parser gave up, not where you made the mistake.** Always check
> the line above.

**EXPECT**

| Status | Charged | Refunded | Still held | % returned |
|---|---|---|---|---|
| completed | $2,095,456 | $132,503 | $1,962,953 | 6.3% — normal returns |
| confirmed | $605,712 | $36,039 | $569,673 | 5.9% — normal returns |
| **cancelled** | $131,272 | $86,844 | **$44,428** | 66% — a third never went back |
| **placed** | $66,728 | $4,450 | **$62,278** | 6.7% — almost none went back |

**Total refunds: $259,837.**

### Three things to teach from this one query

**1. `refunded` aggregates *before* joining.** An order could have several
refunds. Join first and you'd fan out the payment rows again — the same mistake
in a new costume. **Collapse to one row per key, then join.** Make it a reflex.

**2. `left join`, not `join`.** A plain join drops every order that was never
refunded — which is most of them, and exactly the population you're hunting.

**3. `coalesce(r.refund_amount, 0)`** — "if blank, treat as zero." Without it,
`payment_amount - NULL` returns NULL, not the payment amount. **In SQL, blank is
not zero; it is *unknown*, and unknown poisons every calculation it touches.**
This single mistake silently deletes rows from financial totals more often than
any other.

### ❓ ASK

> **"These two bottom rows look similar. Are they the same problem?"**

**No — and that's the finding.**

- **Cancelled:** someone is trying. Two thirds returned. There *is* a refund
  process; it leaks. **Operations fix.**
- **Placed:** nobody is trying. 93% never returned — and 6.7% happens to match
  the ordinary returns rate for delivered goods, which means **no
  cancellation-driven refunds are occurring at all.** Those customers may not
  even know they were charged. **Unmonitored failure mode.**

---

# Session 3 — Classification and the bridge

**Goal:** one verdict per order, and a bridge finance can argue with.

---

### 3.1 — Check the grain, always (10 min)

> **WHERE** Snowflake worksheet
> **TYPE**
> ```sql
> select
>     count(*)                  as shipping_rows,
>     count(distinct order_id)  as distinct_orders
> from LUMEN_LOOM.DEV_YOURNAME.STG_SHIPPING;
> ```
> **EXPECT** `42811 | 42811` — one row per order. Safe to join.

> 🎓 **Before joining any table, ask "one row per what?"** If the numbers match,
> the join is safe. If they don't, you must aggregate first. This question has a
> name — the **grain** of a table — and getting it wrong is the number one cause
> of wrong numbers in analytics.

> ⚠️ **There's already a finding here.** 44,530 paid orders but only 42,811
> shipping rows. **1,719 paid orders that shipping has never heard of.**

---

### 3.2 — Did the goods go out? (20 min)

### ❓ ASK — before running

> **"How many `completed` orders should be missing a ship date?"**

Zero. You cannot complete an order you never sent.

> **WHERE** Snowflake worksheet
> **TYPE**
> ```sql
> with charged as (
>
>     select
>         o.order_id,
>         o.order_status,
>         p.payment_amount
>     from LUMEN_LOOM.DEV_YOURNAME.STG_ORDERS o
>     join LUMEN_LOOM.DEV_YOURNAME.INT_PAYMENTS_DEDUPLICATED p
>       on o.order_id = p.order_id
>
> )
>
> select
>     c.order_status,
>     count(*)                                                                       as paid_orders,
>     count(s.order_id)                                                              as has_shipment_row,
>     count(s.shipped_at)                                                            as has_ship_date,
>     count(s.delivered_at)                                                          as has_delivery_date,
>     round(sum(case when s.shipped_at is null then c.payment_amount else 0 end), 2) as cash_never_shipped
> from charged c
> left join LUMEN_LOOM.DEV_YOURNAME.STG_SHIPPING s
>   on c.order_id = s.order_id
> group by c.order_status
> order by cash_never_shipped desc;
> ```
> **EXPECT**

| Status | Paid | Has row | Has ship date | Has delivery date | Cash never shipped |
|---|---|---|---|---|---|
| completed | 32,127 | 32,127 | 29,635 | **30,275** | $164,870 |
| cancelled | 2,024 | 305 | 277 | 285 | $112,411 |
| confirmed | 9,399 | 9,399 | 8,661 | **8,921** | $48,563 |
| placed | 980 | 980 | 907 | 929 | $4,954 |

**Two SQL techniques doing the work:**

**`count(*)` vs `count(column)`** — `count(*)` counts rows; `count(column)`
counts only rows where that column has a value. Side by side they show exactly
where the data thins out. **Each step should be smaller than the last. How much
smaller is the finding.**

**`sum(case when ... then amount else 0 end)`** — a running total that only
picks up the rows you care about. **The single most useful pattern in analytics
SQL.** Students will use it every day.

### Three findings

**1. 2,492 "completed" orders have no ship date — $164,870.** Revenue recognised
against goods that may not exist anywhere but a status column.

**2. 1,719 charged cancelled orders don't exist in shipping at all — $112,411.**
Not shipping a cancelled order is correct. Charging for it is not.

**3. The impossible one.** In *every* row, `has_delivery_date` is **larger** than
`has_ship_date`. **640 orders were delivered before they were shipped.**

> 🎓 **Give the third one a full minute of silence.** Not late. Not missing.
> *Impossible.* Nothing in the real world produces it — it can only be a defect
> in how the carrier feed writes data. And critically: **no `count(*)` would
> ever have revealed it.** It only appears when you compare two columns that
> must have a logical relationship and find they don't.

---

### 3.3 — One verdict per order (35 min)

> **WHERE** VS Code
> **FILE** `models/intermediate/int_order_revenue.sql`
> **TYPE**
> ```powershell
> code "models\intermediate\int_order_revenue.sql"
> ```

> 🔴 **Build it FIRST without the `and delivered_at is null` line.** The
> over-correction that follows is the most important teaching moment in the
> engagement. Type it exactly as below.

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
            when shipped_at is null         then 'charged_not_shipped'
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

> **TYPE**
> ```powershell
> dbt run
> ```
> **EXPECT** `PASS=6`

### The two ideas in this model

**1. `orders` is the base and every join is a `left join`.** All 50,000 orders
survive. An order with no payment gets a blank payment; an order with no
shipment gets a blank ship date. **You never lose a row, so nothing can go
missing without you seeing it.**

**2. The order of the `case` conditions is the business rule.** `case` checks
top to bottom and **stops at the first match**:

| Order | Check | Meaning |
|---|---|---|
| 1 | `payment_amount is null` | No money moved. Nothing to argue about |
| 2 | `order_status = 'cancelled'` | Money on a cancelled order — beats every other concern |
| 3 | `order_status = 'placed'` | Money on an order that never progressed |
| 4 | `shipped_at is null` | Live order, paid, no evidence it shipped |
| 5 | `else` | Genuine revenue |

> 🎓 **This is why you couldn't add up the four findings earlier.** An order that
> is both cancelled *and* never shipped now lands in exactly one bucket — the
> more serious one. **Every order gets one verdict. No double-counting, by
> construction.**

> 🎓 **Rearranging those five lines changes the company's revenue number.** That
> isn't a SQL detail — it's an accounting policy written in SQL. Whoever owns
> that ordering owns the definition of revenue, and it should be Finance, not
> the analyst.

---

### 3.4 — 🔴 The over-correction (15 min)

> **WHERE** Snowflake worksheet
> **TYPE**
> ```sql
> select
>     revenue_category,
>     count(*)                                   as orders,
>     round(sum(coalesce(payment_amount, 0)), 2) as cash_collected,
>     round(sum(refund_amount), 2)               as refunded,
>     round(sum(recognised_revenue), 2)          as recognised
> from LUMEN_LOOM.DEV_YOURNAME.INT_ORDER_REVENUE
> group by revenue_category
> order by cash_collected desc;
> ```
> **EXPECT**

| Category | Orders | Cash collected | Recognised |
|---|---|---|---|
| recognisable | 38,296 | $2,487,735 | **$2,331,181** |
| charged_not_shipped | 3,230 | $213,433 | $0 |
| cancelled_but_charged | 2,024 | $131,272 | $0 |
| placed_but_charged | 980 | $66,728 | $0 |
| never_charged | 5,470 | $0 | $0 |
| **Total** | **50,000** | **$2,899,169** | **$2,331,181** |

Finance's figure is **$2,940,566**. Your gap is **$609,385 — 20.7%**.

### ❓ ASK

> **"The brief predicts 8–12% leakage. You're at 20.7%. What do you do?"**

**Check your work before presenting it.** When your answer is nearly double
what the client expects, you are probably wrong, not them.

> **"The suspect is `charged_not_shipped` — $213,433 written off. Does 'no ship
> date' mean it never shipped?"**

No. **640 of those orders have a *delivery* date.** Something delivered was
shipped. The timestamp is missing; the event isn't.

**Your model is treating missing data as a business failure.**

### The fix — one line

> **FILE** `models/intermediate/int_order_revenue.sql`
> Change:
> ```sql
>             when shipped_at is null         then 'charged_not_shipped'
> ```
> To:
> ```sql
>             when shipped_at is null
>              and delivered_at is null       then 'charged_not_shipped'
> ```

> **TYPE**
> ```powershell
> dbt run
> ```
> Then re-run the category query.
> **EXPECT**

| Category | Orders | Cash collected | Recognised |
|---|---|---|---|
| recognisable | 41,526 | $2,701,168 | **$2,532,626** |
| cancelled_but_charged | 2,024 | $131,272 | $0 |
| placed_but_charged | 980 | $66,728 | $0 |
| never_charged | 5,470 | $0 | $0 |

**Leakage drops from 20.7% to 13.9%.**

> ⚠️ **The verification that matters: total cash must still be $2,899,168.76.**
> Orders moved between buckets; no money was created or destroyed. **If the
> total shifts by a cent, you've broken the classification, not refined it.**

> 🎓 **`charged_not_shipped` isn't smaller — it's gone.** All 3,230 orders moved.
> **A rule that never fires is itself a finding:** it means the carrier feed
> doesn't lose shipments, it loses ship *timestamps* specifically. That's a
> narrow, fixable defect in one integration, and you can now tell the client
> exactly that. **Keep the rule anyway** — it's a live tripwire for when the
> feed degrades further.

> 🎓 **The transferable lesson, and the most valuable idea in the engagement:**
> *"the field is empty" and "the thing didn't happen" are different claims.*
> Treating them as the same will systematically understate your business. For
> every null you act on, ask: **is this a missing event, or a missing record of
> an event?** Then go looking for corroborating evidence elsewhere in the data.

---

### 3.5 — The bridge (20 min)

> **WHERE** VS Code
> **FILE** `models/marts/rpt_revenue_bridge.sql`
> **TYPE**
> ```powershell
> code "models\marts\rpt_revenue_bridge.sql"
> ```

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

> **TYPE**
> ```powershell
> dbt run
> ```
> **EXPECT** `PASS=7`, and note `sql table model` — this is your first **table**,
> not a view. `[SUCCESS 10 in 1.7s]` — the 10 is rows created.

> **WHERE** Snowflake worksheet
> **TYPE**
> ```sql
> select * from LUMEN_LOOM.DEV_YOURNAME.RPT_REVENUE_BRIDGE order by step;
> ```
> **EXPECT**

| Step | Line item | Amount |
|---|---|---|
| 1 | Gateway total: all successful payments | 2,940,565.58 |
| 2 | Less: duplicate payment webhooks | (41,396.82) |
| 3 | Less: cancelled orders that were charged | (131,272.28) |
| 4 | Less: placed orders that were charged | (66,728.17) |
| 5 | Less: charged, no shipping evidence | 0.00 |
| 6 | Less: refunds on recognised orders | (168,542.64) |
| 7 | **Defensible revenue** | **2,532,625.67** |
| 8 | Less: processing fees on recognised revenue | (90,790.54) |
| 9 | **Revenue net of payment costs** | **2,441,835.13** |
| 10 | Memo: fees on revenue never recognised (sunk) | (6,643.44) |

**Steps 1–6 must sum to step 7.** Check it live on screen.

> 🎓 **Why a bridge beats a corrected number.** A single figure on a slide invites
> one response: *"that's wrong."* A bridge invites *"explain line 3."* One is a
> conversation; the other is a fight. And the client can accept four of your six
> adjustments and still use the work. This shape has a name in finance: a
> **bridge**, or a **waterfall**.

> 🎓 **Step 10 is labelled "Memo" because it sits outside the arithmetic.**
> Finance uses that convention for a figure that's relevant but doesn't
> participate in the walk. Mixing it in would break the reconciliation.

> 🎓 **Steps 9 and 10 are different kinds of number.** The $407,940 overstatement
> is an **accounting** correction — money never really earned. The $6,643 of
> sunk fees is an **actual cash loss** — the gateway charged ~2.9% + $0.30 on
> 3,004 orders that should never have been charged, and processing fees are
> generally not returned on refund. **One changes the books; the other changed
> the bank balance.**

---

### 3.6 — The problem that invalidates the total (15 min)

> **WHERE** Snowflake worksheet
> **TYPE**
> ```sql
> select
>     currency,
>     count(*)                          as orders,
>     round(sum(recognised_revenue), 2) as recognised
> from LUMEN_LOOM.DEV_YOURNAME.INT_ORDER_REVENUE
> where recognised_revenue > 0
> group by currency
> order by recognised desc;
> ```
> **EXPECT** USD $1,823,001 · GBP $357,981 · EUR $351,643 — **28% non-USD**

### ❓ ASK

> **"$2,532,625.67 of *what*?"**

You have been adding dollars, pounds and euros as though they were the same
thing. **The total is not a currency amount at all** — it's a sum of unrelated
numbers that happen to share a column.

And the part that makes it a consulting finding rather than a SQL bug:
**there is no exchange-rate table anywhere in this data.** You cannot fix it.
Not with better SQL, not with more effort.

> 🎓 **The most senior thing in the entire engagement.** A junior analyst
> converts at today's Google rate and delivers a confident number. A senior one
> recognises that the choice of rate — transaction date, month-end, or a hedged
> internal rate — is a finance policy decision that changes the answer by tens
> of thousands, and refuses to make it silently on the client's behalf.
> **Knowing when to stop and ask is a skill, not a failure. The deliverable is
> the question.**

**Now build the version that is actually valid:**

> **FILE** `models/marts/rpt_revenue_bridge_by_currency.sql`

```sql
with orders as (

    select * from {{ ref('int_order_revenue') }}

),

gateway as (

    select
        currency,
        sum(payment_amount) as gateway_total
    from {{ ref('stg_payments') }}
    where payment_status = 'succeeded'
    group by currency

),

deduped as (

    select
        currency,
        sum(payment_amount) as deduped_total
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

> **TYPE**
> ```powershell
> dbt run
> ```
> **WHERE** Snowflake worksheet
> ```sql
> select * from LUMEN_LOOM.DEV_YOURNAME.RPT_REVENUE_BRIDGE_BY_CURRENCY;
> ```
> **EXPECT**

| Currency | Gateway total | Defensible revenue | Overstatement | Rate |
|---|---|---|---|---|
| USD | $2,119,539 | $1,823,001 | $296,538 | **14.0%** |
| GBP | $414,653 | $357,981 | $56,672 | **13.7%** |
| EUR | $406,373 | $351,643 | $54,730 | **13.5%** |

**The three defensible figures must add to $2,532,625.67.**

**Why the layout flipped:** the first bridge was one row per *step*; this is one
row per *currency* with steps as columns. Same data, transposed. **Choose the
orientation that matches the question** — comparing *across* currencies vs
walking *down* a single reconciliation.

**Why plain `join`, not `left join`:** every currency in the gateway must appear
in all three CTEs. If one doesn't, you want the row to vanish loudly rather than
appear with blanks.

> 🎓 **The `overstatement` column produces a finding by *elimination*.** Rates
> are near-identical across three markets. If the cause were local process
> variation — a UK team handling cancellations badly, a European payments
> partner misbehaving — the rates would diverge. **They don't. So this is one
> shared platform defect, and one fix addresses all three markets.** That
> changes the recommendation entirely: you're not asking the client to audit
> three regional teams.

---

# Session 4 — Timing, testing and delivery

**Goal:** the timing finding, a test that fails on purpose, and a deliverable.

---

### 4.1 — The finding nobody has ever caught (25 min)

### ❓ ASK — before building

> **"A customer buys in January and is refunded in March. Which month loses the
> money?"**

March. **So January is overstated, March is understated — and the year is
perfect.**

> **WHERE** VS Code
> **FILE** `models/marts/rpt_revenue_by_month.sql`

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

> **TYPE**
> ```powershell
> dbt run
> ```
> **WHERE** Snowflake worksheet
> ```sql
> select * from LUMEN_LOOM.DEV_YOURNAME.RPT_REVENUE_BY_MONTH order by month;
> ```
> **EXPECT** 14 rows — 12 months of 2024, plus Jan and Feb 2025.

**How the query works:**

**`date_trunc('month', paid_at)`** — flattens every timestamp to the first of its
month. `2024-03-17 14:22` → `2024-03-01`. That's how you group by month.

**The two refund CTEs are identical except for one column — and that is the
entire lesson:**

| CTE | Groups refunds by | Represents |
|---|---|---|
| `refunds_as_booked` | `refunded_at` — when the money went back | **What the business reports today** |
| `refunds_matched` | `paid_at` — when the sale happened | **What it should report** |

Same refunds. Same annual total. Different months.

**`months` uses `union`, not a plain join.** Refunds processed in early 2025 have
no matching sales month, and a plain join would silently drop them. `union` (not
`union all`) also removes the duplicates.

### The three things to show

| Month | Net as reported | Net matched | Distortion |
|---|---|---|---|
| Jan 2024 | 219,019 | 211,857 | **(7,163)** |
| Oct 2024 | 217,158 | 219,052 | 1,894 |
| Nov 2024 | 208,628 | 209,886 | 1,258 |
| Jan 2025 | **(4,825)** | 0 | 4,825 |
| Feb 2025 | **(1,411)** | 0 | 1,411 |

**1. Negative revenue in two months where nothing was sold.** $6,236 of 2024
refunds arriving after 2024 closed. If the fiscal year ends 31 December, 2024 is
overstated by that amount and 2025 opens in the hole for reasons unrelated to
2025 trading.

**2. January is structurally overstated by $7,163.** January's refunds flow *out*
into February and March — but no prior month's refunds flow *in*, because there
is no prior month. **The first period of any reporting window is always
flattered.** Same happens on a new product line, a new market, a new system.

**3. Sum the distortion column. It comes to exactly zero.**

> 🎓 **That is the whole finding in one number. Every month is wrong. The year is
> right.** Which is exactly why nobody caught it — the annual figure reconciles
> perfectly to the bank, so every monthly report inherits an error the year-end
> check can never detect.
>
> Note October and November are *understated* — they absorbed earlier months'
> refunds. **Someone in that business almost certainly explained October's dip
> in a meeting.**

> 🎓 **This finding is arguably worth more than the $407,940.** Marketing spend
> judged on monthly ROI, sales commissions, forecast accuracy, month-over-month
> growth — all built on numbers that are individually wrong and collectively
> fine.

---

### 4.2 — Payment attempts (15 min)

> **WHERE** VS Code
> **FILE** `models/marts/rpt_payment_attempts.sql`

```sql
with orders as (

    select
        order_id,
        order_status,
        order_amount,
        currency
    from {{ ref('stg_orders') }}

),

attempts as (

    select
        order_id,
        count(*)                                                      as total_attempts,
        sum(case when payment_status = 'failed'    then 1 else 0 end) as failed_attempts,
        sum(case when payment_status = 'succeeded' then 1 else 0 end) as successful_attempts
    from {{ ref('stg_payments') }}
    group by order_id

),

joined as (

    select
        o.order_id,
        o.order_status,
        o.order_amount,
        coalesce(a.total_attempts, 0)      as total_attempts,
        coalesce(a.failed_attempts, 0)     as failed_attempts,
        coalesce(a.successful_attempts, 0) as successful_attempts,

        case
            when a.order_id is null        then 'no_payment_attempted'
            when a.successful_attempts = 0 then 'all_attempts_failed'
            when a.failed_attempts = 0     then 'first_time_success'
            else                                'recovered_after_retry'
        end as attempt_outcome

    from orders o
    left join attempts a
      on o.order_id = a.order_id

)

select
    attempt_outcome,
    count(*)                       as orders,
    sum(failed_attempts)           as failed_attempts,
    round(avg(total_attempts), 2)  as avg_attempts_per_order,
    round(sum(order_amount), 2)    as order_value

from joined
group by attempt_outcome
order by orders desc
```

> **TYPE**
> ```powershell
> dbt run
> ```
> **WHERE** Snowflake worksheet
> ```sql
> select * from LUMEN_LOOM.DEV_YOURNAME.RPT_PAYMENT_ATTEMPTS order by orders desc;
> ```
> **EXPECT**

| Outcome | Orders | Failed attempts | Avg attempts | Order value |
|---|---|---|---|---|
| first_time_success | 40,016 | 0 | **1.01** | $2,606,512 |
| no_payment_attempted | 4,947 | 0 | 0.00 | $325,202 |
| recovered_after_retry | 4,514 | 5,819 | 2.31 | $292,657 |
| **all_attempts_failed** | **523** | **665** | 1.27 | **$34,120** |

### Three things fall out — one validates your entire pipeline

**1. The cross-check.** 4,947 + 523 = **5,470** — *exactly* the `never_charged`
count from `int_order_revenue`. **Two models built by completely different logic
agree precisely.** Point at this.

**2. $34,120 of demand that produced nothing.** 5,037 orders hit at least one
payment failure; 4,514 recovered — an **89.6% recovery rate**. The remaining
10.4% is the leak. It isn't straightforwardly lost revenue (some customers
reordered) but it is **currently unmeasured and unmonitored**.

**3. `first_time_success` shows 1.01 average attempts, not 1.00.** With zero
failed attempts it should be exactly 1.00. **The extra 0.01 is your 642
duplicate webhooks showing up again from a completely different angle.**

---

### 4.3 — Generic tests (20 min)

> **WHERE** VS Code
> **FILE** `models/staging/schema.yml`

```yaml
version: 2

models:
  - name: stg_orders
    description: "One row per order, cleaned and renamed."
    columns:
      - name: order_id
        description: "Unique order identifier."
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
      - name: currency
        data_tests:
          - accepted_values:
              arguments:
                values: ['USD', 'GBP', 'EUR']

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
      - name: payment_status
        data_tests:
          - accepted_values:
              arguments:
                values: ['succeeded', 'failed']

  - name: stg_refunds
    description: "One row per completed refund. Often lands in a later month than the sale."
    columns:
      - name: refund_id
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
      - name: refund_amount
        data_tests:
          - not_null

  - name: stg_shipping
    description: "One row per shipment. Carrier feed drops timestamps on API timeouts."
    columns:
      - name: shipment_id
        data_tests:
          - unique
          - not_null
      - name: order_id
        data_tests:
          - unique
          - not_null
```

> **FILE** `models/intermediate/schema.yml`

```yaml
version: 2

models:
  - name: int_payments_deduplicated
    description: "One settling payment per order. Gateway duplicate webhooks removed."
    columns:
      - name: order_id
        description: "Unique after deduplication — that is the entire purpose of this model."
        data_tests:
          - unique
          - not_null
      - name: payment_id
        data_tests:
          - unique
          - not_null

  - name: int_order_revenue
    description: "One row per order with a single revenue verdict attached."
    columns:
      - name: order_id
        description: "Exactly one row per order. Everything downstream depends on this."
        data_tests:
          - unique
          - not_null
      - name: revenue_category
        data_tests:
          - accepted_values:
              arguments:
                values:
                  - recognisable
                  - cancelled_but_charged
                  - placed_but_charged
                  - charged_not_shipped
                  - never_charged
      - name: recognised_revenue
        data_tests:
          - not_null
```

> **FILE** `models/marts/schema.yml`

```yaml
version: 2

models:
  - name: rpt_revenue_bridge
    description: "The headline deliverable. Steps 1-6 sum to step 7."
    columns:
      - name: step
        data_tests:
          - unique
          - not_null
      - name: line_item
        data_tests:
          - not_null
      - name: amount
        data_tests:
          - not_null

  - name: rpt_revenue_bridge_by_currency
    description: "The same bridge, split by currency. The arithmetically valid version."
    columns:
      - name: currency
        data_tests:
          - unique
          - not_null
      - name: gateway_total
        data_tests:
          - not_null
      - name: defensible_revenue
        data_tests:
          - not_null

  - name: rpt_revenue_by_month
    description: "Monthly reporting is unreliable while the annual total is correct."
    columns:
      - name: month
        data_tests:
          - unique
          - not_null

  - name: rpt_payment_attempts
    description: "Payment attempt outcomes per order."
    columns:
      - name: attempt_outcome
        data_tests:
          - unique
          - not_null
```

> **WHERE** Terminal
> **TYPE**
> ```powershell
> dbt test
> ```
> **EXPECT** `PASS=39` (before adding the singular tests below)

> ⚠️ **Note the verb.** `dbt run` **builds** models. `dbt test` **checks** them.
> Different commands.

| Test | Asks |
|---|---|
| `unique` | Is this really one row per thing? **The grain question, automated** |
| `not_null` | Is this ever missing? |
| `accepted_values` | Has a new value appeared that my `case` doesn't handle? |
| `relationships` | Does every payment point at an order that actually exists? |

> 🎓 **`accepted_values` is the quiet hero.** Your entire revenue rule is a `case`
> listing four statuses. If the business adds a fifth — `returned`, say — your
> `else` sends it to `recognisable` and silently books it as revenue. Nothing
> errors. The number just goes wrong. This test catches it on the first run after
> the change.

> 🎓 **Note where the tests live.** `payment_id` is unique on `stg_payments`;
> `order_id` is **not** — and asserting that it were would fail, correctly,
> because that isn't what this table is. **Test the grain you have, not the
> grain you wish for.**

> 🎓 **The `unique` on `int_order_revenue.order_id` is the most important test in
> the project.** That model does four `left join`s. If any joined table ever
> gains a duplicate, orders fan out and every total inflates — **no error, no
> warning, just a bigger number.** This test is the only thing standing between
> you and that.

> ⚠️ **dbt 1.10+ requires generic-test arguments nested under `arguments:`.**
> Writing `values:` directly under `accepted_values:` still works but emits
> `MissingArgumentsPropertyInGenericTestDeprecation`. Fix deprecation warnings
> when they appear — ignore them for two years and you face forty at once during
> an upgrade.

---

### 4.4 — The test that matters most (10 min)

Generic tests check columns. **They cannot check that your bridge adds up.**

> **WHERE** VS Code
> **FILE** `tests/assert_bridge_balances.sql`

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

> **TYPE**
> ```powershell
> dbt test --select assert_bridge_balances
> ```
> **EXPECT** `PASS`

> 🎓 **How a dbt test works — the bit that confuses everyone.** A test is a query
> that should return **nothing**. **Rows returned = failures found.** It is
> written upside down from how you'd naturally think: you don't describe what's
> correct, you describe what's *wrong*, then assert that nothing matches.

**`abs(...) > 0.01`** — allow a cent of tolerance. Money is stored to two decimal
places and rounding at each step can leave a hair. **Demanding exact equality
gives you a test that fails randomly, which is worse than no test at all —
people learn to ignore it.**

> 🎓 **This test is worth more than the other thirty-nine combined.** They check
> that columns look sane. This checks that **your headline number is internally
> consistent**. If someone edits the `case` block in `int_order_revenue` six
> months from now and forgets the bridge, every generic test still passes and
> this one fails immediately.

> ⚠️ **It encodes an assumption about structure** — that steps 1–6 sum to step 7.
> Adding steps 8–10 was safe *by luck*. Numbering them 5, 6, 7 would have
> silently broken it. **When a test encodes structure, changing the structure
> needs a look at the test.**

---

### 4.5 — A test that fails on purpose (20 min)

Every test so far has passed. **A green light nobody has ever seen turn red
teaches nothing.**

> **WHERE** VS Code
> **FILE** `tests/assert_order_timestamps_sane.sql`

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

> **TYPE**
> ```powershell
> dbt test --select assert_order_timestamps_sane
> ```
> **EXPECT**
> ```
> 1 of 1 FAIL 100 assert_order_timestamps_sane [FAIL 100 in 1.8s]
> Got 100 results, configured to fail if != 0
> ```

**`--select`** runs one test instead of all forty-one. Useful when iterating.

**What it asserts:** an order cannot be updated before it was created. **That's
not a business rule, it's physics.**

**100 rows — exactly 1 in every 500 orders.** Too regular to be random.

**Look at what failed:**

> **WHERE** Snowflake worksheet
> ```sql
> select
>     order_id, order_status, ordered_at, status_updated_at,
>     datediff('hour', ordered_at, status_updated_at) as hours_difference
> from LUMEN_LOOM.DEV_YOURNAME.STG_ORDERS
> where status_updated_at < ordered_at
> order by hours_difference
> limit 20;
> ```

> **WHY look before deciding:** the size of the gap tells you the cause. A few
> seconds is clock drift between servers. A few *days* is a replayed record.
> You'd handle those differently.

### ❓ ASK — the real question

> **"This will fail on every run, forever, and we cannot fix it. What do you do
> with it?"**

> **FILE** `tests/assert_order_timestamps_sane.sql`
> Add **one line at the very top**, above the `select`:
> ```sql
> {{ config(severity = 'warn') }}
> ```

> **TYPE**
> ```powershell
> dbt test --select assert_order_timestamps_sane
> ```
> **EXPECT** `WARN 100` — and `Done. PASS=0 WARN=1 ERROR=0`. The run now
> completes successfully.

| Severity | Behaviour | Use when |
|---|---|---|
| `error` (default) | Test fails, run fails, pipeline stops | Data is unusable downstream |
| `warn` | Test reports, run continues | Defect is real but tolerable |

**Why `warn` is right here:** those 100 orders still have correct amounts,
statuses and payments. **Your revenue figures are unaffected.** Stopping a
production pipeline — and every dashboard behind it — over a timestamp anomaly
you cannot fix would be the wrong trade.

**Why not just delete the test:** because the *rate* matters. 1 in 500 is
tolerable. If a clock breaks properly next month and it becomes 1 in 5, you want
to know. **The warning is a thermometer.**

> 🎓 **This is the question that separates people who *write* tests from people
> who *own* them.** A test that always fails gets ignored within two weeks — and
> then so does every other red light in the project, including the ones that
> matter. **A permanently failing test is worse than no test**, because it trains
> the team not to look.

> ⚠️ **Say this out loud:** downgrading to `warn` is a decision to be made
> deliberately and recorded. **The failure mode in real teams is downgrading
> tests to make the build green** — and then nobody reads warnings either.

**Run the full suite:**

> **TYPE**
> ```powershell
> dbt test
> ```
> **EXPECT** `Done. PASS=40 WARN=1 ERROR=0 TOTAL=41`

---

### 4.6 — Source freshness (10 min)

> **WHERE** Terminal
> **TYPE**
> ```powershell
> dbt source freshness
> ```
> **EXPECT** All four sources report **`ERROR STALE`**.

**That is correct.** Your data is from 2024 and the thresholds are 36/48 hours.
This is a static teaching sandbox — nothing feeds it.

> ⚠️ **Freshness only runs where a `freshness:` block exists.** Without
> thresholds dbt skips the source entirely — it has no definition of "stale."
> See 1.3.

> 🎓 **This is the failure mode freshness exists to catch, and it's the nastiest
> one in production.** When a source feed dies, **nothing breaks.** Every model
> builds. Every test passes. The dashboards render. They just quietly show last
> Tuesday's numbers, and keep showing them until someone notices the figures
> haven't moved. **Freshness is the only check in your project that would catch
> a pipeline succeeding perfectly at doing nothing.**

---

### 4.7 — Documentation and lineage (15 min)

**Step 1 — build the docs files**

> **TYPE**
> ```powershell
> dbt docs generate
> ```
> **EXPECT** `Catalog written to ...\target\catalog.json`
> **WHY** dbt re-reads every model and asks Snowflake for the actual column
> names and types. It needs the connection because `select *` doesn't tell it
> what columns exist.

**Step 2 — start the viewer**

> **TYPE**
> ```powershell
> dbt docs serve
> ```
> **EXPECT** Your browser opens at `http://localhost:8080`.
> ⚠️ **The terminal will look frozen.** It isn't — the server is holding it.

**Step 3 — the lineage graph**

Bottom-right corner: a small round blue icon with connected dots. **Click it.**

You'll see four green source tables on the left, staging, intermediate, then the
marts. **Drag to move, scroll to zoom.**

**Step 4 — trace a number backwards**

Click `rpt_revenue_bridge` → the **Lineage** tab.

> **Say to the class:** *"Someone asks where the $2.5 million came from. Watch."*
> Then click backwards: bridge → int_order_revenue → stg_payments →
> raw_payments. **Four clicks from a board-level number to a raw column.**

**Step 5 — show what dbt actually sent**

Still on that model, scroll down. Two code blocks:

| Block | Contains |
|---|---|
| **Source** | The SQL you wrote, with `{{ ref(...) }}` still in it |
| **Compiled** | What dbt actually sent to Snowflake, with real table names |

**That comparison is the clearest possible explanation of what dbt does.** You
write the readable version; dbt writes the real one.

**Step 6 — show a test**

Left sidebar → **Tests** → `assert_bridge_balances`. You can read its SQL right
there. **Anyone can audit what "tested" means** — they don't have to take your
word for it.

**Step 7 — stop the server**

Click into the terminal, press **Ctrl+C**.

> **WHY you must** — while the server runs, that terminal accepts nothing else.
> Forget, and `dbt run` appears to do nothing.

> 🎓 **Nobody drew that diagram.** dbt inferred it entirely from your `ref()` and
> `source()` calls. **It cannot go out of date, because it *is* the code.** Show
> students any company's hand-maintained architecture diagram and ask when it
> was last accurate.

> 🎓 **End a class here rather than on the revenue number.** The number is the
> *answer*; the lineage graph is the *argument*. When the CFO asks where $2.5
> million came from, you don't defend it with a spreadsheet — you click through
> seven boxes back to a raw table.

---

### 4.8 — The client deliverable (20 min)

> **WHERE** VS Code
> **FILE** `FINDINGS.md`
> **TYPE**
> ```powershell
> code "FINDINGS.md"
> ```

See the completed version in this repo. The structure:

| Section | Contains |
|---|---|
| Executive summary | The headline number and the two independent findings |
| 1. Revenue bridge | The ten-step table |
| 2.1 – 2.8 | One finding each: number, cause, **recommendation** |
| 3. Method | The three layers, the test count, why the `case` order matters |
| 4. Open items | Every unresolved question, **with an owner's name** |

> 🎓 **Every finding carries a recommendation and an owner. A finding without an
> action is a complaint.** Section 4 exists so the meeting ends with someone's
> name against each item.

> 🎓 **§2.5 says what you *couldn't* do, and why.** That is not a weakness in the
> report — it is the most senior paragraph in it. **It converts your limitation
> into their decision.**

> 🎓 **The report is not written at the end.** Every time you learn something,
> it goes in the document immediately. Otherwise you finish with a working
> pipeline and a vague memory of what it told you. **The analysis is finished
> when the report is.**

---

### 4.9 — Version control (10 min)

> **WHERE** Terminal, inside `lumen_loom/`
> **TYPE**
> ```powershell
> git status
> ```
> **EXPECT** `fatal: not a git repository` — confirming there's nothing to
> conflict with.

> **TYPE**
> ```powershell
> git init -b main
> ```
> **WHY `-b main`** — older git versions default to `master`. GitHub and every
> modern team use `main`. Set it now, avoid renaming later.

> **FILE** `.gitignore`
> ```powershell
> code ".gitignore"
> ```
> ```
> target/
> dbt_packages/
> logs/
> .user.yml
>
> # never commit credentials
> .env
> *.env
> profiles.yml
> ```

| Entry | Why |
|---|---|
| `target/` | Compiled SQL and docs catalog. Regenerated every run |
| `dbt_packages/` | Third-party packages. Downloaded, not authored |
| `logs/` | Run logs. Grow forever, useful to nobody |
| `.user.yml` | A local ID dbt generates per machine |
| `.env`, `profiles.yml` | **Credentials.** The one entry that actually matters |

> **The `profiles.yml` line is belt and braces.** Yours lives safely in
> `~/.dbt/`. But students will copy it into their project folder — everyone does
> — and this line means it doesn't get published when they do.

> **TYPE**
> ```powershell
> git add .
> git status
> ```
> **READ THE LIST BEFORE COMMITTING.**
>
> ✅ You want: `models/`, `tests/`, `dbt_project.yml`, `FINDINGS.md`, `.gitignore`
> ❌ You must not see: anything under `target/`, `logs/`, or ending `.env`

> **TYPE**
> ```powershell
> git commit -m "Engagement 01: revenue leakage pipeline, tests and findings"
> git log --oneline
> ```

> 🎓 **Git remembers everything.** Commit a password once, delete it in the next
> commit, and **it is still in the history for anyone who clones the repo**.
> Bots scan public GitHub for exactly this and find live credentials within
> minutes. **`.gitignore` isn't tidiness — it's the only cheap moment to get
> this right**, because after the commit it is genuinely painful to undo.

**The `LF will be replaced by CRLF` warning is harmless.** Windows ends lines
with two invisible characters, Mac and Linux with one. Git normalises them.

---

### 4.10 — Publish (5 min)

**Scan for credentials in file *contents*, not just filenames:**

> **TYPE**
> ```powershell
> git ls-files | Select-String -Pattern "env|profiles|target"
> ```
> **EXPECT** Nothing.

> ⚠️ **A filename scan is not enough.** A file called `config.yml` looks harmless
> and can still contain a password on line 4. Also grep the contents for your
> account identifier and username.

**With the GitHub CLI:**

> **TYPE**
> ```powershell
> gh repo create aef-01-ecommerce-revenue-leakage --public --source=. --push
> ```

**Without it** — create an empty repo on github.com (no README, no `.gitignore`
— you already have both), then:

> ```powershell
> git remote add origin https://github.com/YOUR-USERNAME/aef-01-ecommerce-revenue-leakage.git
> git push -u origin main
> ```

> 🎓 **This repo *is* the submission.** The thing you hand in isn't a document
> *about* the work — it's the work, with its history. A reviewer can clone it,
> read `FINDINGS.md`, click into the exact model that produced each number, and
> run `dbt test` to confirm the claims hold. **That's why the commit messages
> and the `.gitignore` matter as much as the SQL.**

---

# Appendix A — Complete file map

```
lumen_loom/
├── .gitignore
├── dbt_project.yml                                  0.16
├── README.md
├── FINDINGS.md                                      4.8
├── TEACHING-GUIDE.md
├── models/
│   ├── staging/
│   │   ├── sources.yml                              1.3
│   │   ├── schema.yml                               4.3
│   │   ├── stg_orders.sql                           1.4
│   │   ├── stg_payments.sql                         1.5
│   │   ├── stg_refunds.sql                          1.5
│   │   └── stg_shipping.sql                         1.5
│   ├── intermediate/
│   │   ├── schema.yml                               4.3
│   │   ├── int_payments_deduplicated.sql            2.2
│   │   └── int_order_revenue.sql                    3.3
│   └── marts/
│       ├── schema.yml                               4.3
│       ├── rpt_revenue_bridge.sql                   3.5
│       ├── rpt_revenue_bridge_by_currency.sql       3.6
│       ├── rpt_revenue_by_month.sql                 4.1
│       └── rpt_payment_attempts.sql                 4.2
└── tests/
    ├── assert_bridge_balances.sql                   4.4
    └── assert_order_timestamps_sane.sql             4.5

~/.dbt/profiles.yml                                  0.15   (never committed)
```

**Build order dbt works out for itself:**

```
raw_orders   ──► stg_orders   ──┐
raw_payments ──► stg_payments ──┼──► int_payments_deduplicated ──┐
raw_refunds  ──► stg_refunds  ──┤                                │
raw_shipping ──► stg_shipping ──┴──► int_order_revenue ◄─────────┘
                                            │
                                            ├──► rpt_revenue_bridge
                                            ├──► rpt_revenue_bridge_by_currency
                                            ├──► rpt_revenue_by_month
                                            └──► rpt_payment_attempts
```

---

# Appendix B — Every command in order

### Terminal — setup (once)

```powershell
python --version
git --version
python -m pip install --upgrade pip
pip install dbt-snowflake
dbt --version
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path","User") + ";$env:APPDATA\Python\Python314\Scripts", "User")
pip install -r "C:\path\to\data_generator\requirements.txt"
python "C:\path\to\data_generator\generate_data.py" --orders 50000 --seed 42 --dry-run
python "C:\path\to\data_generator\generate_data.py" --orders 50000 --seed 42
cd "C:\Users\YOU\Documents\Ecommerce Revenue Leakage Project"
dbt init lumen_loom --skip-profile-setup
cd lumen_loom
Remove-Item -Recurse -Force "models\example"
New-Item -ItemType Directory -Force "models\staging","models\intermediate","models\marts"
New-Item -ItemType Directory -Force "$env:USERPROFILE\.dbt"
code "$env:USERPROFILE\.dbt\profiles.yml"
code "dbt_project.yml"
dbt debug
```

### Terminal — every session start

```powershell
cd "C:\Users\YOU\Documents\Ecommerce Revenue Leakage Project\lumen_loom"
$env:SNOWFLAKE_ACCOUNT="your-org-your-account"
$env:SNOWFLAKE_USER="YOUR_USERNAME"
$env:SNOWFLAKE_ROLE="ACCOUNTADMIN"
$env:SNOWFLAKE_WAREHOUSE="COMPUTE_WH"
$env:SNOWFLAKE_DATABASE="LUMEN_LOOM"
$env:SNOWFLAKE_SCHEMA="RAW"
$s = Read-Host "Password" -AsSecureString
$env:SNOWFLAKE_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
dbt debug
```

### Terminal — creating each file

```powershell
code "models\staging\sources.yml"
code "models\staging\stg_orders.sql"
code "models\staging\stg_payments.sql"
code "models\staging\stg_refunds.sql"
code "models\staging\stg_shipping.sql"
code "models\intermediate\int_payments_deduplicated.sql"
code "models\intermediate\int_order_revenue.sql"
code "models\marts\rpt_revenue_bridge.sql"
code "models\marts\rpt_revenue_bridge_by_currency.sql"
code "models\marts\rpt_revenue_by_month.sql"
code "models\marts\rpt_payment_attempts.sql"
code "models\staging\schema.yml"
code "models\intermediate\schema.yml"
code "models\marts\schema.yml"
code "tests\assert_bridge_balances.sql"
code "tests\assert_order_timestamps_sane.sql"
code "FINDINGS.md"
code ".gitignore"
```

### Terminal — dbt

```powershell
dbt debug                                   # test the connection
dbt run                                     # build everything
dbt run --select rpt_revenue_bridge         # build one model
dbt test                                    # run all tests
dbt test --select assert_bridge_balances    # run one test
dbt source freshness                        # check the feeds are current
dbt docs generate                           # build the docs
dbt docs serve                              # view them (Ctrl+C to stop)
```

### Terminal — git

```powershell
git init -b main
git add .
git status
git commit -m "Engagement 01: revenue leakage pipeline, tests and findings"
git log --oneline
gh repo create aef-01-ecommerce-revenue-leakage --public --source=. --push
```

### Snowflake — every query, in order

| Step | Purpose |
|---|---|
| 0.6 | `CREATE DATABASE` / `CREATE SCHEMA` ×2 |
| 0.6 | `SHOW SCHEMAS IN DATABASE LUMEN_LOOM;` `SHOW WAREHOUSES;` |
| 0.12 | Row counts across the four raw tables (`UNION ALL`) |
| 0.13 | `DATE_PART('year', created_at)` — timestamp sanity |
| 1.1 | `SELECT * FROM RAW_ORDERS LIMIT 20;` |
| 1.1 | `DESCRIBE TABLE` ×4 |
| 1.2 | Order status breakdown — **the framing question** |
| 1.4 | `SELECT * FROM STG_ORDERS LIMIT 10;` |
| 2.1 | Duplicate payment detection |
| 2.2 | before/after dedup counts — must differ by 642 |
| 2.3 | Orders joined to deduped payments by status |
| 2.4 | Charged vs refunded vs still held |
| 3.1 | Shipping grain check |
| 3.2 | Shipping evidence — the four `count()`s |
| 3.4 | Revenue category breakdown (run **twice** — before and after the fix) |
| 3.5 | `SELECT * FROM RPT_REVENUE_BRIDGE ORDER BY step;` |
| 3.6 | Revenue by currency |
| 3.6 | `SELECT * FROM RPT_REVENUE_BRIDGE_BY_CURRENCY;` |
| 4.1 | `SELECT * FROM RPT_REVENUE_BY_MONTH ORDER BY month;` |
| 4.2 | `SELECT * FROM RPT_PAYMENT_ATTEMPTS ORDER BY orders DESC;` |
| 4.5 | The 100 clock-skew rows |

---

# Appendix C — Known traps

Things that will cost you class time if you meet them unprepared.

### The generator writes broken timestamps

**Every date lands around the year 54 billion and the load reports success.**
Row counts match. Models build. Tests pass.

```python
success, _, nrows, _ = write_pandas(
    conn, df, name, quote_identifiers=False, auto_create_table=False,
    use_logical_type=True
)
```

Without `use_logical_type=True`, timestamps go to Parquet with no unit
information and Snowflake misinterprets them. **Fix it before class** (0.7).

### `dbt is not recognized`

The install worked; Windows can't find the program. See 0.4. **A new terminal
tab is not enough** — VS Code caches the environment at application start.

### `metadata-generation-failed` when installing dbt

Old pip, or a dropped network connection. Run
`python -m pip install --upgrade pip` first (0.3).

### `getaddrinfo failed`

DNS or network dropout. Usually resolves on retry.

### `TypeError: argument of type 'NoneType' is not a container`

YAML indentation in `profiles.yml`. `outputs:` at 2 spaces, `dev:` at 4, its
settings at 6. Select `dev:` and everything below, press **Tab**. See 0.15.

### `Unexpected token 'USER'`

A space inside a variable name — `$env:SNOWFLAKE_ USER`. **Read the character
just *before* the `~~~~` squiggle**, not the squiggle itself.

### `ROWS` is a reserved word

`COUNT(*) AS rows` fails in Snowflake. **Rename to `row_count`** rather than
quoting `"ROWS"` — quoting also locks the capitalisation and causes join
failures later.

### `ConvertFrom-SecureString: parameter 'AsPlainText' not found`

You're on Windows PowerShell 5.1; that flag is PowerShell 7 only. Use the
two-line `[Runtime.InteropServices.Marshal]` version in 0.10.

### `Object 'INT_...' does not exist`

Either you haven't run `dbt run` since creating the model, or `intermediate` is
still set to `ephemeral` in `dbt_project.yml` — ephemeral models build nothing.

### Snowflake Copilot rewrites your worksheet

It will offer to create dbt-managed objects by hand, and its version may differ
subtly from yours — e.g. `ORDER BY processed_at DESC` keeps the *duplicate*
webhook rather than the original payment, with **the same row count**.

**Disable it before class.** The rule: **if dbt builds it, you never touch it by
hand.** Worksheets are for *looking*, not *building*.

> 🎓 Two queries, identical row counts, different data. **Counting rows is not
> verification.**

### Environment variables die with the terminal

Every new session needs them re-set. That is the correct trade-off for keeping
passwords off disk. **Tell students on day one** so it isn't mistaken for a bug.

### The Pydantic warning

```
UserWarning: Core Pydantic V1 functionality isn't compatible with Python 3.14
```

Cosmetic. Silence with `$env:PYTHONWARNINGS = "ignore"`.

> 🎓 **Teach the difference between a warning and an error.** A warning means
> "this ran fine, but heads up." An error means "this did not run." **The tell
> is what comes *after*** — here, the version report still printed.

---

# Timing at a glance

| Session | Content | Builds | Running total |
|---|---|---|---|
| 0 | Setup, Snowflake, data load | — | — |
| 1 | Raw data, staging layer | 4 models | 4 |
| 2 | Duplicates, dedup, cancelled/placed charges | +1 model | 5 |
| 3 | Grain, shipping, classification, bridge, currency | +3 models | 8 |
| 4 | Monthly timing, attempts, tests, docs, git | +2 models, 41 tests | 10 |

**Final: 10 models · 41 tests · 8 findings · 1 client memo · published repo**
