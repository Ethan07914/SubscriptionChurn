{{
    config(
        materialized='table')
}}

WITH source as (
SELECT
    account_id,
    subscription_id,
    account_name,
    industry,
    country,
    account_signup_date,
    referral_source,
    plan_tier,
    number_of_seats,
    is_trial,
    churn_flag,
    subscription_start_date,
    subscription_end_date,
    DATE_DIFF(coalesce(subscription_end_date, current_date()), subscription_start_date, MONTH) as total_months_subscribed,
    mrr_amount,
    arr_amount,
    upgrade_flag,
    downgrade_flag,
    billing_frequency,
    auto_renew_flag
FROM
    {{ ref('int_joined__subscription_accounts') }})

, metrics as (
SELECT
    *,
    mrr_amount * total_months_subscribed as lifetime_value,
    CASE
        WHEN subscription_end_date IS NOT NULL THEN DATE_DIFF(subscription_end_date, subscription_start_date, DAY)
        ELSE NULL
    END AS time_to_churn_days
FROM
    source)

SELECT
    *
FROM
    metrics