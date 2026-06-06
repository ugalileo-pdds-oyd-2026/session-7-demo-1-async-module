# Session 7 — Async Module + Event-Driven Compute

Build a reusable Terraform module that wires SQS, a Lambda Event Source Mapping, and an EventBridge Scheduler into an async job processing system on AWS.

## What students learn

- How to structure a Terraform module with `variables.tf`, `main.tf`, and `outputs.tf` as a strict interface contract
- Why a Dead Letter Queue is necessary and how `redrive_policy` prevents poison messages from looping indefinitely
- How the Lambda Event Source Mapping connects SQS to Lambda without either resource knowing about the other
- How to break a circular module dependency using deterministic resource naming and data sources
- Why each AWS service (Lambda, EventBridge Scheduler) needs its own dedicated IAM role
- How a single Lambda function handles multiple invocation paths (HTTP, SQS, Scheduler) using event shape dispatch

## Project structure

```
session-7-demo-1-async-module/
├── app/
│   └── lambda_function.py          # Lambda handler — dispatches HTTP, SQS, and Scheduler events
├── infra/
│   ├── envs/dev/
│   │   └── dev.tfvars              # Dev environment variable values
│   ├── modules/
│   │   ├── async/                  # Module built during this demo
│   │   │   ├── main.tf             # SQS queues, ESM, IAM policies, Scheduler
│   │   │   ├── variables.tf        # Module inputs
│   │   │   └── outputs.tf          # Queue URLs and ARNs
│   │   └── compute_lambda/         # Pre-existing Lambda + API Gateway module
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   ├── main.tf                     # Root module — wires compute_lambda and async together
│   ├── outputs.tf
│   ├── provider.tf
│   └── variables.tf
```

## Prerequisites

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with valid credentials
- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.6
- [Python 3.12+](https://www.python.org/downloads/) (for packaging the Lambda)

Verify your setup:

```bash
aws sts get-caller-identity
terraform version
```

## Demo workflow

### 1. Package the Lambda

```bash
cd app
zip app.zip lambda_function.py
cd ..
```

### 2. Scaffold the async module

```bash
mkdir -p infra/modules/async
touch infra/modules/async/main.tf infra/modules/async/variables.tf infra/modules/async/outputs.tf
```

Verify: `ls infra/modules/async/` shows three files.

### 3. Define the Dead Letter Queue

Add to `infra/modules/async/main.tf`:

```hcl
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-${var.environment}-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds
}
```

### 4. Define the main queue with redrive policy

Add below the DLQ in `infra/modules/async/main.tf`:

```hcl
resource "aws_sqs_queue" "main" {
  name                       = "${var.name}-${var.environment}-queue"
  visibility_timeout_seconds = var.visibility_timeout_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
}
```

Note: `aws_sqs_queue.dlq.arn` is a direct resource reference — no hardcoded ARN strings.

### 5. Declare variables and outputs

In `infra/modules/async/variables.tf`:

```hcl
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
```

In `infra/modules/async/outputs.tf`:

```hcl
output "queue_url" {
  description = "SQS main queue URL — used by the application to enqueue jobs"
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
```

### 6. Wire the module from root

Add data sources and new variables to `infra/variables.tf`:

```hcl
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
```

Update `infra/main.tf`:

```hcl
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
```

Note: `local.queue_url` is built from data sources and variable names — not from `module.async.*` — which breaks the circular dependency between the two modules.

### 7. Wire the Lambda Event Source Mapping

Add to `infra/modules/async/main.tf`:

```hcl
resource "aws_lambda_event_source_mapping" "this" {
  event_source_arn = aws_sqs_queue.main.arn
  function_name    = var.lambda_function_arn
  batch_size       = var.batch_size
}
```

### 8. Add IAM: SQS permissions on the Lambda execution role

Add to `infra/modules/async/main.tf`:

```hcl
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
```

Four actions scoped to the specific queue ARN: `SendMessage` for the HTTP path, `ReceiveMessage` + `DeleteMessage` + `GetQueueAttributes` for the ESM consumer path.

### 9. Add IAM: Dedicated Scheduler role

Add **above** `aws_scheduler_schedule` in `infra/modules/async/main.tf`:

```hcl
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
```

### 10. Add the EventBridge Scheduler

Add to `infra/modules/async/main.tf`:

```hcl
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
```

The `source = "scheduler"` payload lets the Lambda distinguish this invocation from an HTTP or SQS trigger and run the cleanup branch.

### 11. Add dev.tfvars values, then deploy

Add to `infra/envs/dev/dev.tfvars`:

```hcl
dlq_message_retention_seconds = 1209600
max_receive_count              = 3
visibility_timeout_seconds     = 30
batch_size                     = 10
schedule_expression            = "rate(5 minutes)"
scheduler_timezone             = "America/Guatemala"
```

Then plan and apply:

```bash
cd infra
terraform init
terraform plan -var-file=envs/dev/dev.tfvars
terraform apply -var-file=envs/dev/dev.tfvars
terraform output
```

Expected output:

```
dlq_url     = "https://sqs.us-west-2.amazonaws.com/<ACCOUNT_ID>/<NAME>-dev-dlq"
invoke_url  = "https://<API_ID>.execute-api.us-west-2.amazonaws.com"
queue_url   = "https://sqs.us-west-2.amazonaws.com/<ACCOUNT_ID>/<NAME>-dev-queue"
results_bucket = "<NAME>-dev-results"
```

The plan should show **6 new resources**: DLQ, main queue, ESM, Lambda SQS policy, Scheduler role + policy, Scheduler schedule.

### 12. Test the async path

```bash
curl -X POST $(terraform output -raw invoke_url)/jobs \
  -H "Content-Type: application/json" \
  -d '{"filename": "photo.jpg"}'
```

Expected output:

```json
{"job_id": "job-...", "status": "queued"}
```

The `202 queued` response confirms the HTTP handler enqueued the job to SQS and returned immediately — processing happens asynchronously via the ESM.

### 13. Clean up

```bash
cd infra
terraform destroy -var-file=envs/dev/dev.tfvars
```

## Expected outcomes

By the end of this demo, students should be able to:

1. Build a Terraform module with a clean variable/output contract and no internal hardcoding
2. Explain why a DLQ + `redrive_policy` is required to prevent poison messages from exhausting Lambda concurrency
3. Describe how the Lambda Event Source Mapping decouples SQS from the Lambda function definition
4. Resolve a circular module dependency by computing a resource URL deterministically from data sources
5. Scope IAM policies to the minimum required actions on a specific resource ARN
6. Configure EventBridge Scheduler to invoke Lambda on a recurring schedule with a distinguishable payload
