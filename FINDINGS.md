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
| Revenue net of payment processing costs | $2,441,835 |

Three findings carry a cash impact rather than an accounting one:

- **$106,706** collected on cancelled or never-progressed orders and never returned
- **$6,643** in processing fees paid on charges that should not have been taken
- **$34,120** of orders where every payment attempt failed and the customer stopped

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
| 8 | Less: payment processing fees on recognised revenue | (90,790.54) |
| 9 | **Revenue net of payment processing costs** | **2,441,835.13** |
| 10 | Memo: fees paid on revenue never recognised (sunk) | (6,643.44) |

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

| Currency | Recognised | Overstatement rate |
|---|---|---|
| USD | 1,823,001 | 14.0% |
| GBP | 357,981 | 13.7% |
| EUR | 351,643 | 13.5% |

**28% of revenue is non-USD.** The consolidated figure of $2,532,626 is a sum
of three different units and is not a valid monetary amount.

Leakage is uniform across currencies. This rules out regional process variation
and points to a defect in shared platform infrastructure rather than local
operations — meaning a single fix addresses all three markets.

We have deliberately not applied a conversion. The choice of rate —
transaction date, month-end, or internal hedged rate — is a finance policy
decision that materially changes the result.

**Recommendation:** provide a rate table and confirm the applicable
convention. We will restate on receipt.

### 2.6 Payment processing costs

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

### 2.7 Failed payment attempts — $34,120 of demand never collected

The gateway records every payment attempt, including failures and retries.
Across 50,000 orders:

| Outcome | Orders | Failed attempts | Order value |
|---|---|---|---|
| Paid on first attempt | 40,016 | 0 | 2,606,512 |
| No payment attempted | 4,947 | 0 | 325,202 |
| Paid after one or more retries | 4,514 | 5,819 | 292,657 |
| **Every attempt failed** | **523** | **665** | **34,120** |

**5,037 orders encountered at least one payment failure. 4,514 eventually
succeeded — an 89.6% recovery rate. The remaining 523 orders, worth $34,120,
were never collected.**

This is demand that reached checkout and produced nothing. It is not
straightforwardly lost revenue — some customers will have reordered
successfully — but it is currently unmeasured and unmonitored.

The retry pattern is also worth attention: orders that eventually succeeded
averaged 2.31 attempts, indicating the failures are transient rather than
hard declines.

**Recommendation:** monitor the failure recovery rate as an operational
metric. Investigate whether the 523 non-recovered orders share a payment
method, currency or issuing region.

### 2.8 Data quality defects

- **640 orders record a delivery date but no shipment date.** Physically
  impossible; indicates a defect in the carrier integration. Revenue is
  unaffected — delivery is accepted as evidence of shipment — but the feed
  is unreliable for any operational analysis.
- **100 orders (1 in 500) record an update timestamp earlier than their
  creation timestamp.** Indicates clock drift or record replay in the order
  platform. Revenue is unaffected. Monitored as a warning rather than a
  blocking error; escalate if the rate increases.
- **1,719 charged, cancelled orders have no record in the shipping system.**
  Correct behaviour for fulfilment; the fault is that they were charged.
- **5,470 orders were never charged at all** and are excluded throughout.
  This figure reconciles exactly against the payment attempt analysis in §2.7
  (4,947 with no attempt + 523 where all attempts failed).

---

## 3. Method

Built as a dbt project on Snowflake, in three layers:

- **staging** (4 models) — one per source table; renaming and type handling
  only, no filtering and no business logic
- **intermediate** (2 models) — deduplication, then a single revenue verdict
  per order
- **marts** (4 models) — the revenue bridge, the per-currency bridge, the
  monthly recognition view, and the payment attempt analysis

Every order receives exactly one classification, so no amount is counted
twice and the categories sum to the total. The order of conditions determining
that classification is the revenue recognition policy expressed in SQL;
changing it changes the reported figure, and it should be owned by Finance.

**41 automated tests** cover uniqueness, completeness, referential integrity,
permitted status values, and the arithmetic integrity of the bridge itself.
One test reports as a warning by design (§2.8, clock skew) — a defect that is
real, tolerable, and outside our control to fix.

Source freshness thresholds are configured on all four feeds. Note that in a
live deployment these would alert when a feed stops delivering — the failure
mode in which every model builds successfully and every dashboard silently
shows stale figures.

---

## 4. Open items

| Item | Owner |
|---|---|
| Exchange-rate table and conversion convention | Finance |
| Confirm treatment of `confirmed` (paid, not yet delivered) orders | Finance |
| Carrier integration defect — delivery without shipment | Engineering |
| Order platform clock drift — update before creation | Engineering |
| Duplicate webhook delivery | Payments provider |
| Investigate the 523 non-recovered payment failures | Payments provider |
