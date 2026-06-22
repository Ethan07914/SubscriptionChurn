
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
    is_trial
FROM
     {{ ref('stg_bigquery__accounts') }})

, support_tickets as (
SELECT
    account_id,
    submitted_at,

    -- Time Metrics
    sum(resolution_time_hours) as total_resolution_time_hours,
    avg(resolution_time_hours) as avg_resolution_time_hours,
    sum(first_response_time_minutes) as total_first_response_time_minutes,
    avg(first_response_time_minutes) as avg_first_response_time_minutes,

    -- Ticket Totals
    count(ticket_id) as total_tickets,
    sum(CASE WHEN priority = 'high' THEN 1 ELSE 0 END) as total_high_priority_tickets,
    sum(CASE WHEN priority = 'low' THEN 1 ELSE 0 END) as total_low_priority_tickets,
    sum(CASE WHEN priority = 'medium' THEN 1 ELSE 0 END) as total_medium_priority_tickets,
    sum(CASE WHEN priority = 'urgent' THEN 1 ELSE 0 END) as total_urgent_priority_tickets,
    sum(CASE WHEN escalation_flag THEN 1 ELSE 0 END) as total_escalated_ticket,

    -- Satisfaction Scores
    sum(satisfaction_score) as total_satisfaction_score,
    avg(satisfaction_score) as average_satisfaction_score,
FROM
    {{ ref('stg_bigquery__support_tickets') }}
GROUP BY
    account_id,
    submitted_at
)

, feature_usage as (
SELECT
    s.account_id,
    fu.usage_date,
    count(distinct fu.feature_name) as total_features_used,
    sum(CASE WHEN fu.is_beta_feature THEN 1 ELSE 0 END) as total_beta_features_used,
    sum(fu.usage_count) as total_usage_count,
    sum(fu.usage_duration_secs) as total_usage_duration_secs,
    sum(fu.error_count) as total_error_count
FROM
    {{ ref('stg_bigquery__feature_usage') }} as fu
    inner join {{ ref('stg_bigquery__subscriptions') }} as s
    on fu.subscription_id = s.subscription_id
GROUP BY
    account_id,
    usage_date)

, churn_events as (
SELECT
    account_id,
    churn_date,
    count(*) as total_churn_events,
    sum(refund_amount_usd) as refund_amount_usd,
    logical_or(preceding_upgrade_flag) as preceding_upgrade_flag,
    logical_or(preceding_downgrade_flag) as preceding_downgrade_flag,
    string_agg(distinct reason_code, ', ') as reason_code,
    string_agg(distinct feedback_text, ', ') as feedback_text
FROM
    {{ ref('stg_bigquery__churn_events') }}
WHERE
    is_reactivation = FALSE
GROUP BY
    account_id,
    churn_date)

, spine as (
-- One row per account per day that appears in any activity source
SELECT account_id, usage_date  as activity_date FROM feature_usage
UNION DISTINCT
SELECT account_id, submitted_at as activity_date FROM support_tickets
UNION DISTINCT
SELECT account_id, churn_date   as activity_date FROM churn_events
)

, final as (
SELECT
     {{ dbt_utils.generate_surrogate_key(['sp.account_id', 'sp.activity_date']) }} as account_date_pk,
     sp.account_id,
     sp.activity_date,
     a.* EXCEPT(account_id),

    -- Time Metrics
    coalesce(st.total_resolution_time_hours, 0) as total_resolution_time_hours,
    coalesce(st.avg_resolution_time_hours, 0) as avg_resolution_time_hours,
    coalesce(st.total_first_response_time_minutes, 0) as total_first_response_time_minutes,
    coalesce(st.avg_first_response_time_minutes, 0) as avg_first_response_time_minutes,

    -- Ticket Totals
    coalesce(st.total_tickets, 0) as total_tickets,
    coalesce(st.total_high_priority_tickets, 0) as total_high_priority_tickets,
    coalesce(st.total_low_priority_tickets, 0) as total_low_priority_tickets,
    coalesce(st.total_medium_priority_tickets, 0) as total_medium_priority_tickets,
    coalesce(st.total_urgent_priority_tickets, 0) as total_urgent_priority_tickets,
    coalesce(st.total_escalated_ticket, 0) as total_escalated_ticket,

    -- Satisfaction Scores
    coalesce(st.total_satisfaction_score, 0) as total_response_satisfaction_score,
    coalesce(st.average_satisfaction_score, 0) as average_response_satisfaction_score,

    -- Feature Usage
    coalesce(fu.total_features_used, 0) as total_features_used,
    coalesce(fu.total_beta_features_used, 0) as total_beta_features_used,
    coalesce(fu.total_usage_count, 0) as total_usage_count,
    coalesce(fu.total_usage_duration_secs, 0) as total_usage_duration_secs,
    coalesce(fu.total_error_count, 0) as total_error_count,

    -- Churn Events
    coalesce(ce.total_churn_events, 0) as total_churn_events,
    ce.reason_code as churn_reason_code,
    coalesce(ce.refund_amount_usd, 0) as refund_amount_usd,
    ce.preceding_upgrade_flag,
    ce.preceding_downgrade_flag,
    ce.feedback_text churn_feedback_text,
    CASE
        WHEN ce.account_id IS NOT NULL THEN TRUE
        ELSE FALSE
    END AS churned_today

FROM
    spine as sp
    left join accounts as a
    on sp.account_id = a.account_id
    left join feature_usage as fu
    on sp.account_id = fu.account_id and sp.activity_date = fu.usage_date
    left join support_tickets as st
    on sp.account_id = st.account_id and sp.activity_date = st.submitted_at
    left join churn_events as ce
    on sp.account_id = ce.account_id and sp.activity_date = ce.churn_date
WHERE
    (fu.account_id IS NOT NULL
     OR st.account_id IS NOT NULL
     OR CE.account_id IS NOT NULL)
    )

SELECT * FROM final
