variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "name" {
  description = "Base name applied to all resources in this module"
  type        = string
}

variable "memory_size" {
  description = "Memory allocated to the Lambda function in MB"
  type        = number
  default     = 128
}

variable "queue_url" {
  description = "SQS queue URL passed to the Lambda as QUEUE_URL env var — empty until the async module is added"
  type        = string
  default     = ""
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}
