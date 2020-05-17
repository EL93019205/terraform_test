provider "aws" {
  region = "ap-northeast-1"
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
  identifier = "ec2.amazonaws.com"
  policy     = data.aws_iam_policy_document.allow_describe_regions.json
}

resource "aws_s3_bucket" "private" {
  bucket = "junbucket-private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "private" {
  bucket = aws_s3_bucket.private.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "public" {
  bucket = "junbucket-public"
  acl = "public-read"

  cors_rule {
    allowed_origins = ["https://example.com"]
    allowed_methods = ["GET"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
  force_destroy = true
}

resource "aws_s3_bucket" "alb_log" {
  bucket = "junbucket-alblog"

  lifecycle_rule {
    enabled = true

    expiration {
      days = "180"
    }
  }
  force_destroy = true
}

resource "aws_s3_bucket_policy" "alb_log" {
  bucket = aws_s3_bucket.alb_log.id
  policy = data.aws_iam_policy_document.alb_log.json
}

data "aws_iam_policy_document" "alb_log" {
  statement{
    effect = "Allow"
    actions = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.alb_log.id}/*"]

    principals {
      type = "AWS"
      identifiers =  ["582318560864"]
    }
  }
}

resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "example"
  }
}

resource "aws_subnet" "public_0" {
  vpc_id = aws_vpc.example.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "public_0_subnet"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id = aws_vpc.example.id
  cidr_block = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone = "ap-northeast-1c"
  tags = {
    Name = "public_1_subnet"
  }
}

resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id
  tags = {
    Name = "internet_gateway_example"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example.id
  tags = {
    Name = "public_route_table"
  }
}

resource "aws_route" "public" {
  route_table_id = aws_route_table.public.id
  gateway_id = aws_internet_gateway.example.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "public_0" {
  subnet_id = aws_subnet.public_0.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1" {
  subnet_id = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private_0" {
  vpc_id = aws_vpc.example.id
  cidr_block = "10.0.65.0/24"
  availability_zone = "ap-northeast-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "private_0_subnet"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id = aws_vpc.example.id
  cidr_block = "10.0.66.0/24"
  availability_zone = "ap-northeast-1c"
  map_public_ip_on_launch = false
  tags = {
    Name = "private_1_subnet"
  }
}

resource "aws_route_table" "private_0" {
  vpc_id = aws_vpc.example.id
  tags = {
    Name = "private_0_route_table"
  }
}

resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.example.id
  tags = {
    Name = "private_1_route_table"
  }
}

resource "aws_route_table_association" "private_0" {
  subnet_id = aws_subnet.private_0.id
  route_table_id = aws_route_table.private_0.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

resource "aws_eip" "nat_gateway_0" {
  vpc = true
  depends_on = [aws_internet_gateway.example]
  tags = {
    Name = "eip0"
  }
}

resource "aws_eip" "nat_gateway_1" {
  vpc = true
  depends_on = [aws_internet_gateway.example]
  tags = {
    Name = "eip1"
  }
}

resource "aws_nat_gateway" "nat_gateway_0" {
  allocation_id = aws_eip.nat_gateway_0.id
  subnet_id = aws_subnet.public_0.id
  depends_on = [aws_internet_gateway.example]
  tags = {
    Name = "public_0_subnet_nat_gateway_0"
  }
}

resource "aws_nat_gateway" "nat_gateway_1" {
  allocation_id = aws_eip.nat_gateway_1.id
  subnet_id = aws_subnet.public_1.id
  depends_on = [aws_internet_gateway.example]
  tags = {
    Name = "public_1_subnet_nat_gateway_1"
  }
}

resource "aws_route" "private_0" {
  route_table_id = aws_route_table.private_0.id
  nat_gateway_id = aws_nat_gateway.nat_gateway_0.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "private_1" {
  route_table_id = aws_route_table.private_1.id
  nat_gateway_id = aws_nat_gateway.nat_gateway_1.id
  destination_cidr_block = "0.0.0.0/0"
}

module "example_sg" {
  source = "./security_group"
  name = "module-sg"
  vpc_id = aws_vpc.example.id
  port = 80
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_lb" "example" {
  name = "example"
  load_balancer_type = "application"
  internal = false
  idle_timeout = 60
  enable_deletion_protection = false

  subnets = [
    aws_subnet.public_0.id,
    aws_subnet.public_1.id,
  ]

  access_logs {
    bucket = aws_s3_bucket.alb_log.id
    enabled = true
  }

  security_groups = [
    module.http_sg.security_group_id,
    module.https_sg.security_group_id,
    module.http_redirect_sg.security_group_id,
  ]
}

output "alb_dns_name" {
  value = aws_lb.example.dns_name
}

module "http_sg" {
  source = "./security_group"
  name = "http-sg"
  vpc_id = aws_vpc.example.id
  port = 80
  cidr_blocks = ["0.0.0.0/0"]
}

module "https_sg" {
  source = "./security_group"
  name = "https-sg"
  vpc_id = aws_vpc.example.id
  port = 443
  cidr_blocks = ["0.0.0.0/0"]
}

module "http_redirect_sg" {
  source = "./security_group"
  name = "http-redirect-sg"
  vpc_id = aws_vpc.example.id
  port = 8080
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "これはhttpです"
      status_code = "200"
    }
  }
}

data "aws_route53_zone" "example" {
  name = "jun-web-free.com"
}

resource "aws_route53_record" "example" {
  zone_id = data.aws_route53_zone.example.zone_id
  name = data.aws_route53_zone.example.name

  type = "A"

  alias {
    name = aws_lb.example.dns_name
    zone_id = aws_lb.example.zone_id
    evaluate_target_health = true
  }
}

output "domain_name" {
  value = aws_route53_record.example.name
}

resource "aws_acm_certificate" "example" {
  domain_name = aws_route53_record.example.name
  subject_alternative_names = []
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "example_certificate" {
  name = aws_acm_certificate.example.domain_validation_options[0].resource_record_name
  type = aws_acm_certificate.example.domain_validation_options[0].resource_record_type
  records = [aws_acm_certificate.example.domain_validation_options[0].resource_record_value]
  zone_id = data.aws_route53_zone.example.id
  ttl = 60
}

resource "aws_acm_certificate_validation" "example" {
  certificate_arn = aws_acm_certificate.example.arn
  validation_record_fqdns = [aws_route53_record.example_certificate.fqdn]
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.example.arn
  port = "443"
  protocol = "HTTPS"
  certificate_arn = aws_acm_certificate.example.arn
  ssl_policy = "ELBSecurityPolicy-2016-08"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "これはHTTPSです"
      status_code = "200"
    }
  }
}

resource "aws_lb_listener" "redirect_http_to_https" {
  load_balancer_arn = aws_lb.example.arn
  port = "8080"
  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port = "443"
      protocol = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_target_group" "example" {
  name = "example"
  target_type = "ip"
  vpc_id = aws_vpc.example.id
  port = 80
  protocol = "HTTP"
  deregistration_delay = 300

  health_check {
    path = "/"
    healthy_threshold = 5
    unhealthy_threshold = 2
    timeout = 5
    interval = 30
    matcher = 200
    port = "traffic-port"
    protocol = "HTTP"
  }

  depends_on = [aws_lb.example]
}

resource "aws_lb_listener_rule" "example" {
  listener_arn = aws_lb_listener.https.arn
  priority = 100

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }

  condition {
    field = "path-pattern"
    values = ["/*"]
  }
}

resource "aws_ecs_cluster" "example" {
  name = "example"
}

resource "aws_ecs_task_definition" "example" {
  family = "example"
  cpu = "256"
  memory = "512"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions = file("./container_definitions.json")
  execution_role_arn = module.ecs_task_execution_role.iam_role_arn
}

resource "aws_ecs_service" "example" {
  name = "example"
  cluster = aws_ecs_cluster.example.arn
  task_definition = aws_ecs_task_definition.example.arn
  desired_count = 2
  launch_type = "FARGATE"
  platform_version = "1.3.0"
  health_check_grace_period_seconds = 60

  network_configuration {
    assign_public_ip = false
    security_groups = [module.nginx_sg.security_group_id]

    subnets = [
      aws_subnet.private_0.id,
      aws_subnet.private_1.id,
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.example.arn
    container_name = "example"
    container_port = 80
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}

module "nginx_sg" {
  source = "./security_group"
  name = "nginx-sg"
  vpc_id = aws_vpc.example.id
  port = 80
  cidr_blocks = [aws_vpc.example.cidr_block]
}

resource "aws_cloudwatch_log_group" "for_ecs" {
  name = "/ecs/example"
  retention_in_days = 180
}

data "aws_iam_policy" "ecs_task_execution_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_execution" {
  source_json = data.aws_iam_policy.ecs_task_execution_role_policy.policy

  statement {
    effect = "Allow"
    actions = ["ssm:GetParameters", "kms:Decrypt"]
    resources = ["*"]
  }
}

module "ecs_task_execution_role" {
  source = "./iam_role"
  name = "ecs-task-execution"
  identifier = "ecs-tasks.amazonaws.com"
  policy = data.aws_iam_policy_document.ecs_task_execution.json
}

resource "aws_cloudwatch_log_group" "for_ecs_scheduled_tasks" {
  name = "/ecs-scheduled-tasks/example"
  retention_in_days = 180
}

resource "aws_ecs_task_definition" "example_batch" {
  family = "example-batch"
  cpu = "256"
  memory = "512"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions = file("./batch_container_definitions.json")
  execution_role_arn = module.ecs_task_execution_role.iam_role_arn
}

module "ecs_events_role" {
  source = "./iam_role"
  name = "ecs-events"
  identifier = "events.amazonaws.com"
  policy = data.aws_iam_policy.ecs_events_role_policy.policy
}

data "aws_iam_policy" "ecs_events_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
}

resource "aws_cloudwatch_event_rule" "example_batch" {
  name = "example-batch"
  description = "とても重要なバッチ処理です"
  schedule_expression = "cron(*/2 * * * ? *)"
}

resource "aws_cloudwatch_event_target" "example_batch" {
  target_id = "example-batch"
  rule = aws_cloudwatch_event_rule.example_batch.name
  role_arn = module.ecs_events_role.iam_role_arn
  arn = aws_ecs_cluster.example.arn

  ecs_target {
    launch_type = "FARGATE"
    task_count = 1
    platform_version = "1.3.0"
    task_definition_arn = aws_ecs_task_definition.example_batch.arn

    network_configuration {
      assign_public_ip = "false"
      subnets = [aws_subnet.private_0.id]
    }
  }
}

resource "aws_kms_key" "example" {
  description = "Example Customer Master Key"
  enable_key_rotation = true
  is_enabled = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "example" {
  name = "alias/example"
  target_key_id = aws_kms_key.example.key_id
}

resource "aws_ssm_parameter" "db_username" {
  name = "/db/username"
  value = "root"
  type = "String"
  description = "データベースのユーザー名"
}

resource "aws_ssm_parameter" "db_password" {
  name = "/db/password"
  value = "uninitialized"
  type = "SecureString"
  description = "データベースのパスワード"
  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_db_parameter_group" "example" {
  name = "example"
  family = "mysql5.7"

  parameter {
    name = "character_set_database"
    value = "utf8mb4"
  }

  parameter {
    name = "character_set_server"
    value = "utf8mb4"
  }
}

resource "aws_db_option_group" "example" {
  name = "example"
  engine_name = "mysql"
  major_engine_version = "5.7"

  option {
    option_name = "MARIADB_AUDIT_PLUGIN"
  }
}
