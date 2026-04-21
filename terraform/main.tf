# ==============================================================================
# TECH CHALLENGE 5 - API GATEWAY
# Infraestrutura compartilhada da fase 5
# ==============================================================================

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  project_name = var.project_name
  environment  = var.environment

  servicos_gateway = {
    upload = {
      path_part     = "upload"
      listener_port = var.upload_listener_port
    }
    relatorio = {
      path_part     = "relatorio"
      listener_port = var.relatorio_listener_port
    }
  }

  bucket_diagramas_name = lower("${local.project_name}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}-diagramas")

  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}
