# ============================================================================
# SEGREDOS E POLITICAS COMPARTILHADAS PARA OS MICROSSERVICOS
# Os times podem apenas anexar a policy correspondente e ler o segredo do seu MS
# ============================================================================

locals {
  private_subnet_ids = aws_subnet.private[*].id

  microservicos_secret_payload = {
    upload = {
      aws_region              = var.aws_region
      environment             = var.environment
      api_gateway_url         = aws_api_gateway_stage.prod.invoke_url
      auth_login_url          = "${aws_api_gateway_stage.prod.invoke_url}/auth/login"
      rota_publica            = "${aws_api_gateway_stage.prod.invoke_url}/api/upload"
      nlb_dns_name            = aws_lb.interno.dns_name
      target_group_arn        = aws_lb_target_group.microservicos["upload"].arn
      listener_port           = var.upload_listener_port
      vpc_id                  = aws_vpc.main.id
      private_subnet_ids      = local.private_subnet_ids
      security_group_id       = aws_security_group.aplicacoes.id
      db_host                 = local.db_host
      db_port                 = 3306
      db_schema               = var.db_name_upload
      db_user                 = var.db_user
      db_password             = var.db_password
      db_connection_string    = "Server=${local.db_host};Port=3306;Database=${var.db_name_upload};User=${var.db_user};Password=${var.db_password};SslMode=Preferred;"
      bucket_diagramas        = aws_s3_bucket.diagramas.bucket
      queue_processamento_url = aws_sqs_queue.processar_diagrama.url
      queue_processamento_arn = aws_sqs_queue.processar_diagrama.arn
      jwt_secret              = var.jwt_secret
      jwt_issuer              = var.jwt_issuer
      jwt_audience            = var.jwt_audience
    }
    processamento = {
      aws_region           = var.aws_region
      environment          = var.environment
      exposto_no_gateway   = false
      vpc_id               = aws_vpc.main.id
      private_subnet_ids   = local.private_subnet_ids
      security_group_id    = aws_security_group.aplicacoes.id
      db_host              = local.db_host
      db_port              = 3306
      db_schema            = var.db_name_processamento
      db_user              = var.db_user
      db_password          = var.db_password
      db_connection_string = "Server=${local.db_host};Port=3306;Database=${var.db_name_processamento};User=${var.db_user};Password=${var.db_password};SslMode=Preferred;"
      bucket_diagramas     = aws_s3_bucket.diagramas.bucket
      queue_consumo_url    = aws_sqs_queue.processar_diagrama.url
      queue_consumo_arn    = aws_sqs_queue.processar_diagrama.arn
      queue_publicacao_url = aws_sqs_queue.analise_concluida.url
      queue_publicacao_arn = aws_sqs_queue.analise_concluida.arn
      jwt_secret           = var.jwt_secret
      jwt_issuer           = var.jwt_issuer
      jwt_audience         = var.jwt_audience
    }
    relatorio = {
      aws_region           = var.aws_region
      environment          = var.environment
      api_gateway_url      = aws_api_gateway_stage.prod.invoke_url
      auth_login_url       = "${aws_api_gateway_stage.prod.invoke_url}/auth/login"
      rota_publica         = "${aws_api_gateway_stage.prod.invoke_url}/api/relatorio"
      nlb_dns_name         = aws_lb.interno.dns_name
      target_group_arn     = aws_lb_target_group.microservicos["relatorio"].arn
      listener_port        = var.relatorio_listener_port
      vpc_id               = aws_vpc.main.id
      private_subnet_ids   = local.private_subnet_ids
      security_group_id    = aws_security_group.aplicacoes.id
      db_host              = local.db_host
      db_port              = 3306
      db_schema            = var.db_name_relatorio
      db_user              = var.db_user
      db_password          = var.db_password
      db_connection_string = "Server=${local.db_host};Port=3306;Database=${var.db_name_relatorio};User=${var.db_user};Password=${var.db_password};SslMode=Preferred;"
      queue_consumo_url    = aws_sqs_queue.analise_concluida.url
      queue_consumo_arn    = aws_sqs_queue.analise_concluida.arn
      jwt_secret           = var.jwt_secret
      jwt_issuer           = var.jwt_issuer
      jwt_audience         = var.jwt_audience
    }
  }
}

resource "aws_secretsmanager_secret" "microservicos_config" {
  for_each = local.microservicos_secret_payload

  name                    = "${local.project_name}-${each.key}-config"
  recovery_window_in_days = 0

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${each.key}-config"
    Service = each.key
  })
}

resource "aws_secretsmanager_secret_version" "microservicos_config" {
  for_each = local.microservicos_secret_payload

  secret_id     = aws_secretsmanager_secret.microservicos_config[each.key].id
  secret_string = jsonencode(each.value)
}

resource "aws_iam_policy" "microservico_upload_access" {
  name        = "${local.project_name}-upload-access"
  description = "Acesso compartilhado de infra para o microsservico de upload"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.microservicos_config["upload"].arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.diagramas.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.diagramas.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.processar_diagrama.arn
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-upload-access"
    Service = "upload"
  })
}

resource "aws_iam_policy" "microservico_processamento_access" {
  name        = "${local.project_name}-processamento-access"
  description = "Acesso compartilhado de infra para o microsservico de processamento"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.microservicos_config["processamento"].arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.diagramas.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.diagramas.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:ChangeMessageVisibility",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.processar_diagrama.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.analise_concluida.arn
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-processamento-access"
    Service = "processamento"
  })
}

resource "aws_iam_policy" "microservico_relatorio_access" {
  name        = "${local.project_name}-relatorio-access"
  description = "Acesso compartilhado de infra para o microsservico de relatorio"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.microservicos_config["relatorio"].arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:ChangeMessageVisibility",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.analise_concluida.arn
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-relatorio-access"
    Service = "relatorio"
  })
}
