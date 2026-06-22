# subscription_churn

## Subscription KPIs & what this data can track

The metrics below are the standard SaaS scorecard. The **Status** column reflects what is
actually derivable from the five raw tables:

- ✅ **Trackable** — computable directly from the raw columns.
- ⚠️ **Partial / proxy** — approximable, but missing an input so it's a revenue-only proxy or
  a best-effort estimate.
- ❌ **Not trackable** — requires data we don't have (mainly **marketing/sales spend** and
  **payment/billing event logs**).

### 1. Revenue & Growth

| KPI | What it measures | Status | How / source |
|-----|------------------|--------|--------------|
| **MRR** (Monthly Recurring Revenue) | Predictable monthly revenue from active subs | ✅ | `SUM(subscriptions.mrr_amount)` for active subs (`end_date IS NULL`, `churn_flag = false`) |
| **ARR** (Annual Recurring Revenue) | MRR × 12; valuation headline | ✅ | `subscriptions.arr_amount`, or MRR × 12 |
| **ARPU** (Avg Revenue Per User) | Revenue ÷ active accounts; pricing power | ✅ | MRR ÷ count of active accounts; segment by `plan_tier` / `industry` |

### 2. Retention & Churn (the "leaky bucket")

| KPI | What it measures | Status | How / source |
|-----|------------------|--------|--------------|
| **Logo Churn** | % of customers who cancel in a period | ✅ | `churn_events` / `accounts.churn_flag` / `subscriptions.end_date` over the active base |
| **Revenue Churn** | % of MRR lost to cancels + downgrades | ✅ | MRR of churned subs + MRR delta on `downgrade_flag` subs |
| **NRR** (Net Revenue Retention) | Cohort revenue growth incl. upsell − churn; >100% is the goal | ⚠️ | Approximate via `upgrade_flag` / `downgrade_flag` + MRR deltas. No explicit "expansion MRR" event, so this is an estimate, not exact |

### 3. Customer Economics

| KPI | What it measures | Status | How / source |
|-----|------------------|--------|--------------|
| **CAC** (Customer Acquisition Cost) | Spend to acquire one customer | ❌ | **No marketing/sales spend in the data.** `referral_source` gives the *channel* but not its *cost* |
| **LTV / CLV** | Lifetime value of a customer | ⚠️ | Revenue-LTV only: `ARPU × avg lifetime` (lifetime from `start_date`→`end_date`/`churn_date`). No COGS/margin, so it's gross revenue, not profit |
| **LTV : CAC Ratio** | Health ratio (target ≈ 3:1) | ❌ | Needs CAC |
| **Payback Period** | Months of subscription to recoup CAC | ❌ | Needs CAC |

### 4. Billing & Operational Efficiency

| KPI | What it measures | Status | How / source |
|-----|------------------|--------|--------------|
| **Involuntary Churn Rate** | Churn from failed/expired payments (not intent) | ⚠️ | Segment `churn_events.reason_code` for payment/billing reasons; `auto_renew_flag` adds context. No true payment-failure log |
| **Dunning Success Rate** | % of failed payments recovered via retries/emails | ❌ | **No payment-retry / failed-payment events** in the data |
| **Trial Conversion Rate** | % of trials that become paying customers | ✅ | `is_trial` → paid transition across `accounts` / `subscriptions` |

> **To unlock the ❌ rows** you'd add two sources the dataset lacks: a **marketing/finance
> spend** table (cost by channel/period → CAC, LTV:CAC, payback) and a **billing/payment-event**
> log (charges, failures, retries → dunning, true involuntary churn).

---

## Analyses to build & questions to answer

Four analytical themes the data supports — each with the metrics to model and the business
questions they unlock.

### 1. Revenue & MRR dynamics (the holy grail)

Don't track total revenue — track how **MRR moves** month-over-month. The standard dbt pattern
is an **MRR log / MRR bridge** table capturing state changes:

- **New MRR** — revenue from brand-new account signups.
- **Expansion MRR** — existing accounts adding seats or upgrading plan tiers.
- **Contraction MRR** — existing accounts dropping seats or downgrading.
- **Churned MRR** — revenue lost from cancelled accounts.
- **NRR** = `(Starting MRR + Expansion − Contraction − Churn) / Starting MRR` (aim for **>100%**).

*Questions:* What is NRR by `plan_tier` and `industry`? Are accounts on annual vs. monthly
`billing_frequency` less likely to downgrade?

### 2. Customer retention & churn analytics

- **Logo churn rate** — % of accounts lost over a period.
- **Customer LTV** — revenue a customer generates before churning.
- **Time-to-churn (cohorts)** — average duration from `signup_date` to `churn_date`.

*Questions:* Which `reason_code` values drive the most churn, and do they correlate with a
`plan_tier`? Do `preceding_upgrade_flag` / `preceding_downgrade_flag` act as leading indicators of
churn? How effective are reactivations (`is_reactivation`), and what is a reactivated account's LTV?

### 3. Product-led growth (PLG) & engagement

Revenue and churn are *lagging* indicators; `feature_usage` gives the **leading** ones.

- **DAU/WAU proxy** — distinct usage days per `account_id` / `subscription_id`.
- **Feature adoption rate** — % of accounts using a given `feature_name`.
- **Error rate ratio** — `error_count / usage_count`.

*Questions:* Is there an **"aha!" threshold** of `usage_count` / `usage_duration_secs` in the first
30 days after `signup_date` that sharply reduces churn? Does heavy `is_beta_feature` use correlate
with higher CSAT or more upgrades (`upgrade_flag`)?

### 4. Customer support health

- **MTTR** — mean of `resolution_time_hours`.
- **First response time** — mean of `first_response_time_minutes`.
- **CSAT** — mean of `satisfaction_score`.

*Questions:* What's the frustration tipping point — e.g. do accounts with avg CSAT < 3.0 or >2
`escalation_flag`s churn within 60 days? Do certain industries / plan tiers file a
disproportionate share of high-`priority` tickets?

---

## Proposed dbt build-out

Layer the work rather than writing one giant query. Mapped to this project's conventions
(`warehouse/` is the marts layer; staging models use the `stg_bigquery__` prefix):

```
models/
├── staging/                            # views — clean/rename/cast, no joins
│   ├── stg_bigquery__accounts.sql
│   ├── stg_bigquery__subscriptions.sql
│   ├── stg_bigquery__feature_usage.sql
│   ├── stg_bigquery__support_tickets.sql
│   └── stg_bigquery__churn_events.sql
├── intermediate/                       # ephemeral — heavy lifting
│   ├── int_mrr_movements_monthly.sql   # MoM new/expansion/contraction/churned MRR
│   └── int_account_health_metrics.sql  # tickets + usage joined per account
└── warehouse/                          # tables — analytics-ready marts (BI-facing)
    ├── fct_mrr_movements.sql           # fact table for MRR waterfalls / NRR
    ├── dim_accounts.sql                # account-level: total tickets, lifetime spend, status
    └── fct_usage_daily.sql            # cleaned daily product-usage metrics
```

> **Pro-tip — snapshots:** SaaS dimensions *mutate* rather than append (e.g. `plan_tier` changing
> Gold → Platinum). Use **dbt snapshots** on `subscriptions` / `accounts` to capture that history
> over time — a good way to practice slowly-changing-dimension tracking.



