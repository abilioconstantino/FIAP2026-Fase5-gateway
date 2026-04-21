# FIAP 2026 - Tech Challenge 5 - API Gateway

## Objetivo

Este repositorio concentra a porta de entrada da solucao:

- autenticacao simples por `usuario` e `senha` via Lambda
- validacao de bearer token via Lambda Authorizer
- roteamento do API Gateway para os microsservicos publicos `upload` e `relatorio`
- provisionamento da infraestrutura compartilhada essencial para a fase 5
- distribuicao de configuracao compartilhada pronta para consumo pelos times dos microsservicos

## Rotas previstas no gateway

- `POST /auth/login`
- `GET /health`
- `ANY /api/upload`
- `ANY /api/upload/{proxy+}`
- `ANY /api/relatorio`
- `ANY /api/relatorio/{proxy+}`

Os endpoints de negocio dos microsservicos continuam sendo responsabilidade de cada servico. O gateway apenas encaminha as requisicoes para cada prefixo publico.

## Infraestrutura provisionada pelo Terraform

- VPC com subnets publicas e privadas
- NAT Gateway para saida das subnets privadas
- RDS MySQL compartilhado
- bucket S3 para armazenamento dos diagramas
- filas SQS para requisicao e resposta do processamento
- Network Load Balancer interno para integracao privada
- VPC Link entre API Gateway e NLB
- Lambda de login
- Lambda Authorizer de JWT
- Lambda de inicializacao do banco compartilhado
- logs de acesso do API Gateway no CloudWatch
- segredos consolidados no Secrets Manager para `upload`, `processamento` e `relatorio`
- policies IAM prontas para `upload`, `processamento` e `relatorio`

## Estrutura

- `lambda/`: codigo .NET dos lambdas
- `scripts/`: apoio para inicializacao do banco
- `terraform/`: infraestrutura AWS


## Credenciais iniciais de referencia

O script [scripts/init-auth.sql](scripts/init-auth.sql) ja deixa um usuario inicial pronto para desenvolvimento:

- usuario: `admin`
- senha: `Admin@123456`

O JWT base tambem ja foi definido no arquivo [JWT-CONFIG-REFERENCE.env](JWT-CONFIG-REFERENCE.env).

## Como os times dos microsservicos consomem a infra

O gateway ja entrega para cada microsservico:

- um segredo consolidado no Secrets Manager
- uma policy IAM pronta para anexar ao workload
- as rotas publicas e target groups quando o servico for exposto pelo gateway

Esses nomes e ARNs ficam publicados nos outputs do Terraform.
