variable "aws-region" {
  type        = string  
  description = "Região da AWS"
  default     = "us-east-1"
}

terraform {
  required_version = ">= 1.3, <= 1.7.5"

  backend "s3" {
    bucket         = "techchallengestate-g27"
    key            = "terraform-rds/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }

  required_providers {
    
    random = {
      version = "~> 3.0"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.65"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_default_vpc" "vpcTechChallenge" {
  tags = {
    Name = "Default VPC to Tech Challenge"
  }
}

resource "aws_default_subnet" "subnetTechChallenge" {
  availability_zone = "us-east-1a"

  tags = {
    Name = "Default subnet for us-east-1a to Tech Challenge"
  }
}

resource "aws_default_subnet" "subnetTechChallenge2" {
  availability_zone = "us-east-1b"

  tags = {
    Name = "Default subnet for us-east-1b to Tech Challenge"
  }
}

resource "aws_db_subnet_group" "dbgroupsubnet" {
  name        = "techchallenge-subnet-group"
  subnet_ids  = [aws_default_subnet.subnetTechChallenge.id, aws_default_subnet.subnetTechChallenge2.id]

  tags = {
    Name = "My DB Subnet Group"
  }
}

resource "random_string" "username" {
  length  = 16
  special = false
  upper   = true
}

resource "random_string" "password" {
  length           = 16
  special          = true
  override_special = "/@\" "
}

output "secrets_policy" {
  value = aws_iam_policy.secretsPolicy.arn
}

output "secrets_id" {
  value = aws_secretsmanager_secret.db_credentials.id
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "dbcredentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = random_string.username.result
    password = random_string.password.result
    host = aws_db_instance.postgresdb.address
    port = aws_db_instance.postgresdb.port
    db = aws_db_instance.postgresdb.db_name
    typeorm = "postgres://${random_string.username.result}:${random_string.password.result}@${aws_db_instance.postgresdb.address}:${aws_db_instance.postgresdb.port}/${aws_db_instance.postgresdb.db_name}"
  })
}

resource "aws_iam_policy" "secretsPolicy" {
  name   = "podsecrets-deployment-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = [aws_secretsmanager_secret.db_credentials.arn]
      },
    ]
  })
}

resource "aws_db_instance" "postgresdb" {
  allocated_storage    = 10
  identifier           = "postgresapp" 
  db_name              = "app"
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.micro"
  username = random_string.username.result
  password = random_string.password.result
  skip_final_snapshot  = true
  publicly_accessible = true
}