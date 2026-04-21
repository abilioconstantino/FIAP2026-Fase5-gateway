# ============================================================================
# CORS
# ============================================================================

locals {
  recursos_cors = merge(
    {
      auth_login = {
        resource_id = aws_api_gateway_resource.auth_login.id
        methods     = "POST,OPTIONS"
      }
    },
    {
      for chave, recurso in aws_api_gateway_resource.servicos :
      chave => {
        resource_id = recurso.id
        methods     = "GET,POST,PUT,PATCH,DELETE,OPTIONS"
      }
    },
    {
      for chave, recurso in aws_api_gateway_resource.servicos_proxy :
      "${chave}_proxy" => {
        resource_id = recurso.id
        methods     = "GET,POST,PUT,PATCH,DELETE,OPTIONS"
      }
    }
  )
}

resource "aws_api_gateway_method" "cors" {
  for_each = local.recursos_cors

  rest_api_id   = aws_api_gateway_rest_api.gateway.id
  resource_id   = each.value.resource_id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "cors" {
  for_each = local.recursos_cors

  rest_api_id = aws_api_gateway_rest_api.gateway.id
  resource_id = each.value.resource_id
  http_method = aws_api_gateway_method.cors[each.key].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "cors" {
  for_each = local.recursos_cors

  rest_api_id = aws_api_gateway_rest_api.gateway.id
  resource_id = each.value.resource_id
  http_method = aws_api_gateway_method.cors[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "cors" {
  for_each = local.recursos_cors

  rest_api_id = aws_api_gateway_rest_api.gateway.id
  resource_id = each.value.resource_id
  http_method = aws_api_gateway_method.cors[each.key].http_method
  status_code = aws_api_gateway_method_response.cors[each.key].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'${each.value.methods}'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

