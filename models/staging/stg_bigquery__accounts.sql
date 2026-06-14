{{
config(
    materialized='view')
}}

SELECT
    account_id,
    account_name,
    industry,
    country,
    signup_date,
    referral_source,
    plan_tier,
    seats as number_of_seats,
    is_trial,
    churn_flag
FROM
    {{ source('raw_subscription', 'accounts') }}