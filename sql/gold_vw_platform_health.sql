CREATE OR REPLACE VIEW `gold.vw_platform_health` AS
SELECT
  table_name,
  error_reason,
  COUNT(*) AS error_count,
  MAX(rejected_at) AS last_error_detected
FROM
  `quarantine.invalid_records`
GROUP BY
  table_name,
  error_reason;