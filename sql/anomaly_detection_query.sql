-- Detects cost anomalies by comparing each day's spend per service
-- against the trailing 7-day average, filtering out sub-cent noise.

WITH daily_costs AS (
  SELECT
    DATE(usage_start_time) AS usage_date,
    service.description AS service_name,
    SUM(cost) AS daily_cost
  FROM
    `cloud-cost-watchdog-502507.billing_export.gcp_billing_export_v1_01AEE6_E00B11_AE642E`
  GROUP BY
    usage_date, service_name
),

rolling_avg AS (
  SELECT
    usage_date,
    service_name,
    daily_cost,
    AVG(daily_cost) OVER (
      PARTITION BY service_name
      ORDER BY UNIX_DATE(usage_date)
      ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING
    ) AS avg_last_7_days
  FROM
    daily_costs
)

SELECT
  usage_date,
  service_name,
  daily_cost,
  ROUND(avg_last_7_days, 4) AS avg_last_7_days,
  ROUND(daily_cost / NULLIF(avg_last_7_days, 0), 2) AS spike_multiplier
FROM
  rolling_avg
WHERE
  avg_last_7_days > 0
  AND daily_cost > 2 * avg_last_7_days
  AND daily_cost > 0.01  -- ignore noise below ₹0.01
ORDER BY
  usage_date DESC;
