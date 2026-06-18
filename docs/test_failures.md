wher# Known Test Failures

Log of failing dbt data tests, their root cause, and remediation status.

## `unique_stg_bigquery__feature_usage_usage_id`

| Field | Value |
|-------|-------|
| **Test** | `unique` on `stg_bigquery__feature_usage.usage_id` |
| **Defined in** | `models/staging/source.yml` |
| **Status** | ✅ RESOLVED (2026-06-14) — see Resolution below |
| **First seen** | 2026-06-14 |
| **Result** | `Got 21 results, configured to fail if != 0` |

### What it means

`usage_id` is documented as the primary key of `feature_usage`, so every row should have a
distinct value. The test returned **21 `usage_id` values that occur more than once**, i.e. the
raw source `subscriptionchurn.raw.feature_usage` contains duplicate usage events. This is expected
given the synthetic dataset's documented edge cases (e.g. "beta feature spikes", duplicated events).

### How to investigate

Run against the staging view to see the offending keys and how many times each repeats:

```sql
SELECT usage_id, COUNT(*) AS n
FROM `subscriptionchurn.staging.stg_bigquery__feature_usage`
GROUP BY usage_id
HAVING COUNT(*) > 1
ORDER BY n DESC;
```

### Remediation options

1. **De-duplicate in staging** — keep one row per `usage_id`. This makes `usage_id` a true PK and
   the `unique` test pass:

   ```sql
   SELECT * EXCEPT(row_num) FROM (
       SELECT *,
              ROW_NUMBER() OVER (
                  PARTITION BY usage_id
                  ORDER BY usage_date DESC   -- pick the rule that fits the analysis
              ) AS row_num
       FROM {{ source('raw_subscription', 'feature_usage') }}
   )
   WHERE row_num = 1
   ```

2. **Relax the test** — if duplicate usage events are legitimate and should be retained, drop the
   `unique` test from `usage_id` (keep `not_null`) and add a surrogate key
   (`dbt_utils.generate_surrogate_key`) as the grain instead.

3. **Quarantine, don't block** — change the test to a warning while the source is investigated:

   ```yaml
   - name: usage_id
     data_tests:
       - unique:
           config:
             severity: warn
       - not_null
   ```

### Resolution (chosen: option 2 — surrogate key)

Duplicate `usage_id` values were treated as legitimate (a single feature-usage event can recur per
subscription), so the source rows are **retained** rather than de-duplicated. Instead, the model grain
is now enforced by a surrogate key built from `usage_id` + `subscription_id`.

Changes made in `stg_bigquery__feature_usage`:

- **`models/staging/stg_bigquery__feature_usage.sql`** — added a surrogate primary key:

  ```sql
  {{ dbt_utils.generate_surrogate_key(['usage_id', 'subscription_id']) }} as subscription_usage_pk,
  ```

- **`models/staging/source.yml`** — added the `subscription_usage_pk` column carrying the
  `unique` + `not_null` tests, and demoted `usage_id` to `not_null` only.

Net effect: `unique` now validates the `(usage_id, subscription_id)` grain instead of `usage_id`
alone, so the test passes while no source rows are dropped.

**Prerequisites / notes:**

- Requires the `dbt_utils` package. Ensure it is listed in `packages.yml` and installed via
  `dbt deps` before running.
- This assumes `(usage_id, subscription_id)` is genuinely unique. If duplicates exist on that
  combined key too, fall back to option 1 (de-duplicate) or add `usage_date` to the surrogate key.