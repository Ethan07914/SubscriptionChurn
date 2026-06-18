{{
    config(
        materialized='ephemeral')
}}

WITH accounts as (
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
),

subscriptions as (
    SELECT
         subscription_id,
         account_id,
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
),

joined as (
    SELECT
         a.account_id,
         s.subscription_id,
         a.account_name,
         a.industry,
         a.country,
         a.signup_date as account_signup_date,
         a.referral_source,
         s.plan_tier,
         s.number_of_seats,
         s.is_trial,
         s.churn_flag,
         s.start_date as subscription_start_date,
         s.end_date as subscription_end_date,
         s.mrr_amount,
         s.arr_amount,
         s.upgrade_flag,
         s.downgrade_flag,
         s.billing_frequency,
         s.auto_renew_flag
    FROM
         accounts as a
         left join subscriptions as s
         on a.account_id = s.account_id)

SELECT
    {{ dbt_utils.generate_surrogate_key(['account_id', 'subscription_id']) }} as account_subscription_pk,
    *
FROM
    joined