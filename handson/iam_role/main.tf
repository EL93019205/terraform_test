variable "name" {}
variable "policy1" {}
variable "policy2" {}
variable "identifier" {}

resource "aws_iam_role" "default" {
  name               = var.name
  assume_role_policy = var.policy1
}

resource "aws_iam_policy" "default" {
  name   = var.name
  policy = var.policy2
}

resource "aws_iam_role_policy_attachment" "default" {
  role       = aws_iam_role.default.name
  policy_arn = aws_iam_policy.default.arn
}

output "iam_role_arn" {
  value = aws_iam_role.default.arn
}

output "iam_role_name" {
  value = aws_iam_role.default.name
}