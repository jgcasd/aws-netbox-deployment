AMI = "ami-01234sample"

KeyName = "netbox"

PrivateSubnets = ["subnet-01234sample", "subnet-01234sample", "subnet-01234sample"]

PublicSubnets = ["subnet-01234sample", "subnet-01234sample", "subnet-01234sample"]

DatabaseSubnets = ["subnet-01234sample", "subnet-01234sample", "subnet-01234sample"]

Environment = "dev"

SSLCertificate = "arn:aws:acm:us-west-2:01234567890:certificate/01234sample"

VPCId = "vpc-01234sample"

DBName = "netbox"

DBUsername = "netbox"

DBClass = "db.t2.small"

DBAllocatedStorage = "20"

MultiAZ = "true"

BackupRetentionPeriod = "7"

S3Bucket = "aws-netbox-deployment-sample"

InstanceType = "t3.micro"

KMSKeyId = "arn:aws:kms:us-west-2:01234567890:key/01234sample"

DomainControllers = ["0.0.0.0/0"]

AllowedIngress = ["0.0.0.0/0"]

Region = "us-west-2"

Account = "01234567890"
