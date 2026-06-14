{{
config(
    materialized='view')
}}

SELECT
    subscription_id,
    account_id,
    start_date,
    end_date,
    plan_tier,
    seats as number_of_seats,
    mrr_amount,
    arr_amount,
    is_trial,
    upgrade_flag,
    downgrade_flag,
    churn_flag,
    billing_frequency,
    auto_renew_flag
FROM
    {{ source('raw_subscription', 'subscriptions') }}