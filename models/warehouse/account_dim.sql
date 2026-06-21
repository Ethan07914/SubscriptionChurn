{{
    config(
        materialized='table')
}}

SELECT
    account_id,
    account_name,
    industry,
    country,
    signup_date,
    referral_source,
    plan_tier,
    number_of_seats,
    is_trial,
    churn_flag
FROM
    {{ ref('stg_bigquery__accounts') }}