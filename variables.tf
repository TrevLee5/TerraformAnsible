
variable "aws_profile" {}
variable "region" {
  default = "us-east-1"
}
variable "localip" {}
variable "jump_ip" {}
variable "jenkins_ip" {}
variable "public_key_path" {}
variable "key_name" {}
variable "jenkins_ami" {}
variable "jenkins_instance_type" {}
variable "jump_instance_type" {}
variable "jump_ami" {}
variable "dev_ami" {}
variable "dev_instance_type" {}
variable "prod_ami" {}
variable "prod_instance_type" {}
