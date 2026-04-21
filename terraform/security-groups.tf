# ============================================================================
# SECURITY GROUPS
# ============================================================================

resource "aws_security_group" "lambda" {
  name        = "${local.project_name}-lambda-sg"
  description = "Security group do lambda de autenticacao"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Saida geral"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-lambda-sg"
  })
}

resource "aws_security_group" "aplicacoes" {
  name        = "${local.project_name}-apps-sg"
  description = "Security group base para microsservicos privados"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Aplicacoes privadas acessiveis apenas dentro da VPC"
    from_port   = 8080
    to_port     = 8090
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    description = "Saida geral"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-apps-sg"
  })
}

resource "aws_security_group" "rds" {
  name        = "${local.project_name}-rds-sg"
  description = "Security group do banco MySQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL a partir do lambda"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  ingress {
    description     = "MySQL a partir dos microsservicos"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.aplicacoes.id]
  }

  egress {
    description = "Saida geral"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-rds-sg"
  })
}

