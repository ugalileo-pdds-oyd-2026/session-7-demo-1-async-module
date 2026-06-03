environment = "staging"
name        = "demo-lambda"
memory_size = 256

dlq_message_retention_seconds  = 1209600
max_receive_count              = 5
visibility_timeout_seconds     = 60
batch_size                     = 10
bisect_batch_on_function_error = true
schedule_expression            = "rate(15 minutes)"
scheduler_timezone             = "America/Guatemala"