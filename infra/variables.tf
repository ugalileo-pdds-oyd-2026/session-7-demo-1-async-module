variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "name" {
  description = "Base name applied to all resources"
  type        = string
}

variable "memory_size" {
  description = "Memory allocated to the Lambda function in MB"
  type        = number
  default     = 128
}

variable "dlq_message_retention_seconds" {
  description = "DLQ message retention period in seconds"
  type        = number
  default     = 1209600
}

variable "max_receive_count" {
  description = "Delivery attempts before a message moves to the DLQ"
  type        = number
  default     = 3
}

variable "visibility_timeout_seconds" {
  description = "Queue visibility timeout in seconds — must be >= Lambda timeout"
  type        = number
  default     = 30
}

variable "batch_size" {
  description = "Max messages per Lambda invocation"
  type        = number
  default     = 10
}
