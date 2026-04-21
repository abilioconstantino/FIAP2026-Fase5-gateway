# ============================================================================
# VPC LINK
# Conecta o API Gateway ao NLB interno
# ============================================================================

resource "aws_api_gateway_vpc_link" "privado" {
  name        = "${local.project_name}-vpc-link"
  description = "VPC Link do API Gateway para os microsservicos privados"

  target_arns = [aws_lb.interno.arn]

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-vpc-link"
  })
}

