resource "aws_vpc" "main" {
  cidr_block           = "10.1.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "tf-${local.RUNNER}-${local.ORGANIZATION}-vpc"
  }
}

resource "aws_subnet" "public-subnet-a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "${var.AWS_REGION}a"

  tags = {
    Name = "tf-${local.RUNNER}-${local.ORGANIZATION}-public-subnet-a"
  }
}

resource "aws_subnet" "public-subnet-b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "${var.AWS_REGION}b"

  tags = {
    Name = "tf-${local.RUNNER}-${local.ORGANIZATION}-public-subnet-b"
  }
}

resource "aws_subnet" "private-subnet-a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.3.0/24"
  availability_zone = "${var.AWS_REGION}a"

  tags = {
    Name = "tf-${local.RUNNER}-${local.ORGANIZATION}-private-subnet-a"
  }
}

resource "aws_subnet" "private-subnet-b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.4.0/24"
  availability_zone = "${var.AWS_REGION}b"

  tags = {
    Name = "tf-${local.RUNNER}-${local.ORGANIZATION}-private-subnet-b"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "tf-${local.RUNNER}-${local.ORGANIZATION}-igw"
  }
}

resource "aws_eip" "nat_eipa" {
  domain = "vpc"

  tags = {
    Name = "tf-${local.RUNNER}-${local.ORGANIZATION}-eip-a"
  }
}

resource "aws_eip" "nat_eipb" {
  domain = "vpc"

  tags = {
    Name = "tf-${local.RUNNER}-${local.ORGANIZATION}-eip-b"
  }
}

resource "aws_nat_gateway" "nat-gtwy" {
  depends_on = [aws_internet_gateway.igw]

  for_each = {
    "a" = aws_subnet.public-subnet-a
    "b" = aws_subnet.public-subnet-b
  }

  allocation_id = each.key == "a" ? aws_eip.nat_eipa.id : aws_eip.nat_eipb.id
  subnet_id     = each.value.id

  tags = {
    Name = "tf-${local.RUNNER}-${local.ORGANIZATION}-nat"
  }
}

resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "tf-${local.RUNNER}-${local.ORGANIZATION}-public-rt"
  }
}

resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.main.id

  for_each = {
    "a" = aws_subnet.public-subnet-a
    "b" = aws_subnet.public-subnet-b
  }

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gtwy[each.key].id
  }

  tags = {
    Name = "tf-${local.RUNNER}-${local.ORGANIZATION}-private-rt"
  }
}

resource "aws_route_table_association" "public-a" {
  subnet_id      = aws_subnet.public-subnet-a.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_route_table_association" "public-b" {
  subnet_id      = aws_subnet.public-subnet-b.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_route_table_association" "private" {
  for_each = {
    "a" = aws_subnet.private-subnet-a
    "b" = aws_subnet.private-subnet-b
  }

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private-rt[each.key].id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    aws_route_table.private-rt["a"].id,
    aws_route_table.private-rt["b"].id,
    aws_route_table.public-rt.id
  ]
}