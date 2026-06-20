{{
    config(
        materialized='ephemeral')
}}

WITH joined as (
SELECT
    a.account_id,
    st.ticket_id,
    a.account_name,
    a.industry,
    a.country,
    a.signup_date,
    a.referral_source,
    a.plan_tier,
    a.number_of_seats,
    a.is_trial,
    a.churn_flag,
    st.resolution_time_hours,
    st.first_response_time_minutes,
    st.satisfaction_score,
    CASE
        WHEN escalation_flag THEN 1
        ELSE 0
    END AS is_escalation,
    CASE
        WHEN NOT escalation_flag THEN 1
        ELSE 0
    END AS is_not_escalation,
    {% set priority_levels = ['high', 'low', 'medium', 'urgent'] %}
    {% for priority_level in priority_levels %}
    CASE
        WHEN priority = '{{ priority_level }}' THEN 1
        ELSE 0
    END AS is_{{ priority_level }}_priority{% if not loop.last %},{% endif %}
    {% endfor %}
FROM
    {{ ref('stg_bigquery__accounts') }} as a
    LEFT JOIN {{ ref('stg_bigquery__support_tickets') }} as st
    ON a.account_id = st.account_id)

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
    count(satisfaction_score) as total_satisfaction_scores,
    count(distinct ticket_id) as total_support_tickets,
    sum(resolution_time_hours) as total_resolution_time_hours,
    sum(first_response_time_minutes) as total_first_response_time_minutes,
    sum(satisfaction_score) as total_satisfaction_score,
    sum(is_escalation) as total_escalated_tickets,
    sum(is_not_escalation) as total_unescalated_tickets,
    sum(is_high_priority) as total_high_priority,
    sum(is_low_priority) as total_low_priority,
    sum(is_medium_priority) as total_medium_priority,
    sum(is_urgent_priority) as total_urgent_priority
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

, final as (
SELECT
    *,
    SAFE_DIVIDE(total_resolution_time_hours, total_support_tickets) as average_resolution_time_hours,
    SAFE_DIVIDE(total_first_response_time_minutes, total_support_tickets) as average_first_response_time_minutes,
    SAFE_DIVIDE(total_satisfaction_score, total_satisfaction_scores) as average_satisfaction_score
FROM
    aggregated)

SELECT
    *
FROM
    final