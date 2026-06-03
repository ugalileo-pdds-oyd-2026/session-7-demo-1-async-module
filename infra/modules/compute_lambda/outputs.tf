output "invoke_url" {
  description = "APIGW HTTP API invoke URL"
  value       = aws_apigatewayv2_stage.this.invoke_url
}

output "api_id" {
  description = "API Gateway HTTP API ID"
  value       = aws_apigatewayv2_api.this.id
}

output "stage_name" {
  description = "API Gateway stage name"
  value       = aws_apigatewayv2_stage.this.name
}

output "results_bucket_name" {
  description = "S3 bucket name where processed job results are stored"
  value       = aws_s3_bucket.results.bucket
}
