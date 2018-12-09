# aws-netbox-deployment
Code for deploying Netbox into AWS

# Summary
The code contained in this repo support deploying the Netbox IPAM service into AWS on EC2 instances. The infrastructure automation is driven by Terraform while the configuration of the EC2 instances is performed by Ansible. These instances are configured to "self-instanstiate" by calling Ansible with user data.

# Installation
1) Create a new environment directory inside inventory following a similar pattern to the sample provided.
* The following variables are required inisde your inventory/{environment}/group_vars/all.yml file:

| Attribute  | Description |
| ------------- | ------------- |
| netbox_version  | Netbox version to be deployed  |
| db_name  | Database name  |
| db_user  | Database user  |
| region  | Region  |
| server_name  | Server Name  |
| AUTH_LDAP_USER_SEARCH_BASEDN  | LDAP User Search BaseDN  |
| AUTH_LDAP_GROUP_SEARCH_BASEDN  | LDAP Group Search BaseDN  |
| active_groups  | LDAP Groups allowed access |
| staff_group  | LDAP Group with staff access  |

2) Create a new {environment}.tfvars file inside the terraform directory following a similar pattern to the sample provided.
* The following variables are required inside your terraform/{environment}.tfvars file:

| Attribute  | Description |
| ------------- | ------------- |
| AMI  | AMI for the Netbox EC2 instances  |
| KeyName  | KMS Key for the Netbox EC2 instances  |
| PrivateSubnets  | List of private subnets for the Netbox EC2 instances  |
| PublicSubnets  | List of public subnets for the Load Balancers  |
| DatabaseSubnets  | List of database subnets  |
| Environment  | Environment this application is in  |
| SSLCertificate  | SSL Certificate used by the Load Balancer  |
| VPCId  | Id of the VPC this application is deployed in |
| DBName  | Name of the netbox database  |
| DBUsername  | Username for the netbox database  |
| DBClass  | Instance type for the database  |
| DBAllocatedStorage  | Amount of storage allocated to the database  |
| MultiAZ  | Boolean value indicating whether this should use MutliAZ for HA  |
| BackupRetentionPeriod  | Length of time to retain backups  |
| S3Bucket  | S3 Bucket used for storing the artifact  |
| InstanceType  | EC2 instance type used for the Netbox application  |
| KMSKeyId  | Id of the KMS Key  |
| DomainControllers  | List of domain controllers the application should use for LDAP and DNS  |
| AllowedIngress | List of subnets allowed to access to the Netbox ELB |
| Account | Id of your AWS account |
| Region | Region the application will be deployed in |


3) Add parameters to parameter store
```bash
aws ssm put-parameter --name "/netbox/user" --type "String" --value "netbox-admin"
aws ssm put-parameter --name "/netbox/email" --type "String" --value "netbox-admin@sample.com"
aws ssm put-parameter --name "/netbox/pass" --type "SecureString" --value 'abcde12345'
aws ssm put-parameter --name "/netbox/db_pass" --type "SecureString" --value 'abcde12345'
aws ssm put-parameter --name "/netbox/secret_key" --type "SecureString" --value 'abcdefghijklmnopqrstuvwxyz1234567890'
```

4) Create S3 Bucket to store artifact
```bash
aws s3api create-bucket --bucket aws-netbox-deployment-sample --region us-west-2
```

5) Create artifact and upload to S3 Bucket
```bash
zip build.zip -r inventory playbooks roles ansible.cfg requirements.txt
aws s3 cp build.zip s3://aws-netbox-deployment-sample/
```

4) Using Terraform, deploy into AWS
```bash
export AWS_ACCESS_KEY_ID="SAMPLEACCESSKEY"
export AWS_SECRET_ACCESS_KEY="SAMPLESECRETACCESSKEY"
export AWS_REGION="us-west-2"
terraform init
terraform plan --var-file="sample.tfvars"
terraform apply --var-file="sample.tfvars"
```
