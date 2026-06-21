{{
    config(
        materialized='table')
}}

SELECT
    subscription_feature_usage_pk,
    subscription_id,
    account_id,
    feature_fk,
    feature_name,
    plan_tier,
    is_trial,
    upgrade_flag,
    downgrade_flag,
    churn_flag,
    billing_frequency,
    auto_renew_flag,
    total_usage_count,
    total_usage_duration_secs,
    total_error_count
FROM
    {{ ref('int_aggregated__subscription_feature_usage') }}