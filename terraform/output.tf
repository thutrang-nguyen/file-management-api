output "ecs_repository" {
  value = "${aws_ecr_repository.this.repository_url}"
}

output "file_management_api_fargate_cluster" {
  value = "${aws_ecs_cluster.this.arn}"
}