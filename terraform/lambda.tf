# ============================================================================
# BUILD E PUBLICACAO DOS LAMBDAS
# ============================================================================

resource "null_resource" "build_auth_lambda" {
  triggers = {
    source_hash = sha256(join("", concat(
      [filesha256("${path.module}/../lambda/TechChallenge5.Lambda.Auth.csproj")],
      [for f in fileset("${path.module}/../lambda/src", "**/*.cs") : filesha256("${path.module}/../lambda/src/${f}")]
    )))
  }

  provisioner "local-exec" {
    command = <<-EOT
      Push-Location ${path.module}\..\lambda

      if (Test-Path "publish-auth") { Remove-Item -Path "publish-auth" -Recurse -Force }
      if (Test-Path "auth.zip") { Remove-Item -Path "auth.zip" -Force }

      dotnet publish TechChallenge5.Lambda.Auth.csproj `
        -c Release `
        -r linux-x64 `
        --self-contained false `
        -o publish-auth

      if ($LASTEXITCODE -ne 0) {
        Write-Host "Falha ao buildar o lambda de autenticacao" -ForegroundColor Red
        exit 1
      }

      Push-Location publish-auth
      Compress-Archive -Path * -DestinationPath ..\auth.zip -Force
      Pop-Location
      Pop-Location
    EOT

    interpreter = ["PowerShell", "-Command"]
  }
}

resource "null_resource" "build_authorizer_lambda" {
  triggers = {
    source_hash = sha256(join("", concat(
      [filesha256("${path.module}/../lambda/TechChallenge5.Lambda.Authorizer.csproj")],
      [filesha256("${path.module}/../lambda/src/Handlers/JwtAuthorizerHandler.cs")]
    )))
  }

  provisioner "local-exec" {
    command = <<-EOT
      Push-Location ${path.module}\..\lambda

      if (Test-Path "publish-authorizer") { Remove-Item -Path "publish-authorizer" -Recurse -Force }
      if (Test-Path "authorizer.zip") { Remove-Item -Path "authorizer.zip" -Force }

      dotnet publish TechChallenge5.Lambda.Authorizer.csproj `
        -c Release `
        -r linux-x64 `
        --self-contained false `
        -o publish-authorizer

      if ($LASTEXITCODE -ne 0) {
        Write-Host "Falha ao buildar o lambda authorizer" -ForegroundColor Red
        exit 1
      }

      Push-Location publish-authorizer
      Compress-Archive -Path * -DestinationPath ..\authorizer.zip -Force
      Pop-Location
      Pop-Location
    EOT

    interpreter = ["PowerShell", "-Command"]
  }
}

# ============================================================================
# IAM
# ============================================================================

resource "aws_iam_role" "lambda_execucao" {
  name = "${local.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-lambda-role"
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execucao.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_execucao.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role" "api_gateway_lambda_invoke" {
  name = "${local.project_name}-apigw-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "api_gateway_lambda_invoke" {
  name = "${local.project_name}-apigw-lambda-policy"
  role = aws_iam_role.api_gateway_lambda_invoke.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "lambda:InvokeFunction"
      ]
      Resource = aws_lambda_function.authorizer.arn
    }]
  })
}

# ============================================================================
# LAMBDA DE AUTENTICACAO
# ============================================================================

resource "aws_lambda_function" "auth_login" {
  depends_on = [
    null_resource.build_auth_lambda,
    aws_db_instance.mysql
  ]

  filename      = "${path.module}/../lambda/auth.zip"
  function_name = "${local.project_name}-auth-login"
  role          = aws_iam_role.lambda_execucao.arn
  handler       = "TechChallenge5.Lambda.Auth::TechChallenge5.Lambda.Auth.Handlers.AuthUsuarioHandler::HandleLoginAsync"
  runtime       = "dotnet8"
  timeout       = 30
  memory_size   = 256

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_CONNECTION_STRING = "Server=${split(":", aws_db_instance.mysql.endpoint)[0]};Port=3306;Database=${var.db_name_autenticacao};User=${var.db_user};Password=${var.db_password};SslMode=Preferred;"
      TABLE_USUARIOS       = var.table_usuarios
      JWT_SECRET           = var.jwt_secret
      JWT_ISSUER           = var.jwt_issuer
      JWT_AUDIENCE         = var.jwt_audience
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-auth-login"
  })
}

resource "aws_lambda_function" "authorizer" {
  depends_on = [null_resource.build_authorizer_lambda]

  filename      = "${path.module}/../lambda/authorizer.zip"
  function_name = "${local.project_name}-jwt-authorizer"
  role          = aws_iam_role.lambda_execucao.arn
  handler       = "TechChallenge5.Lambda.Authorizer::TechChallenge5.Lambda.Authorizer.Handlers.JwtAuthorizerHandler::HandleAuthorization"
  runtime       = "dotnet8"
  timeout       = 10
  memory_size   = 128

  environment {
    variables = {
      JWT_SECRET   = var.jwt_secret
      JWT_ISSUER   = var.jwt_issuer
      JWT_AUDIENCE = var.jwt_audience
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-jwt-authorizer"
  })
}

resource "aws_cloudwatch_log_group" "auth_login" {
  name              = "/aws/lambda/${aws_lambda_function.auth_login.function_name}"
  retention_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-auth-login-logs"
  })
}

resource "aws_cloudwatch_log_group" "authorizer" {
  name              = "/aws/lambda/${aws_lambda_function.authorizer.function_name}"
  retention_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-authorizer-logs"
  })
}
