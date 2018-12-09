variable "AMI" {}
variable "KeyName" {}

variable "PrivateSubnets" {
  type = "list"
}

variable "PublicSubnets" {
  type = "list"
}

variable "DatabaseSubnets" {
  type = "list"
}

variable "Environment" {}
variable "SSLCertificate" {}
variable "VPCId" {}
variable "DBName" {}
variable "DBUsername" {}
variable "DBClass" {}
variable "DBAllocatedStorage" {}
variable "MultiAZ" {}
variable "BackupRetentionPeriod" {}
variable "S3Bucket" {}
variable "InstanceType" {}
variable "KMSKeyId" {}

variable "Region" {}

variable "Account" {}

variable "DomainControllers" {
  type = "list"
}

variable "AllowedIngress" {
  type        = "list"
  default     = "${var.AllowedIngress}"
  description = "List of hosts allowed to communicate with the Netbox ELB"
}
