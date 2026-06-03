resource "aws_s3_bucket" "results" {
  bucket = "${var.name}-${var.environment}-results"

  tags = {
    Name        = "${var.name}-${var.environment}-results"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "results" {
  bucket = aws_s3_bucket.results.id

  rule {
    id     = "expire-old-results"
    status = "Enabled"

    filter { prefix = "results/" }

    expiration {
      days = 30
    }
  }
}

resource "aws_iam_role" "lambda" {
  name = "${var.name}-${var.environment}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3" {
  name = "${var.name}-${var.environment}-lambda-s3-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.results.arn,
        "${aws_s3_bucket.results.arn}/*"
      ]
    }]
  })
}

resource "aws_lambda_function" "this" {
  function_name    = "${var.name}-${var.environment}"
  filename         = "${path.module}/../../../app/app.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../app/app.zip")
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  architectures    = ["x86_64"]
  memory_size      = var.memory_size
  timeout          = var.timeout
  role             = aws_iam_role.lambda.arn

  environment {
    variables = {
      RESULTS_BUCKET = aws_s3_bucket.results.bucket
      QUEUE_URL      = var.queue_url
    }
  }
}

resource "aws_apigatewayv2_api" "this" {
  name          = "${var.name}-${var.environment}"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "this" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.this.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.this.id}"
}

resource "aws_apigatewayv2_route" "jobs" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /jobs"
  target    = "integrations/${aws_apigatewayv2_integration.this.id}"
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
