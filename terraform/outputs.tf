# ============================================================================
# OUTPUTS
# ============================================================================

output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.main.id
}

output "public_subnets" {
  description = "Subnets publicas"
  value       = aws_subnet.public[*].id
}

output "private_subnets" {
  description = "Subnets privadas"
  value       = aws_subnet.private[*].id
}

output "security_groups_compartilhados" {
  description = "Security groups compartilhados da infraestrutura"
  value = {
    lambda      = aws_security_group.lambda.id
    aplicacoes  = aws_security_group.aplicacoes.id
    banco_mysql = aws_security_group.rds.id
  }
}

output "api_gateway_url" {
  description = "URL base do API Gateway"
  value       = aws_api_gateway_stage.prod.invoke_url
}

output "api_gateway_health_url" {
  description = "Endpoint publico de health do API Gateway"
  value       = "${aws_api_gateway_stage.prod.invoke_url}/health"
}

output "api_gateway_rotas_base" {
  description = "Rotas base publicadas pelo gateway"
  value = {
    auth_login = "${aws_api_gateway_stage.prod.invoke_url}/auth/login"
    upload     = "${aws_api_gateway_stage.prod.invoke_url}/api/upload"
    relatorio  = "${aws_api_gateway_stage.prod.invoke_url}/api/relatorio"
  }
}

output "api_gateway_rest_api_id" {
  description = "ID do REST API"
  value       = aws_api_gateway_rest_api.gateway.id
}

output "vpc_link_id" {
  description = "ID do VPC Link"
  value       = aws_api_gateway_vpc_link.privado.id
}

output "nlb_dns_name" {
  description = "DNS do NLB interno"
  value       = aws_lb.interno.dns_name
}

output "target_groups_microservicos" {
  description = "ARNs dos target groups publicos por microsservico"
  value = {
    for chave, tg in aws_lb_target_group.microservicos :
    chave => tg.arn
  }
}

output "rds_endpoint" {
  description = "Endpoint do MySQL"
  value       = aws_db_instance.mysql.endpoint
}

output "rds_connection_strings" {
  description = "Connection strings por schema"
  value = {
    autenticacao  = "Server=${split(":", aws_db_instance.mysql.endpoint)[0]};Port=3306;Database=${var.db_name_autenticacao};User=${var.db_user}"
    upload        = "Server=${split(":", aws_db_instance.mysql.endpoint)[0]};Port=3306;Database=${var.db_name_upload};User=${var.db_user}"
    processamento = "Server=${split(":", aws_db_instance.mysql.endpoint)[0]};Port=3306;Database=${var.db_name_processamento};User=${var.db_user}"
    relatorio     = "Server=${split(":", aws_db_instance.mysql.endpoint)[0]};Port=3306;Database=${var.db_name_relatorio};User=${var.db_user}"
  }
}

output "s3_bucket_diagramas" {
  description = "Bucket S3 para armazenamento dos diagramas"
  value       = aws_s3_bucket.diagramas.bucket
}

output "sqs_queues" {
  description = "Filas SQS do fluxo"
  value = {
    processar_diagrama     = aws_sqs_queue.processar_diagrama.url
    processar_diagrama_dlq = aws_sqs_queue.processar_diagrama_dlq.url
    analise_concluida      = aws_sqs_queue.analise_concluida.url
    analise_concluida_dlq  = aws_sqs_queue.analise_concluida_dlq.url
  }
}

output "lambda_functions" {
  description = "Lambdas publicados"
  value = {
    auth_login           = aws_lambda_function.auth_login.function_name
    authorizer           = aws_lambda_function.authorizer.function_name
    database_initializer = aws_lambda_function.database_initializer.function_name
  }
}

output "service_config_secrets" {
  description = "Segredos consolidados por microsservico"
  value = {
    for chave, secret in aws_secretsmanager_secret.microservicos_config :
    chave => {
      arn  = secret.arn
      name = secret.name
    }
  }
}

output "service_iam_policies" {
  description = "Policies prontas para anexar aos microsservicos"
  value = {
    upload = {
      arn  = aws_iam_policy.microservico_upload_access.arn
      name = aws_iam_policy.microservico_upload_access.name
    }
    processamento = {
      arn  = aws_iam_policy.microservico_processamento_access.arn
      name = aws_iam_policy.microservico_processamento_access.name
    }
    relatorio = {
      arn  = aws_iam_policy.microservico_relatorio_access.arn
      name = aws_iam_policy.microservico_relatorio_access.name
    }
  }
}

output "infrastructure_summary" {
  description = "Resumo da infraestrutura"
  value = {
    region                = data.aws_region.current.name
    api_gateway_url       = aws_api_gateway_stage.prod.invoke_url
    mysql_endpoint        = aws_db_instance.mysql.endpoint
    bucket_diagramas      = aws_s3_bucket.diagramas.bucket
    filas_sqs             = 2
    microservicos_proxy   = keys(local.servicos_gateway)
    processamento_interno = true
  }
}

output "microservices_configuracao_base" {
  description = "Configuracao base para repassar ao time dos microsservicos"
  value = {
    upload = {
      rota_publica           = "${aws_api_gateway_stage.prod.invoke_url}/api/upload"
      target_group_arn       = aws_lb_target_group.microservicos["upload"].arn
      listener_port          = var.upload_listener_port
      schema_mysql           = var.db_name_upload
      bucket_diagramas       = aws_s3_bucket.diagramas.bucket
      fila_processamento_url = aws_sqs_queue.processar_diagrama.url
      secret_name            = aws_secretsmanager_secret.microservicos_config["upload"].name
      policy_arn             = aws_iam_policy.microservico_upload_access.arn
      security_group_id      = aws_security_group.aplicacoes.id
      private_subnet_ids     = aws_subnet.private[*].id
      jwt_issuer             = var.jwt_issuer
      jwt_audience           = var.jwt_audience
    }
    processamento = {
      exposto_no_gateway  = false
      schema_mysql        = var.db_name_processamento
      bucket_diagramas    = aws_s3_bucket.diagramas.bucket
      fila_consumo_url    = aws_sqs_queue.processar_diagrama.url
      fila_publicacao_url = aws_sqs_queue.analise_concluida.url
      secret_name         = aws_secretsmanager_secret.microservicos_config["processamento"].name
      policy_arn          = aws_iam_policy.microservico_processamento_access.arn
      security_group_id   = aws_security_group.aplicacoes.id
      private_subnet_ids  = aws_subnet.private[*].id
    }
    relatorio = {
      rota_publica       = "${aws_api_gateway_stage.prod.invoke_url}/api/relatorio"
      target_group_arn   = aws_lb_target_group.microservicos["relatorio"].arn
      listener_port      = var.relatorio_listener_port
      schema_mysql       = var.db_name_relatorio
      fila_consumo_url   = aws_sqs_queue.analise_concluida.url
      secret_name        = aws_secretsmanager_secret.microservicos_config["relatorio"].name
      policy_arn         = aws_iam_policy.microservico_relatorio_access.arn
      security_group_id  = aws_security_group.aplicacoes.id
      private_subnet_ids = aws_subnet.private[*].id
      jwt_issuer         = var.jwt_issuer
      jwt_audience       = var.jwt_audience
    }
  }
}
