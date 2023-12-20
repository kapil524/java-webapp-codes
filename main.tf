##################Creating ECR and Building and Pushing the Image to ECR#################
resource "aws_ecr_repository" "your_repository" {
  name = "java-app-ecr"
}

resource "null_resource" "build_and_push_docker_image" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOT
      echo "Executing local-exec provisioner..."
      echo "AWS ECR URL: ${aws_ecr_repository.your_repository.repository_url}"
      aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.your_repository.repository_url}
      docker build -t ${aws_ecr_repository.your_repository.repository_url}:java-app-image .
      docker push ${aws_ecr_repository.your_repository.repository_url}:java-app-image
      echo "Local exec completed successfully."
    EOT
  }
}
##################Creating ECR and Building and Pushing the Image to ECR#################

#####################################################################################

resource "aws_ecs_cluster" "your_cluster" {
  name = "java-app-ecs-cluster"
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policies to the role as needed (e.g., ECS and ECR policies)
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_execution_role.name
}

# Additional policy for ECR access
resource "aws_iam_policy" "ecr_policy" {
  name        = "ECRPolicy"
  description = "Policy for ECR access"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:ListImages",
        ],
        Resource = aws_ecr_repository.your_repository.arn,
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "ecr_role_policy_attachment" {
  policy_arn = aws_iam_policy.ecr_policy.arn
  role       = aws_iam_role.ecs_execution_role.name
}

resource "aws_ecs_task_definition" "your_task_definition" {
  family                   = "java-app-ecs-family"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name  = "java-app-container"
    image = "${aws_ecr_repository.your_repository.repository_url}:java-app-image"
    portMappings = [
      {
        containerPort = 8080,
        hostPort      = 8080,
      }
    ]

    // Add other container settings as needed
  }])
}

resource "aws_ecs_service" "your_service" {
  name            = "java-app-ecs-service"
  cluster         = aws_ecs_cluster.your_cluster.id
  task_definition = aws_ecs_task_definition.your_task_definition.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = ["subnet-0a2c8753df8be86b9", "subnet-03e71207eb0b3520d"]
    security_groups = [aws_security_group.your_security_group.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.your_target_group.arn
    container_name   = "java-app-container"
    container_port   = 8080
  }
}

resource "aws_lb" "your_load_balancer" {
  name               = "java-app-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.your_security_group.id]
  subnets            = ["subnet-0a2c8753df8be86b9", "subnet-03e71207eb0b3520d"]
}

resource "aws_lb_target_group" "your_target_group" {
  name        = "java-app-target-group"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = "vpc-046a9ba86fe64a343"
  target_type = "ip"
}

resource "aws_lb_listener" "your_listener" {
  load_balancer_arn = aws_lb.your_load_balancer.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.your_target_group.arn
  }
}

resource "aws_security_group" "your_security_group" {
  name        = "java-app-security-group"
  description = "Your security group description"
  vpc_id      = "vpc-046a9ba86fe64a343"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}


