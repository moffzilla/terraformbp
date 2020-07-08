provider "aws" {
    version = "~> 2.0"
    region="us-east-1"
}

variable "instance_type" {
  description = "AWS instance type"
  default     = "t2.micro"
}

variable "department" {
  description = "Department tag"
}

resource "random_string" "random" {
    length = 16
    special = true
    override_special = "/@£$"

    provisioner "local-exec" {
       command = "echo sleeping for 10 mins; sleep 600; echo slept"
    }
}

resource "aws_instance" "machine1" {
    depends_on = [
        random_string.random,
       ]
    ami           = "ami-04b9e92b5572fa0d1"
    instance_type = "t2.micro"
    availability_zone = "us-east-1b"
}