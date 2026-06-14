{{
config(
    materialized='view')
}}

SELECT
    {{ dbt_utils.generate_surrogate_key(['usage_id', 'subscription_id']) }} as subscription_usage_pk,
    usage_id,
    subscription_id,
    usage_date,
    feature_name,
    usage_count,
    usage_duration_secs,
    error_count,
    is_beta_feature
FROM
    {{ source('raw_subscription', 'feature_usage') }}