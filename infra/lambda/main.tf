# Lambda + API Gateway + CodeDeploy
locals {
  prefix        = "${var.name}-${var.env}"
  function_name = "${local.prefix}-podinfo"
  alias_name    = "live" # sabit alias, CodeDeploy bu alias üstünden trafik kaydıracak
}

# Başlangıç için "bootstrap" tag'iyle fonksiyonu oluştur (deploy'da digest'e güncelleyeceğiz)
resource "aws_lambda_function" "this" {
  function_name = local.function_name
  package_type  = "Image"
  role          = aws_iam_role.lambda_exec.arn

  image_uri     = "${var.ecr_registry}/${var.ecr_repo}:bootstrap"
  memory_size   = var.memory_mb
  timeout       = var.timeout_s
  architectures = ["x86_64"] # istersen arm64

  environment {
    variables = {
      # Örnek: corr-id header anahtarı vs. (gerekirse)
    }
  }
}

# Alias (trafik bunun üstünden dönecek)
resource "aws_lambda_alias" "live" {
  name             = local.alias_name
  function_name    = aws_lambda_function.this.function_name
  function_version = "$LATEST" # ilk yaratılışta LATEST'i işaretlesin, deploy'da versiyon değişecek
}

# API Gateway HTTP API → Lambda
resource "aws_apigatewayv2_api" "http" {
  name          = "${local.prefix}-httpapi"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_alias.live.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "root" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

# Lambda'ya API GW'in invoke etmesi için izin
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGWInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  # Alias'ı hedefleyelim
  qualifier     = aws_lambda_alias.live.name
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

# CloudWatch Alarms → Rollback sinyalleri
# Basit bir örnek: Lambda Errors > 0 (1 dakikalık 2 evaluation)
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.prefix}-lambda-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
    Resource     = "${aws_lambda_function.this.function_name}:${aws_lambda_alias.live.name}"
  }
  treat_missing_data = "notBreaching"
}

# CodeDeploy (Lambda) Application + Deployment Group (canary 10%→100%)
resource "aws_iam_role" "codedeploy" {
  name               = "${local.prefix}-cd-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.cd_trust.json
}
data "aws_iam_policy_document" "cd_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["codedeploy.amazonaws.com"] }
  }
}
# AWS managed policy (Lambda için CodeDeploy rolü)
resource "aws_iam_role_policy_attachment" "cd_managed" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda"
}

resource "aws_codedeploy_app" "lambda" {
  name = "${local.prefix}-lambda-app"
  compute_platform = "Lambda"
}

resource "aws_codedeploy_deployment_group" "lambda" {
  app_name              = aws_codedeploy_app.lambda.name
  deployment_group_name = "${local.prefix}-lambda-dg"
  service_role_arn      = aws_iam_role.codedeploy.arn

  deployment_config_name = "CodeDeployDefault.LambdaCanary10Percent5Minutes"

  alarm_configuration {
    alarms = [aws_cloudwatch_metric_alarm.lambda_errors.name]
    enabled = true
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 0
    }
  }
}

# Lambda çalışma rolü
resource "aws_iam_role" "lambda_exec" {
  name               = "${local.prefix}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}
data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions   = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["lambda.amazonaws.com"] }
  }
}
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
