resource "aws_security_group" "clixx-sg" {
  name        = "tf-${local.RUNNER}-sg"
  description = "Allow required traffix for Clixx Retail App"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tf-${local.RUNNER}-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow-ssh" {
  security_group_id = aws_security_group.clixx-sg.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow-http" {
  security_group_id            = aws_security_group.clixx-sg.id
  referenced_security_group_id = aws_security_group.alb-sg.id
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow-ecs-dynamic-ports" {
  security_group_id            = aws_security_group.clixx-sg.id
  referenced_security_group_id = aws_security_group.alb-sg.id
  from_port                    = 32768
  ip_protocol                  = "tcp"
  to_port                      = 65535
}

resource "aws_security_group" "alb-sg" {
  vpc_id = aws_vpc.main.id
  name   = "${local.ORGANIZATION}-alb-sg"

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.ManagedBy}-${local.ORGANIZATION}-alb-sg"
  }
}


resource "aws_security_group" "bastion-sg" {
  name   = "bastion-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "clixx-bastion-sg"
  }
}

resource "aws_security_group" "efs-sg" {
  name   = "efs-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.clixx-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "clixx-efs-sg"
  }
}

resource "aws_security_group" "db-sg" {
  name   = "db-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"
    security_groups = [
      aws_security_group.clixx-sg.id,
      aws_security_group.bastion-sg.id,
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "clixx-db-sg"
  }
}