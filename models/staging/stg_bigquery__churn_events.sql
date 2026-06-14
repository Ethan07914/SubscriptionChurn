{{
config(
    materialized='view')
}}

SELECT
    churn_event_id,
    account_id,
    churn_date,
    reason_code,
    refund_amount_usd,
    preceding_upgrade_flag,
    preceding_downgrade_flag,
    is_reactivation,
    feedback_text
FROM
    {{ source('raw_subscription', 'churn_events') }}