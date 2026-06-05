output "queue_url" {
  description = "SQS main queue URL — used by the application to enqueue messages"
  value       = aws_sqs_queue.main.url
}

output "queue_arn" {
  description = "SQS main queue ARN"
  value       = aws_sqs_queue.main.arn
}

output "dlq_url" {
  description = "Dead letter queue URL"
  value       = aws_sqs_queue.dlq.url
}

output "dlq_arn" {
  description = "Dead letter queue ARN"
  value       = aws_sqs_queue.dlq.arn
}
