resource "aws_secretsmanager_secret" "app_secrets" {
  name                    = "${var.project_name}-app-secrets-${var.environment}"
  recovery_window_in_days = 7

  tags = {
    Name = "${var.project_name}-app-secrets-${var.environment}"
  }
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id

  secret_string = jsonencode({
    OPENAI_API_KEY = var.openai_api_key
    JWT_SECRET     = var.jwt_secret != "" ? var.jwt_secret : random_password.jwt_secret.result
    DATABASE_URL   = "jdbc:postgresql://${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
    DATABASE_USERNAME = aws_db_instance.main.username
    DATABASE_PASSWORD = random_password.db_password.result
  })
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

resource "aws_iam_policy" "secrets_access" {
  name        = "${var.project_name}-secrets-access-${var.environment}"
  description = "Allow ECS tasks to access secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.app_secrets.arn,
          aws_secretsmanager_secret.db_password.arn
        ]
      }
    ]
  })
}
