output "invoke_url" {
  description = "APIGW HTTP API invoke URL"
  value       = module.compute_lambda.invoke_url
}

output "results_bucket" {
  description = "S3 bucket where processed job results are stored"
  value       = module.compute_lambda.results_bucket_name
}
