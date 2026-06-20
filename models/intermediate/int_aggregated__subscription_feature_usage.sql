{{
    config(
        materialized='ephemeral')
}}

WITH joined as (
SELECT
    s.subscription_id,
    s.account_id,
    s.start_date,
    s.end_date,
    s.plan_tier,
    s.number_of_seats,
    s.mrr_amount,
    s.arr_amount,
    s.is_trial,
    s.upgrade_flag,
    s.downgrade_flag,
    s.churn_flag,
    s.billing_frequency,
    s.auto_renew_flag,
    fu.feature_name,
    f.feature_pk as feature_fk,
    fu.usage_count,
    fu.usage_duration_secs,
    fu.error_count
FROM
    {{ ref('stg_bigquery__subscriptions') }} as s
    INNER JOIN {{ ref('stg_bigquery__feature_usage')}} as fu
    ON s.subscription_id = fu.subscription_id
    INNER JOIN {{ ref('int_enriched__features') }} as f
    ON fu.feature_name = f.feature_name)

, aggregated as (
SELECT
    subscription_id,
    account_id,
    feature_fk,
    feature_name,
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
    auto_renew_flag,
    sum(usage_count) as total_usage_count,
    sum(usage_duration_secs) as total_usage_duration_secs,
    sum(error_count) as total_error_count
FROM
    joined
GROUP BY
    subscription_id,
    account_id,
    feature_fk,
    feature_name,
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
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['subscription_id', 'feature_fk']) }} as subscription_feature_usage_pk,
    *
FROM
    aggregated