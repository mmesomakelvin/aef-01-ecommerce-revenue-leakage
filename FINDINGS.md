# Lumen & Loom — Revenue Leakage Review

**Prepared for:** Finance & Operations
**Period reviewed:** 1 January – 31 December 2024
**Source systems:** Order platform, payment gateway, refunds ledger, carrier feed

---

## Executive summary

Reported revenue for 2024 overstates defensible revenue by **$407,940 — 13.9%**.

Separately, and independently of the above: **monthly revenue reporting is
unreliable in every month of the year**, while the annual total reconciles
correctly. This is why the issue has not previously been detected.

| | Amount |
|---|---|
| Revenue per payment gateway | $2,940,566 |
| Defensible revenue | **$2,532,626** |
| **Overstatement** | **$407,940 (13.9%)** |

---

## 1. Revenue bridge

| Step | Line item | Amount |
|---|---|---|
| 1 | Gateway total: all successful payments | 2,940,565.58 |
| 2 | Less: duplicate payment webhooks | (41,396.82) |
| 3 | Less: cancelled orders that were charged | (131,272.28) |
| 4 | Less: placed orders that were charged | (66,728.17) |
| 5 | Less: charged with no shipping evidence | 0.00 |
| 6 | Less: refunds on recognised orders | (168,542.64) |
| 7 | **Defensible revenue** | **2,532,625.67** |

---

## 2. Findings

### 2.1 Duplicate payment records — $41,397

The payment gateway logged 642 settled payments twice. Each affected order has
exactly one extra record — a consistent technical fault, not random error.
Any process summing the payments table without deduplication overstates
revenue by this amount.

**Recommendation:** deduplicate on order at ingestion. Raise with the gateway
provider — duplicate webhook delivery should be idempotent.

### 2.2 Cancelled orders that were charged — $131,272 collected, $44,428 never returned

2,024 cancelled orders were charged — **45% of all cancellations**. Of the
money taken, 66% was refunded; **$44,428 was not**.

The consistency of the 45% figure indicates a systemic gap between the
cancellation workflow and the payment gateway, not isolated error.

**Recommendation:** reconcile cancellations against settled payments daily.
Refund the outstanding balance.

### 2.3 Orders charged but never progressed — $66,728 collected, $62,278 never returned

980 orders in `placed` status were charged — **25% of all placed orders**.
Only 6.7% of that money was returned, which matches the ordinary returns rate
for delivered goods. **No cancellation-driven refunds are occurring on these
orders at all.**

These customers have been charged for orders that never moved and are unlikely
to be aware of it. This carries consumer-protection and chargeback exposure
beyond the accounting impact.

**Recommendation:** treat as urgent. Identify affected customers, refund, and
add an alert for any charged order that remains in `placed` beyond 48 hours.

### 2.4 Monthly reporting is materially distorted

Refunds are recorded in the month they are processed, not the month of the
original sale. Approximately half of all refunds cross a month boundary.

**Every month of 2024 is misstated. The annual total is correct.** The
distortions net to exactly zero across the year, which is why year-end
reconciliation has never surfaced the problem.

| Month | Net as reported | Net matched to sale | Distortion |
|---|---|---|---|
| Jan 2024 | 219,019 | 211,857 | **(7,163)** overstated |
| Oct 2024 | 217,158 | 219,052 | 1,894 understated |
| Nov 2024 | 208,628 | 209,886 | 1,258 understated |
| Jan 2025 | **(4,825)** | 0 | 4,825 |
| Feb 2025 | **(1,411)** | 0 | 1,411 |

Two consequences:

- **January is structurally overstated by $7,163.** The first period of any
  reporting window absorbs no prior-period refunds while exporting its own.
- **$6,236 of 2024 refunds land in 2025**, producing two months of negative
  reported revenue in a period with no offsetting sales.

Any decision made on monthly figures — marketing ROI, commissions, forecast
accuracy, month-on-month growth — rests on numbers that are individually
wrong.

**Recommendation:** report refunds against the month of the original sale.
Retain the cash-basis view separately for treasury purposes.

### 2.5 Multi-currency revenue cannot be consolidated

Revenue is recorded in three currencies with **no exchange-rate table present
in any source system**.

| Currency | Recognised |
|---|---|
| USD | 1,823,001 |
| GBP | 357,981 |
| EUR | 351,643 |

**28% of revenue is non-USD.** The consolidated figure of $2,532,626 is a sum
of three different units and is not a valid monetary amount.

Leakage is uniform across currencies — 14.0% USD, 13.7% GBP, 13.5% EUR.
This rules out regional process variation and points to a defect in shared
platform infrastructure rather than local operations.

We have deliberately not applied a conversion. The choice of rate —
transaction date, month-end, or internal hedged rate — is a finance policy
decision that materially changes the result.

**Recommendation:** provide a rate table and confirm the applicable
convention. We will restate on receipt.

### 2.7 Payment processing costs

Processing fees on recognised revenue total **$90,791** (3.6%).
Revenue net of payment costs is **$2,441,835**.

Separately, **$6,643 in processing fees was paid on charges that should never
have been taken** — the 3,004 cancelled and placed orders in §2.2 and §2.3.
Processing fees are generally not returned on refund, so this represents an
actual cash loss rather than an accounting adjustment.

A further ~$4,900 in fees was paid on legitimate refunds. This is an ordinary
cost of trading but is not currently tracked anywhere.

**Recommendation:** fixing the charging defects in §2.2 and §2.3 recovers
approximately $6,600 per year in fees alone, independent of the revenue
correction.

### 2.6 Data quality — carrier feed

- **640 orders record a delivery date but no shipment date.** Physically
  impossible; indicates a defect in the carrier integration. Revenue is
  unaffected — delivery is accepted as evidence of shipment — but the feed
  is unreliable for any operational analysis.
- **1,719 charged, cancelled orders have no record in the shipping system.**
  Correct behaviour for fulfilment; the fault is that they were charged.
- **5,470 orders were never charged at all** and are excluded throughout.

---

## 3. Method

Built as a dbt project on Snowflake, in three layers:

### 2.6 Data quality — carrier feed

- **640 orders record a delivery date but no shipment date.** Physically
  impossible; indicates a defect in the carrier integration. Revenue is
  unaffected — delivery is accepted as evidence of shipment — but the feed
  is unreliable for any operational analysis.
- **1,719 charged, cancelled orders have no record in the shipping system.**
  Correct behaviour for fulfilment; the fault is that they were charged.
- **5,470 orders were never charged at all** and are excluded throughout.

---

## 3. Method

Built as a dbt project on Snowflake, in three layers:

- **staging** — one model per source table; renaming and type handling only
- **intermediate** — deduplication, then a single revenue verdict per order
- **marts** — the revenue bridge and the monthly recognition view

Every order receives exactly one classification, so no amount is counted
twice and the categories sum to the total.

**18 automated tests** cover uniqueness, completeness, referential integrity,
permitted status values, and the arithmetic integrity of the bridge itself.

---

## 4. Open items

| Item | Owner |
|---|---|
| Exchange-rate table and conversion convention | Finance |
| Confirm treatment of `confirmed` (paid, not yet delivered) orders | Finance |
| Carrier integration defect — delivery without shipment | Engineering |
| Duplicate webhook delivery | Payments provider |