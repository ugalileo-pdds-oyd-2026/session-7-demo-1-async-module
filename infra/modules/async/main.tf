resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-${var.environment}-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds
}

resource "aws_sqs_queue" "main" {
  name                       = "${var.name}-${var.environment}-queue"
  visibility_timeout_seconds = var.visibility_timeout_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
}

resource "aws_lambda_event_source_mapping" "this" {
  event_source_arn = aws_sqs_queue.main.arn
  function_name    = var.lambda_function_arn
  batch_size       = var.batch_size
}

resource "aws_iam_role_policy" "lambda_sqs" {
  name = "${var.name}-${var.environment}-lambda-sqs-policy"
  role = var.lambda_execution_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      Resource = aws_sqs_queue.main.arn
    }]
  })
}

resource "aws_iam_role" "scheduler" {
  name = "${var.name}-${var.environment}-scheduler-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_invoke" {
  name = "${var.name}-${var.environment}-scheduler-invoke-policy"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = var.lambda_function_arn
    }]
  })
}

resource "aws_scheduler_schedule" "this" {
  name       = "${var.name}-${var.environment}-schedule"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = var.scheduler_timezone

  target {
    arn      = var.lambda_function_arn
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      source = "scheduler"
    })
  }
}
