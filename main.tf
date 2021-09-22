provider "aws" {
  profile = var.aws_profile
  region  = var.region
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

data "aws_vpc" "default" {}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

# ------ SECURITY GROUPS ------

#Employee Security Group

resource "aws_security_group" "employee_sg" {
  name        = "employee_sg"
  description = "Used for employee access from jump to jenkins, dev, and prod"
  vpc_id      = "${data.aws_vpc.default.id}"

  #SSH

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    
    cidr_blocks = ["172.31.0.0/16", "${var.localip}"]
  }

  #FTP
  ingress {
    from_port	= 0
    to_port 	= 0
    protocol	= "-1"
    cidr_blocks = ["172.31.0.0/16", "${var.jenkins_ip}"]
  }

  ingress {
    from_port	= 1024
    to_port	= 1048
    protocol	= "tcp"
    cidr_blocks = ["172.31.0.0/16", "${var.jenkins_ip}"]
  }

  #HTTP
  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "employee_sg"
  }
}

#Customer Security Group
resource "aws_security_group" "customer_sg" {
  name        = "customer_sg"
  description = "Used for customer web access to dev and prod machines"
  vpc_id      = "${aws_default_vpc.default.id}"

  #SSH

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    security_groups = [aws_security_group.jump_sg.id]
  }

  #HTTP

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "customer_sg"
  }
}


#Jump Security Group

resource "aws_security_group" "jump_sg" {
  name        = "jump_sg"
  description = "Used for access to jump instance"
  vpc_id      = "${aws_default_vpc.default.id}"

  #SSH

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.localip}"]
  }

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jump_sg"
  }
}

# ------ EC2 INSTANCES -------

#key pair

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

#Null resource to write hosts to ansible inventory

resource "null_resource" "run-playbook" {
  provisioner "local-exec" {
    command = <<EOD
cat <<EOF > aws_hosts
[apache]
dev ansible_host=${aws_instance.dev.public_ip}
prod ansible_host=${aws_instance.prod.public_ip}
EOF
EOD
  }

  provisioner "local-exec" {
    command = "aws ec2 wait instance-status-ok --instance-ids ${aws_instance.dev.id} ${aws_instance.prod.id} && ansible-playbook -i aws_hosts web.yml"
  }
}

#jenkins EC2 Instance

resource "aws_instance" "jenkins" {
  ami             = "${var.jenkins_ami}"
  instance_type   = "${var.jenkins_instance_type}"
  security_groups = ["${aws_security_group.employee_sg.name}"]

  tags = {
    Name = "jenkins"
  }

  key_name = "${aws_key_pair.auth.id}"
}

#Jump EC2 Instance

resource "aws_instance" "jump" {
  ami             = "${var.jump_ami}"
  instance_type   = "${var.jump_instance_type}"
  security_groups = ["${aws_security_group.jump_sg.name}", "${aws_security_group.employee_sg.name}"]

  tags = {
    Name = "jump"
  }

  key_name = "${aws_key_pair.auth.id}"
}

#Dev EC2 Instance

resource "aws_instance" "dev" {
  ami             = "${var.dev_ami}"
  instance_type   = "${var.dev_instance_type}"
  security_groups = ["${aws_security_group.employee_sg.name}"]

  tags = {
    Name = "dev"
  }

  key_name = "${aws_key_pair.auth.id}"
}

#Prod EC2 Instance                                                                                                     

resource "aws_instance" "prod" {
  ami             = "${var.prod_ami}"
  instance_type   = "${var.prod_instance_type}"
  security_groups = ["${aws_security_group.employee_sg.name}"]

  tags = {
    Name = "prod"
  }

  key_name = "${aws_key_pair.auth.id}"
}
