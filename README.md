

```bash
pip install dbt-bigquery
```

## Raw Schema (`subscriptionchurn.raw`)

Entity-relationship diagram generated from the DDL in [`documentation/raw_tables.csv`](./documentation/raw_tables.csv).

```mermaid
erDiagram
    accounts ||--o{ subscriptions : "has"
    accounts ||--o{ support_tickets : "has"
    accounts ||--o{ churn_events : "has"
    subscriptions ||--o{ feature_usage : "has"

    accounts {
        STRING account_id PK
        STRING account_name
        STRING industry
        STRING country
        DATE signup_date
        STRING referral_source
        STRING plan_tier
        INT64 seats
        BOOL is_trial
        BOOL churn_flag
    }

    subscriptions {
        STRING subscription_id PK
        STRING account_id FK
        DATE start_date
        DATE end_date
        STRING plan_tier
        INT64 seats
        INT64 mrr_amount
        INT64 arr_amount
        BOOL is_trial
        BOOL upgrade_flag
        BOOL downgrade_flag
        BOOL churn_flag
        STRING billing_frequency
        BOOL auto_renew_flag
    }

    feature_usage {
        STRING usage_id PK
        STRING subscription_id FK
        DATE usage_date
        STRING feature_name
        INT64 usage_count
        INT64 usage_duration_secs
        INT64 error_count
        BOOL is_beta_feature
    }

    support_tickets {
        STRING ticket_id PK
        STRING account_id FK
        DATE submitted_at
        TIMESTAMP closed_at
        FLOAT64 resolution_time_hours
        STRING priority
        INT64 first_response_time_minutes
        FLOAT64 satisfaction_score
        BOOL escalation_flag
    }

    churn_events {
        STRING churn_event_id PK
        STRING account_id FK
        DATE churn_date
        STRING reason_code
        FLOAT64 refund_amount_usd
        BOOL preceding_upgrade_flag
        BOOL preceding_downgrade_flag
        BOOL is_reactivation
        STRING feedback_text
    }
```