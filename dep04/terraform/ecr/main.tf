provider "aws" {
  region = "us-east-2"
}

resource "aws_ecr_repository" "this" {
  name         = "lgmrepo"
  force_delete = true
}