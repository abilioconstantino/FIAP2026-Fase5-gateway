# ============================================================================
# SQS
# Filas do fluxo de processamento de diagramas
# ============================================================================

resource "aws_sqs_queue" "processar_diagrama_dlq" {
  name                      = "${local.project_name}-processar-diagrama-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-processar-diagrama-dlq"
  })
}

resource "aws_sqs_queue" "processar_diagrama" {
  name                       = "${local.project_name}-processar-diagrama"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-processar-diagrama"
  })
}

resource "aws_sqs_queue_redrive_policy" "processar_diagrama" {
  queue_url = aws_sqs_queue.processar_diagrama.id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.processar_diagrama_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "analise_concluida_dlq" {
  name                      = "${local.project_name}-analise-concluida-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-analise-concluida-dlq"
  })
}

resource "aws_sqs_queue" "analise_concluida" {
  name                       = "${local.project_name}-analise-concluida"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-analise-concluida"
  })
}

resource "aws_sqs_queue_redrive_policy" "analise_concluida" {
  queue_url = aws_sqs_queue.analise_concluida.id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.analise_concluida_dlq.arn
    maxReceiveCount     = 3
  })
}
