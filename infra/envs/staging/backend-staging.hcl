bucket         = "oyd-demo-tfstate"
key            = "staging/terraform.tfstate"
region         = "us-west-2"
encrypt        = true
dynamodb_table = "oyd-demo-tfstate-lock"
