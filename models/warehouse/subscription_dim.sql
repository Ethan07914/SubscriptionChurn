{{
config(
    materialized='table')
}}

SELECT
    subscription_id,
    start_date,
    end_date,
    plan_tier,
    number_of_seats,
    mrr_amount,
    arr_amount,
    is_trial,
    upgrade_flag,
    downgrade_flag,
    churn_flag,
    billing_frequency,
    auto_renew_flag
FROM
    {{ ref('stg_bigquery__subscriptions') }}