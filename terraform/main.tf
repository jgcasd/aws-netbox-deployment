data "aws_ssm_parameter" "netbox_db_pass" {
  name = "/netbox_core/db_pass"
}

terraform {
  backend "s3" {}
}

provider "aws" {
  region = "${var.Region}"
}

resource "aws_s3_bucket_object" "netbox" {
  bucket = "${var.S3Bucket}"
  key    = "netbox-build.zip"
  source = "../netbox-build.zip"
  etag   = "${md5(file("../netbox-build.zip"))}"
}

resource "aws_iam_instance_profile" "netbox" {
  name = "netbox"
  role = "${aws_iam_role.netbox.name}"
}

resource "aws_iam_role" "netbox" {
  name               = "netbox"
  path               = "/"
  assume_role_policy = "${file("assume_role.json")}"
}

data "template_file" "netbox_iam_policy" {
  template = "${file("netbox_iam_policy.json")}"

  vars {
    S3Bucket = "${var.S3Bucket}"
    Region   = "${var.Region}"
    KMSKeyId = "${var.KMSKeyId}"
    Account  = "${var.Account}"
  }
}

resource "aws_iam_policy" "netbox" {
  name   = "allow-netbox-ec2"
  policy = "${data.template_file.netbox_iam_policy.rendered}"
}

resource "aws_iam_policy_attachment" "netbox" {
  name       = "netbox"
  roles      = ["${aws_iam_role.netbox.name}"]
  policy_arn = "${aws_iam_policy.netbox.arn}"
}

resource "aws_kms_grant" "netbox" {
  name              = "netbox"
  key_id            = "${var.KMSKeyId}"
  grantee_principal = "${aws_iam_role.netbox.arn}"
  operations        = ["Encrypt", "Decrypt", "GenerateDataKey"]
}

data "template_file" "user_data" {
  template = "${file("user_data.tpl")}"

  vars {
    Environment = "${var.Environment}"
    S3Bucket    = "${var.S3Bucket}"
    Region      = "${var.Region}"
    Version     = "${aws_s3_bucket_object.netbox.etag}"
  }
}

