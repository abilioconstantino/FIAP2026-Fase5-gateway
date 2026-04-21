# Terraform - API Gateway Fase 5

Infraestrutura enxuta para a fase 5, inspirada na organizacao do gateway da fase 4.

## Recursos provisionados

- VPC com subnets publicas e privadas
- NAT Gateway
- RDS MySQL compartilhado
- bucket S3 para os diagramas
- filas SQS de requisicao e resposta
- NLB interno e VPC Link
- API Gateway REST
- Lambda de login
- Lambda Authorizer
- Lambda inicializador do banco
- logs de acesso do API Gateway no CloudWatch
- segredos consolidados no Secrets Manager por microsservico
- policies IAM prontas para upload, processamento e relatorio

## Antes do `terraform init`

O backend S3 configurado em `provider.tf` precisa existir previamente:

- bucket `techchallenge5-fase5-terraform-state`
- tabela DynamoDB `techchallenge5-fase5-terraform-lock`

## Fluxo esperado

- `POST /auth/login` autentica o usuario
- `GET /health` valida rapidamente a disponibilidade do gateway
- as rotas em `/api/upload` e `/api/relatorio` exigem bearer token
- o gateway encaminha para o NLB interno usando VPC Link
- o microsservico de `processamento` fica interno ao fluxo e conversa por SQS

## Credenciais iniciais de referencia

- usuario: `admin`
- senha: `Admin@123456`
- `JWT_SECRET`: definido em `terraform.tfvars.example` e em `../JWT-CONFIG-REFERENCE.env`

## Entrega para os times dos microsservicos

Depois do `apply`, cada time recebe pelo proprio Terraform:

- segredo consolidado no Secrets Manager
- policy IAM pronta para anexar ao workload
- target group ARN quando o servico for publico pelo gateway
- VPC, subnets privadas e security group compartilhado

Com isso, o consumo da infraestrutura compartilhada deixa de depender de configuracao manual paralela.

## Observacao

Os target groups do NLB sao criados aqui apenas para os microsservicos publicos do gateway. Os alvos reais serao associados quando `upload` e `relatorio` forem implantados.

O bootstrap do banco compartilhado e executado automaticamente por um Lambda na VPC durante o `apply`.
