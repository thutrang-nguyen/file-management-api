provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

data "aws_availability_zones" "available" {}

###################################################################
# NETWORKING #
###################################################################
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
  tags {
    Name      = "file-management-vpc",
    Project   = "file-management"
  }
}

# Create only 1 public subnet for demonstration purpose
resource "aws_subnet" "public" {
  count                   = "1"
  cidr_block              = "${cidrsubnet(aws_vpc.this.cidr_block, 8, count.index + 1)}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id                  = "${aws_vpc.this.id}"
  map_public_ip_on_launch = true
  tags {
    Name      = "file-management-public-subnet",
    Project   = "file-management"
  }
}

# IGW for the public subnet
resource "aws_internet_gateway" "this" {
  vpc_id = "${aws_vpc.this.id}"
}

# Route the public subnet traffic through the IGW
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.this.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.this.id}"
}

###################################################################
# DynamoDB
###################################################################
resource "aws_dynamodb_table" "this" {
  name           = "${var.aws_dynamodb_table_name}"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "Name"

  attribute {
    name = "Name"
    type = "S"
  }
  tags {
    Name      = "file-management-dynamodb-table",
    Project   = "file-management"
  }
}

###################################################################
# S3 bucket
###################################################################
resource "aws_s3_bucket" "this" {
  bucket_prefix = "${var.aws_s3_bucket_name_prefix}"
  acl           = "private"
  force_destroy = true

  versioning {
    enabled = true
  }

  tags {
    Name    = "file-management-s3-bucket"
    Project = "file-management-api"
  }
}

###################################################################
# EC2 Role for Fargate instance
###################################################################
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "this" {
  name = "file-management-access"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem",
                "dynamodb:scan"
            ],
            "Resource": "${aws_dynamodb_table.this.arn}"
        },
        {
            "Effect": "Allow",
            "Action": ["s3:ListBucket"],
            "Resource": ["${aws_s3_bucket.this.arn}"]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject"
            ],
            "Resource": ["${aws_s3_bucket.this.arn}/*"]
        }
    ]
}
EOF
}

resource "aws_iam_role" "this" {
  name = "file-management-role"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
  
  description = "EC2 role for File Management API on Fargate"
}

resource "aws_iam_policy_attachment" "this" {
  name       = "file-management-role-policy-attachment"
  roles      = ["${aws_iam_role.this.name}"]
  policy_arn = "${aws_iam_policy.this.arn}"
}

# ECS Execution IAM Role
resource "aws_iam_role" "execution" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
  description = "Allow execution on Fargate"
}

data "aws_iam_policy" "execution" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy_attachment" "execution" {
  name       = "ecs-execution-role-policy-attachment"
  roles      = ["${aws_iam_role.execution.name}"]
  policy_arn = "${data.aws_iam_policy.execution.arn}"
}

###################################################################
# Security group for Fargate instance
###################################################################
resource "aws_security_group" "this" {
  name        = "file-management-sg"
  description = "Allow inbound access from the open internet"
  vpc_id      = "${aws_vpc.this.id}"

  ingress {
    protocol        = "tcp"
    from_port       = "${var.app_port}"
    to_port         = "${var.app_port}"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Name      = "file-management-sg",
    Project   = "file-management"
  }
}

###################################################################
# ECR repository
###################################################################
resource "aws_ecr_repository" "this" {
  name = "file-management-api"
}

resource "null_resource" "docker_image" {
  provisioner "local-exec" {
    command = "make build && make push"
    environment {
      DOCKER_REGISTRY = "${aws_ecr_repository.this.repository_url}"
      PROJECT_NAME = ""
      BRANCH_NAME = "latest"
      AWS_DEFAULT_REGION = "${var.aws_region}"
    }
  }
  depends_on = ["aws_ecr_repository.this", ]
}


###################################################################
# Fargate instance
###################################################################
resource "aws_ecs_cluster" "this" {
  name = "file-management-cluster"
}

resource "aws_cloudwatch_log_group" "this" {
  name = "/ecs/file-management"
}

resource "aws_cloudwatch_log_stream" "this" {
  name           = "api"
  log_group_name = "${aws_cloudwatch_log_group.this.name}"
}

resource "aws_ecs_task_definition" "this" {
  family                   = "file-management-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "${var.fargate_cpu}"
  memory                   = "${var.fargate_memory}"
  task_role_arn            = "${aws_iam_role.this.arn}"
  execution_role_arn       = "${aws_iam_role.execution.arn}"

  container_definitions = <<DEFINITION
[
  {
    "image": "${aws_ecr_repository.this.repository_url}:latest",
    "cpu": ${var.fargate_cpu},
    "memory": ${var.fargate_memory},
    "memoryReservation": ${var.fargate_memory},
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/file-management",
        "awslogs-region": "${var.aws_region}",
        "awslogs-stream-prefix": "api"
      }
    },
    "environment": [
      {
        "name": "FILE_API_DYNAMODB_TABLE",
        "value": "${aws_dynamodb_table.this.name}"
      },
      {
        "name": "FILE_API_S3_BUCKET",
        "value": "${aws_s3_bucket.this.id}"
      },
      {
        "name": "AWS_DEFAULT_REGION",
        "value": "${var.aws_region}"
      },
      {
        "name": "FLASK_APP",
        "value": "file_api"
      },
      {
        "name": "FLASK_ENV",
        "value": "production"
      }
    ],
    "name": "file-management-api",
    "networkMode": "awsvpc",
    "portMappings": [
      {
        "containerPort": ${var.app_port},
        "hostPort": ${var.app_port},
        "protocol": "tcp"
      }
    ]
  }
]
DEFINITION
  depends_on = ["null_resource.docker_image"]
}

resource "aws_ecs_service" "this" {
  name            = "file-management-api"
  cluster         = "${aws_ecs_cluster.this.id}"
  task_definition = "${aws_ecs_task_definition.this.arn}"
  desired_count   = "${var.app_count}"
  launch_type     = "FARGATE"

  network_configuration {
    security_groups   = ["${aws_security_group.this.id}"]
    subnets           = ["${aws_subnet.public.*.id}"]
    assign_public_ip  = "true"
  }
}
