{{
    config(
        materialized='ephemeral')
}}

WITH joined as (
SELECT
    a.account_id,
    a.account_name,
    a.industry,
    a.country,
    a.signup_date,
    a.referral_source,
    a.plan_tier,
    a.number_of_seats,
    a.is_trial,
    a.churn_flag,
    ce.churn_event_id,
    ce.churn_date,
    ce.refund_amount_usd,
    CASE
        WHEN preceding_downgrade_flag THEN 1
        ELSE 0
    END as preceding_downgrade_flag,
    CASE
        WHEN preceding_upgrade_flag THEN 1
        ELSE 0
    END as preceding_upgrade_flag,
    CASE
        WHEN ce.is_reactivation THEN 1
        ELSE 0
    END AS is_reactivation,
    {% set reason_codes = ['budget', 'competitor', 'features', 'pricing', 'support', 'unknown'] %}
    {% for code in reason_codes %}
    CASE
        WHEN reason_code = '{{ code }}' THEN 1
        ELSE 0
    END AS is_{{ code }}_reason_event{% if not loop.last %},{% endif %}
    {% endfor %},
    CASE
        WHEN feedback_text = 'missing features' THEN 1
        ELSE 0
    END AS feedback_missing_features,
    CASE
        WHEN feedback_text = 'switched to competitor' THEN 1
        ELSE 0
    END AS feedback_switched_to_competitor,
    CASE
        WHEN feedback_text = 'too expensive' THEN 1
        ELSE 0
    END AS feedback_to_expensive,
    CASE
        WHEN feedback_text IS NULL THEN 1
        ELSE 0
    END AS feedback_not_given
FROM
    {{ ref('stg_bigquery__accounts') }} as a
    LEFT JOIn {{ ref('stg_bigquery__churn_events') }} as ce
    on a.account_id = ce.account_id)

, aggregated as (
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
    churn_flag,
    count(distinct churn_event_id) as total_churn_events,
    count(refund_amount_usd) as total_refunds,
    sum(is_reactivation) as total_reactivations,
    sum(refund_amount_usd) as total_refund_amount_usd,
    sum(preceding_downgrade_flag) as total_preceding_downgrade_flags,
    sum(preceding_upgrade_flag) as total_preceding_upgrade_flags,
    sum(is_budget_reason_event) as total_budget_reason_code,
    sum(is_competitor_reason_event) as total_competitor_reason_code,
    sum(is_features_reason_event) as total_features_reason_code,
    sum(is_pricing_reason_event) as total_pricing_reason_code,
    sum(is_support_reason_event) as total_support_reason_code,
    sum(is_unknown_reason_event) as total_unknown_reason_code,
    sum(feedback_missing_features) as total_feedback_missing_features,
    sum(feedback_switched_to_competitor) as total_feedback_switched_to_competitor,
    sum(feedback_to_expensive) as total_feedback_to_expensive,
    sum(feedback_not_given) as total_feedback_not_given
FROM
    joined
GROUP BY
    account_id,
    account_name,
    industry,
    country,
    signup_date,
    referral_source,
    plan_tier,
    number_of_seats,
    is_trial,
    churn_flag)

, most_recent_churn_event as (
SELECT
    account_id,
    churn_date,
    is_reactivation as currently_active
FROM
    joined
QUALIFY
    row_number() over(partition by account_id order by churn_date DESC) = 1)

, final as (
SELECT
    a.*,
    SAFE_DIVIDE(total_refund_amount_usd, total_refunds) as average_refund_amount,
    mrce.churn_date as last_churn_event_date,
    COALESCE(mrce.currently_active, 1) as currently_active
FROM
    aggregated as a
    left join most_recent_churn_event as mrce
    on a.account_id = mrce.account_id
)

SELECT
    *
FROM
    final



