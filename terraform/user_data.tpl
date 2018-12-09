#!/usr/bin/env bash
version="${Version}"
echo "127.0.0.1 $(hostname)" >> /etc/hosts
timedatectl set-timezone America/Los_Angeles
apt-get update -y
apt-get install -y build-essential checkinstall
apt-get install -y libreadline-gplv2-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev
apt-get install -y python3-pip unzip
pip3 install --upgrade pip
/usr/local/bin/pip3 install awscli
/usr/local/bin/pip3 install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz
aws s3 cp --region ${Region} s3://${S3Bucket}/ /home/ubuntu/ --recursive
unzip -o /home/ubuntu/netbox-build.zip -d /home/ubuntu/
/usr/local/bin/pip3 install ansible
/usr/local/bin/pip3 install botocore
/usr/local/bin/pip3 install boto3
mkdir /etc/ansible
mv /home/ubuntu/ansible.cfg /etc/ansible/ansible.cfg
/usr/local/bin/ansible-playbook -i /home/ubuntu/inventory/${Environment}/hosts -c local /home/ubuntu/playbooks/bootstrap.yml --extra-vars "env=${Environment}"