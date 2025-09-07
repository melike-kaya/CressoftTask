# Example CloudWatch alarm (you can expand later)

resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${local.name}-high-error-rate"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alarm when API Gateway 5XX exceeds 5/min"
}
# Global alarms
