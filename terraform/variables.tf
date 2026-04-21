variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome base do projeto"
  type        = string
  default     = "tc5-diagramas"
}

variable "environment" {
  description = "Ambiente de deploy"
  type        = string
  default     = "prod"
}

variable "jwt_secret" {
  description = "Segredo usado para assinar e validar o JWT"
  type        = string
  default     = "CqDFIGTKHTJVlkTej5BjDR5FyqRX7R9WfTzmMCpLywNzpVYVrihTyevf7dEb6pVqvbjnJ1mZ"
  sensitive   = true
}

variable "jwt_issuer" {
  description = "Issuer do JWT"
  type        = string
  default     = "tc5-auth"
}

variable "jwt_audience" {
  description = "Audience do JWT"
  type        = string
  default     = "tc5-api"
}

variable "table_usuarios" {
  description = "Nome da tabela de usuarios usada pelo lambda de autenticacao"
  type        = string
  default     = "usuarios"
}

variable "db_user" {
  description = "Usuario administrador do MySQL"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Senha do MySQL"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "Classe da instancia RDS"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name_autenticacao" {
  description = "Schema inicial criado pelo RDS para autenticacao"
  type        = string
  default     = "auth_db"
}

variable "db_name_upload" {
  description = "Schema usado pelo microsservico de upload"
  type        = string
  default     = "upload_db"
}

variable "db_name_processamento" {
  description = "Schema usado pelo microsservico de processamento"
  type        = string
  default     = "processamento_db"
}

variable "db_name_relatorio" {
  description = "Schema usado pelo microsservico de relatorio"
  type        = string
  default     = "relatorio_db"
}

variable "upload_listener_port" {
  description = "Porta interna do NLB para o microsservico de upload"
  type        = number
  default     = 8081
}

variable "relatorio_listener_port" {
  description = "Porta interna do NLB para o microsservico de relatorio"
  type        = number
  default     = 8083
}
