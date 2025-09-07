# Outputs
output "function_name"  { value = aws_lambda_function.this.function_name }
output "alias_name"     { value = aws_lambda_alias.live.name }
output "apigw_url"      { value = aws_apigatewayv2_api.http.api_endpoint }
output "cd_app"         { value = aws_codedeploy_app.lambda.name }
output "cd_group"       { value = aws_codedeploy_deployment_group.lambda.deployment_group_name }
output "alarm_errors"   { value = aws_cloudwatch_metric_alarm.lambda_errors.name }
