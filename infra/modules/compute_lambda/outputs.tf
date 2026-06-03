output "invoke_url" {
  description = "APIGW HTTP API invoke URL — structurally equivalent to EC2 public_ip"
  value       = aws_apigatewayv2_stage.this.invoke_url
}

output "api_id" {
  description = "API Gateway HTTP API ID — passed to the dns module to create the custom domain API mapping"
  value       = aws_apigatewayv2_api.this.id
}

output "stage_name" {
  description = "API Gateway stage name — target of the custom domain API mapping"
  value       = aws_apigatewayv2_stage.this.name
}

output "results_bucket_name" {
  description = "S3 bucket name where processed job results are stored"
  value       = aws_s3_bucket.results.bucket
}

output "function_arn" {
  description = "Lambda function ARN — passed to the async module for ESM and scheduler"
  value       = aws_lambda_function.this.arn
}

output "function_name" {
  description = "Lambda function name — passed to async module to scope IAM"
  value       = aws_lambda_function.this.function_name
}

output "execution_role_name" {
  description = "Lambda execution IAM role name — async module attaches SQS policy here"
  value       = aws_iam_role.lambda.name
}