resource "aws_launch_configuration" "netbox" {
  image_id             = "${var.AMI}"
  instance_type        = "${var.InstanceType}"
  security_groups      = ["${aws_security_group.sg_netbox_asg.id}"]
  key_name             = "${var.KeyName}"
  user_data            = "${data.template_file.user_data.rendered}"
  iam_instance_profile = "${aws_iam_instance_profile.netbox.name}"
  name_prefix          = "netbox-"

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_availability_zones" "allzones" {}

resource "aws_autoscaling_group" "netbox" {
  name = "${aws_launch_configuration.netbox.name}-asg"

  launch_configuration  = "${aws_launch_configuration.netbox.name}"
  availability_zones    = ["${data.aws_availability_zones.allzones.names}"]
  min_size              = 1
  max_size              = 4
  desired_capacity      = 2
  health_check_type     = "ELB"
  target_group_arns     = ["${aws_lb_target_group.netbox.arn}"]
  wait_for_elb_capacity = true
  vpc_zone_identifier   = "${var.PrivateSubnets}"

  tag {
    key                 = "Name"
    value               = "Netbox"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "${var.Environment}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = ["aws_ssm_parameter.netbox"]
}

resource "aws_security_group" "sg_netbox_asg" {
  name   = "sg_netbox_asg"
  vpc_id = "${var.VPCId}"

  tags {
    Name = "sg_netbox_asg"
  }
}

resource "aws_security_group_rule" "elb_to_asg_ingress" {
  security_group_id        = "${aws_security_group.sg_netbox_asg.id}"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  type                     = "ingress"
  source_security_group_id = "${aws_security_group.sg_netbox_elb.id}"
  description              = "ELB to ASG"
}

resource "aws_security_group_rule" "asg_egress_https" {
  security_group_id = "${aws_security_group.sg_netbox_asg.id}"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS - Package Downloads/Updates"
}

resource "aws_security_group_rule" "asg_egress_http" {
  security_group_id = "${aws_security_group.sg_netbox_asg.id}"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTP - Package Downloads/Updates"
}

resource "aws_security_group_rule" "asg_egress_ldap" {
  security_group_id = "${aws_security_group.sg_netbox_asg.id}"
  from_port         = 389
  to_port           = 389
  protocol          = "tcp"
  type              = "egress"
  cidr_blocks       = "${var.DomainControllers}"
  description       = "LDAP to Domain Controllers"
}

resource "aws_security_group_rule" "asg_egress_ldaps" {
  security_group_id = "${aws_security_group.sg_netbox_asg.id}"
  from_port         = 636
  to_port           = 636
  protocol          = "tcp"
  type              = "egress"
  cidr_blocks       = "${var.DomainControllers}"
  description       = "LDAPS to Domain Controllers"
}

resource "aws_security_group_rule" "asg_egress_dns_tcp" {
  security_group_id = "${aws_security_group.sg_netbox_asg.id}"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  type              = "egress"
  cidr_blocks       = "${var.DomainControllers}"
  description       = "DNS/TCP to Domain Controllers"
}

resource "aws_security_group_rule" "asg_egress_dns_udp" {
  security_group_id = "${aws_security_group.sg_netbox_asg.id}"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  type              = "egress"
  cidr_blocks       = "${var.DomainControllers}"
  description       = "DNS/UDP to Domain Controllers"
}

resource "aws_security_group_rule" "asg_to_rds_egress" {
  security_group_id        = "${aws_security_group.sg_netbox_asg.id}"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  type                     = "egress"
  source_security_group_id = "${aws_security_group.sg_netbox_rds.id}"
  description              = "ASG to RDS"
}

resource "aws_security_group" "sg_netbox_elb" {
  name   = "sg_netbox_elb"
  vpc_id = "${var.VPCId}"

  tags {
    Name = "sg_netbox_elb"
  }
}

resource "aws_security_group_rule" "elb_ingress_https" {
  security_group_id = "${aws_security_group.sg_netbox_elb.id}"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  type              = "ingress"
  cidr_blocks       = "${var.AllowedIngress}"
  description       = "Allowed Networks"
}

resource "aws_security_group_rule" "elb_to_asg_egress" {
  security_group_id        = "${aws_security_group.sg_netbox_elb.id}"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  type                     = "egress"
  source_security_group_id = "${aws_security_group.sg_netbox_asg.id}"
  description              = "ELB to ASG"
}

resource "aws_security_group" "sg_netbox_rds" {
  name   = "sg_netbox_rds"
  vpc_id = "${var.VPCId}"

  tags {
    Name = "sg_netbox_rds"
  }
}

resource "aws_security_group_rule" "asg_to_rds_ingresss" {
  security_group_id        = "${aws_security_group.sg_netbox_rds.id}"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  type                     = "ingress"
  source_security_group_id = "${aws_security_group.sg_netbox_asg.id}"
  description              = "ASG to RDS"
}

resource "aws_lb" "netbox" {
  name               = "netbox"
  internal           = false
  load_balancer_type = "application"
  subnets            = ["${var.PublicSubnets}"]
  security_groups    = ["${aws_security_group.sg_netbox_elb.id}"]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "netbox" {
  name                 = "netbox"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = "${var.VPCId}"
  deregistration_delay = "30"

  health_check {
    path = "/api/"
  }
}

resource "aws_lb_listener" "netbox" {
  load_balancer_arn = "${aws_lb.netbox.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${var.SSLCertificate}"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.netbox.arn}"
  }
}

resource "aws_db_subnet_group" "netbox" {
  name       = "netbox"
  subnet_ids = "${var.DatabaseSubnets}"
}

resource "aws_db_instance" "netbox" {
  allocated_storage       = "${var.DBAllocatedStorage}"
  storage_type            = "gp2"
  engine                  = "postgres"
  engine_version          = "9.6.10"
  identifier_prefix       = "netbox-"
  instance_class          = "${var.DBClass}"
  name                    = "${var.DBName}"
  username                = "${var.DBUsername}"
  password                = "${data.aws_ssm_parameter.netbox_db_pass.value}"
  multi_az                = "${var.MultiAZ}"
  backup_retention_period = "${var.BackupRetentionPeriod}"
  skip_final_snapshot     = true
  apply_immediately       = true
  deletion_protection     = false
  storage_encrypted       = true
  kms_key_id              = "${var.KMSKeyId}"
  vpc_security_group_ids  = ["${aws_security_group.sg_netbox_rds.id}"]
  db_subnet_group_name    = "${aws_db_subnet_group.netbox.name}"
}

resource "aws_ssm_parameter" "netbox" {
  name  = "/netbox_core/db_host_${var.Environment}"
  type  = "String"
  value = "${aws_db_instance.netbox.address}"
}

output "elb-dns" {
  value = "${aws_lb.netbox.dns_name}"
}
