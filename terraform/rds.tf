# ============================================================================
# RDS MYSQL
# Um banco compartilhado com schemas por contexto
# ============================================================================

resource "aws_db_subnet_group" "main" {
  name       = "${local.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-db-subnet-group"
  })
}

resource "aws_db_instance" "mysql" {
  identifier                 = "${local.project_name}-mysql"
  engine                     = "mysql"
  engine_version             = "8.0"
  instance_class             = var.db_instance_class
  allocated_storage          = 20
  max_allocated_storage      = 100
  storage_type               = "gp3"
  storage_encrypted          = true
  db_name                    = var.db_name_autenticacao
  username                   = var.db_user
  password                   = var.db_password
  port                       = 3306
  db_subnet_group_name       = aws_db_subnet_group.main.name
  vpc_security_group_ids     = [aws_security_group.rds.id]
  publicly_accessible        = false
  skip_final_snapshot        = true
  deletion_protection        = false
  backup_retention_period    = 1
  backup_window              = "03:00-04:00"
  maintenance_window         = "sun:04:00-sun:05:00"
  apply_immediately          = true
  multi_az                   = false
  auto_minor_version_upgrade = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-mysql"
  })

  depends_on = [aws_route_table_association.private]
}

