data "aws_iam_policy_document" "allow_describe_regions" {
  statement{
    effect = "Allow"
    actions = ["ec2:DescribeRegions"]
    resource=["*"]
  }
}

resource "aws_iam_policy" "example" {
  name = "example"
  policy = data.aws_iam_policy_document.allow_describe_regions.json
}

