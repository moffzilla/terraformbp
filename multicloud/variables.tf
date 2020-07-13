variable "vm_name" {
  description = "VM Name"
  default     = "myVM"
}

variable "myTag" {
  description = "My Default Tag"
  default = "terraform-test"
}

variable "instance_type" {
  description = "AWS instance type"
  default     = "t2.micro"
}

