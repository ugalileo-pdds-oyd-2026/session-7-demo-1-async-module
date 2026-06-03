data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  queue_url = "https://sqs.${data.aws_region.current.name}.amazonaws.com/${data.aws_caller_identity.current.account_id}/${var.name}-${var.environment}-queue"
}

module "compute_lambda" {
  source = "./modules/compute_lambda"

  environment = var.environment
  name        = var.name
  memory_size = var.memory_size
  queue_url   = local.queue_url
}

module "async" {
  source = "./modules/async"

  name        = var.name
  environment = var.environment

  lambda_function_arn        = module.compute_lambda.function_arn
  lambda_function_name       = module.compute_lambda.function_name
  lambda_execution_role_name = module.compute_lambda.execution_role_name

  dlq_message_retention_seconds = var.dlq_message_retention_seconds
  max_receive_count             = var.max_receive_count
  visibility_timeout_seconds    = var.visibility_timeout_seconds
  batch_size                    = var.batch_size
  schedule_expression           = var.schedule_expression
  scheduler_timezone            = var.scheduler_timezone
}
