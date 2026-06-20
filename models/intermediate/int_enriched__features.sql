{{
    config(
        materialized='ephemeral')
}}

WITH features as (
SELECT
    DISTINCT
    feature_name
FROM
    {{ ref('stg_bigquery__feature_usage')}}
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['feature_name']) }} as feature_pk,
    feature_name
FROM
    features


