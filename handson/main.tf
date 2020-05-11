provider "aws" {
  region = "ap-northeast-1"
}

variable "identifier" {
  default = "ec2.amazonaws.com"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [var.identifier]
    }
  }
}

data "aws_iam_policy_document" "allow_describe_regions" {
  statement {
    effect = "Allow"
    actions = ["ec2:DescribeRegions"]
    resources = ["*"]
  }
}


module "describe_regions_for_ec2" {
  source     = "./iam_role"
  name       = "describe-regions-for-ec2"
  identifier = var.identifier
  policy1     = data.aws_iam_policy_document.assume_role.json
  policy2     = data.aws_iam_policy_document.allow_describe_regions.json
}

