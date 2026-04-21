# ============================================================================
# API GATEWAY REST API
# ============================================================================

resource "aws_api_gateway_rest_api" "gateway" {
  name        = "${local.project_name}-api-gateway"
  description = "API Gateway da fase 5 para analise de diagramas"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-api-gateway"
  })
}

resource "aws_cloudwatch_log_group" "api_gateway_access" {
  name              = "/aws/apigateway/${local.project_name}-access"
  retention_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-api-access-logs"
  })
}

resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${local.project_name}-apigw-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "gateway" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

resource "aws_lambda_permission" "api_gateway_auth_login" {
  statement_id  = "AllowInvokeAuthLoginFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_login.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.gateway.execution_arn}/*/POST/auth/login"
}

resource "aws_lambda_permission" "api_gateway_authorizer" {
  statement_id  = "AllowInvokeAuthorizerFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.gateway.execution_arn}/authorizers/*"
}

resource "aws_api_gateway_authorizer" "jwt" {
  name                             = "${local.project_name}-jwt-authorizer"
  rest_api_id                      = aws_api_gateway_rest_api.gateway.id
  authorizer_uri                   = aws_lambda_function.authorizer.invoke_arn
  authorizer_credentials           = aws_iam_role.api_gateway_lambda_invoke.arn
  type                             = "TOKEN"
  identity_source                  = "method.request.header.Authorization"
  authorizer_result_ttl_in_seconds = 300

  depends_on = [
    aws_lambda_function.authorizer,
    aws_lambda_permission.api_gateway_authorizer
  ]
}

resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.gateway.id
  parent_id   = aws_api_gateway_rest_api.gateway.root_resource_id
  path_part   = "api"
}

resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.gateway.id
  parent_id   = aws_api_gateway_rest_api.gateway.root_resource_id
  path_part   = "auth"
}

resource "aws_api_gateway_resource" "auth_login" {
  rest_api_id = aws_api_gateway_rest_api.gateway.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "login"
}

resource "aws_api_gateway_resource" "servicos" {
  for_each = local.servicos_gateway

  rest_api_id = aws_api_gateway_rest_api.gateway.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = each.value.path_part
}

resource "aws_api_gateway_resource" "servicos_proxy" {
  for_each = local.servicos_gateway

  rest_api_id = aws_api_gateway_rest_api.gateway.id
  parent_id   = aws_api_gateway_resource.servicos[each.key].id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "auth_login_post" {
  rest_api_id   = aws_api_gateway_rest_api.gateway.id
  resource_id   = aws_api_gateway_resource.auth_login.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_login" {
  rest_api_id = aws_api_gateway_rest_api.gateway.id
  resource_id = aws_api_gateway_resource.auth_login.id
  http_method = aws_api_gateway_method.auth_login_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.auth_login.invoke_arn
}

resource "aws_api_gateway_method" "servicos_base_any" {
  for_each = local.servicos_gateway

  rest_api_id   = aws_api_gateway_rest_api.gateway.id
  resource_id   = aws_api_gateway_resource.servicos[each.key].id
  http_method   = "ANY"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id

  request_parameters = {
    "method.request.header.Authorization" = true
  }
}

resource "aws_api_gateway_integration" "servicos_base" {
  for_each = local.servicos_gateway

  rest_api_id = aws_api_gateway_rest_api.gateway.id
  resource_id = aws_api_gateway_resource.servicos[each.key].id
  http_method = aws_api_gateway_method.servicos_base_any[each.key].http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://${aws_lb.interno.dns_name}:${each.value.listener_port}/api/${each.value.path_part}"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.privado.id

  request_parameters = {
    "integration.request.header.Authorization" = "method.request.header.Authorization"
  }
}

resource "aws_api_gateway_method" "servicos_proxy_any" {
  for_each = local.servicos_gateway

  rest_api_id   = aws_api_gateway_rest_api.gateway.id
  resource_id   = aws_api_gateway_resource.servicos_proxy[each.key].id
  http_method   = "ANY"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id

  request_parameters = {
    "method.request.path.proxy"           = true
    "method.request.header.Authorization" = true
  }
}

resource "aws_api_gateway_integration" "servicos_proxy" {
  for_each = local.servicos_gateway

  rest_api_id = aws_api_gateway_rest_api.gateway.id
  resource_id = aws_api_gateway_resource.servicos_proxy[each.key].id
  http_method = aws_api_gateway_method.servicos_proxy_any[each.key].http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://${aws_lb.interno.dns_name}:${each.value.listener_port}/api/${each.value.path_part}/{proxy}"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.privado.id

  request_parameters = {
    "integration.request.path.proxy"           = "method.request.path.proxy"
    "integration.request.header.Authorization" = "method.request.header.Authorization"
  }
}

resource "aws_api_gateway_deployment" "gateway" {
  rest_api_id = aws_api_gateway_rest_api.gateway.id

  depends_on = [
    aws_api_gateway_integration.auth_login,
    aws_api_gateway_integration.servicos_base,
    aws_api_gateway_integration.servicos_proxy,
    aws_api_gateway_integration.cors,
    aws_api_gateway_integration_response.cors
  ]

  lifecycle {
    create_before_destroy = true
  }

  triggers = {
    redeployment = sha1(jsonencode({
      auth_method_id           = aws_api_gateway_method.auth_login_post.id
      auth_integration_id      = aws_api_gateway_integration.auth_login.id
      servicos_base_methods    = [for _, item in aws_api_gateway_method.servicos_base_any : item.id]
      servicos_base_integrals  = [for _, item in aws_api_gateway_integration.servicos_base : item.id]
      servicos_proxy_methods   = [for _, item in aws_api_gateway_method.servicos_proxy_any : item.id]
      servicos_proxy_integrals = [for _, item in aws_api_gateway_integration.servicos_proxy : item.id]
      cors_methods             = [for _, item in aws_api_gateway_method.cors : item.id]
    }))
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.gateway.id
  rest_api_id   = aws_api_gateway_rest_api.gateway.id
  stage_name    = "prod"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_access.arn
    format = jsonencode({
      requestId       = "$context.requestId"
      ip              = "$context.identity.sourceIp"
      requestTime     = "$context.requestTime"
      httpMethod      = "$context.httpMethod"
      routeKey        = "$context.resourcePath"
      status          = "$context.status"
      protocol        = "$context.protocol"
      responseLength  = "$context.responseLength"
      authorizerError = "$context.authorizer.error"
    })
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-api-prod"
  })

  depends_on = [aws_api_gateway_account.gateway]
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.gateway.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  method_path = "*/*"

  settings {
    logging_level      = "INFO"
    metrics_enabled    = true
    data_trace_enabled = false
  }
}
