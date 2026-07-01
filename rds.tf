data "aws_db_snapshot" "latest_prod_snapshot" {
  db_snapshot_identifier = "clixx-recent-snapshot"
  most_recent            = true
}

resource "aws_db_subnet_group" "clixx" {
  name       = "clixx-db-subnet-group"
  subnet_ids = [aws_subnet.private-subnet-a.id, aws_subnet.private-subnet-b.id]
}

resource "aws_db_instance" "clixx" {
  identifier             = "clixx-restored"
  instance_class         = "db.m5.large"
  snapshot_identifier    = data.aws_db_snapshot.latest_prod_snapshot.id
  db_subnet_group_name   = aws_db_subnet_group.clixx.name
  vpc_security_group_ids = [aws_security_group.db-sg.id]
  availability_zone      = "${var.AWS_REGION}a"
  publicly_accessible    = false
  multi_az               = false
  skip_final_snapshot    = true
}