# WebServer on AWS project enabled using Terraform Code for Automation
# Developer: RAHUL PANDA (https://www.linkedin.com/in/rahulpanda/)

/*
Letting Terraform know the type of Provider, i.e. AWS
Using AWS profile - named "rahul" instead of directly using the id and key
The profile was pre-configured on workstation with command "aws configure --profile rahul"
*/
provider "aws" {
	region="ap-south-1"
	profile="rahul"
}

/*
Creating an EC2 instance by declaring AMI ID, Instance Type, Key name and Security Group
"mywebserver" is a pre-defined security_groups with configured inbound and outbound rules
*/
resource "aws_instance" "webserverdemo1" {
	ami = "ami-0447a12f28fddb066"
	instance_type = "t2.micro"
	key_name = "mypemkey"
	security_groups = [ "mywebserver" ]

	#Connecting using SSH protocol to AWS instance with configured Key file
	connection {
		type = "ssh"
		user = "ec2-user"
		private_key = file("D:/Documents/AWS/root_user/secure_key/mypemkey.pem")
		host = aws_instance.webserverdemo1.public_ip
	}

	#Installing requisite OS packages
	provisioner "remote-exec" {
		inline = [
		"sudo yum install httpd php git -y",
		"sudo systemctl start httpd",
		"sudo systemctl enable httpd"
		]
	}

	tags = {
		Name = "webserverdemo1"
	}
}	

/* 
Creating an EBS volume of size 1GB
The EBS is created in the same availability_zone as that of the previously created EC2 instance
*/
resource "aws_ebs_volume" "webserver_ebs_vol" {
  availability_zone = aws_instance.webserverdemo1.availability_zone
  size              = 1
  tags = {
    Name = "webebsvol1"
  }
}

/*
This resource allows to attach or dettach volumes from AWS
*/
resource "aws_volume_attachment" "ebs_att_det" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.webserver_ebs_vol.id}"
  instance_id = "${aws_instance.webserverdemo1.id}"
  force_detach = true
}

/*
Printing Public IP Address on screen for reference
*/
output "ipaddress" {
  value = aws_instance.webserverdemo1.public_ip
}

/*
Attaching the EBS instance to EC2 instance
Mounting the storage to path /var/www/html
Downloading webserver files from GitHub and placing them in /var/www/html
*/
resource "null_resource" "remote_att_ebs"  {

	depends_on = [
		aws_volume_attachment.ebs_att_det,
	]


	connection {
		type     = "ssh"
		user     = "ec2-user"
		private_key = file("D:/Documents/AWS/root_user/secure_key/mypemkey.pem")
		host     = aws_instance.webserverdemo1.public_ip
	}

	provisioner "remote-exec" {
		inline = [
		"sudo mkfs.ext4  /dev/xvdh",
		"sudo mount  /dev/xvdh  /var/www/html",
		"sudo rm -rf /var/www/html/*",
		"sudo git clone https://github.com/rahulpanda95/server_stats.git /var/www/html"
		]
	}
}

/*
	Opening the WebServer Page on Local System Chrome Browser
*/
resource "null_resource" "local_browser"  {
	depends_on = [
		null_resource.remote_att_ebs,
	]

		provisioner "local-exec" {
			command = "chrome  ${aws_instance.webserverdemo1.public_ip}"
		}
}