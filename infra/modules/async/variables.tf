variable "name" {
  description = "Base name for all async resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "lambda_function_arn" {
  description = "ARN of the Lambda function that consumes messages from the queue"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function — used to scope IAM permissions"
  type        = string
}

variable "lambda_execution_role_name" {
  description = "Name of the Lambda execution IAM role — the async module attaches SQS permissions to it"
  type        = string
}

variable "dlq_message_retention_seconds" {
  description = "How long the DLQ retains unprocessed messages (seconds)"
  type        = number
  default     = 1209600
}

variable "visibility_timeout_seconds" {
  description = "How long a message is hidden after being picked up — must be >= Lambda timeout"
  type        = number
  default     = 30
}

variable "max_receive_count" {
  description = "Delivery attempts before a message is moved to the DLQ"
  type        = number
  default     = 3
}

variable "batch_size" {
  description = "Maximum number of messages Lambda reads per invocation"
  type        = number
  default     = 10
}

variable "schedule_expression" {
  description = "EventBridge Scheduler expression (rate or cron)"
  type        = string
  default     = "rate(5 minutes)"
}

variable "scheduler_timezone" {
  description = "IANA timezone for the schedule"
  type        = string
  default     = "America/Guatemala"
}
