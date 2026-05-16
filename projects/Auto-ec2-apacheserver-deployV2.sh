#!/bin/bash

##################################################################################
# author - Harsh yadav (hashwithharsh)
# date - 12 may 2026
# details -
# install aws cli -> check aws config -> create key pair ->
# create/reuse security group -> create ec2 ->
# show ec2 details -> auto deploy website on ec2
##################################################################################

# =========================================
# ASK INSTANCE NAME
# =========================================

read -p "enter ec2 instance name: " USER_INSTANCE_NAME

if [ -z "$USER_INSTANCE_NAME" ]
then
    INSTANCE_NAME="MyWebsiteServer"
else
    INSTANCE_NAME=$USER_INSTANCE_NAME
fi

# =========================================
# EC2 CONFIG
# =========================================

AWS_REGION="ap-south-1"
AMI_ID="ami-07a00cf47dbbc844c"
INSTANCE_TYPE="t3.micro"
KEY_NAME="harsh-ec2key"
SECURITY_GROUP="website-securitygroup"

# =========================================
# INSTALL AWS CLI
# =========================================

echo ""
echo "installing awscli..."

sudo dnf install awscli -y

# =========================================
# CHECK AWS CONFIG
# =========================================

echo ""
echo "checking aws configuration..."

aws sts get-caller-identity > /dev/null 2>&1

if [ $? -ne 0 ]
then
    echo ""
    echo "aws cli not configured"
    echo "starting aws configure..."
    echo ""

    aws configure
else
    echo ""
    echo "aws cli already configured"
fi

# =========================================
# DELETE OLD KEYPAIR
# =========================================

echo ""
echo "checking old keypair..."

aws ec2 delete-key-pair \
--key-name $KEY_NAME \
--region $AWS_REGION > /dev/null 2>&1

rm -f ${KEY_NAME}.pem

# =========================================
# CREATE KEYPAIR
# =========================================

echo ""
echo "creating key pair..."

aws ec2 create-key-pair \
--region $AWS_REGION \
--key-name $KEY_NAME \
--query 'KeyMaterial' \
--output text > ${KEY_NAME}.pem

chmod 400 ${KEY_NAME}.pem

echo ""
echo "pem key downloaded:"
echo "$(pwd)/${KEY_NAME}.pem"

# =========================================
# CREATE OR USE SECURITY GROUP
# =========================================

echo ""
echo "checking security group..."

SG_ID=$(aws ec2 describe-security-groups \
--region $AWS_REGION \
--group-names $SECURITY_GROUP \
--query 'SecurityGroups[0].GroupId' \
--output text 2>/dev/null)

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]
then
    echo ""
    echo "security group not found"
    echo "creating security group..."

    SG_ID=$(aws ec2 create-security-group \
    --group-name $SECURITY_GROUP \
    --description "security group for website" \
    --region $AWS_REGION \
    --query 'GroupId' \
    --output text)

    echo "security group created: $SG_ID"

    echo ""
    echo "adding inbound rules..."

    # SSH
    aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION

    # HTTP
    aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION

    # HTTPS
    aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION

else
    echo ""
    echo "security group already exists"
    echo "using existing security group: $SG_ID"
fi

# =========================================
# CREATE EC2 INSTANCE
# =========================================

echo ""
echo "creating ec2 instance..."

INSTANCE_ID=$(aws ec2 run-instances \
--region $AWS_REGION \
--image-id $AMI_ID \
--count 1 \
--instance-type $INSTANCE_TYPE \
--key-name $KEY_NAME \
--security-group-ids $SG_ID \
--tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
--query 'Instances[0].InstanceId' \
--output text)

echo ""
echo "instance created successfully"
echo "instance id : $INSTANCE_ID"

# =========================================
# WAIT FOR INSTANCE
# =========================================

echo ""
echo "waiting for instance to start..."

aws ec2 wait instance-running \
--region $AWS_REGION \
--instance-ids $INSTANCE_ID

# =========================================
# WAIT FOR PUBLIC IP
# =========================================

echo ""
echo "waiting for public ip..."

sleep 20

PUBLIC_IP=$(aws ec2 describe-instances \
--instance-ids $INSTANCE_ID \
--region $AWS_REGION \
--query "Reservations[0].Instances[0].PublicIpAddress" \
--output text)

# =========================================
# SHOW INSTANCE DETAILS
# =========================================

echo ""
echo "===================================="
echo "NEW INSTANCE DETAILS"
echo "===================================="

echo "instance name : $INSTANCE_NAME"
echo "instance id   : $INSTANCE_ID"
echo "public ip     : $PUBLIC_IP"
echo "region        : $AWS_REGION"

# =========================================
# SHOW ALL EC2 INSTANCES
# =========================================

echo ""
echo "===================================="
echo "ALL EC2 INSTANCES"
echo "===================================="

aws ec2 describe-instances \
--region $AWS_REGION \
--query 'Reservations[*].Instances[*].[Tags[0].Value,InstanceId,State.Name,PublicIpAddress]' \
--output table

# =========================================
# WAIT FOR SSH
# =========================================

echo ""
echo "waiting for ssh service..."

sleep 40

# =========================================
# DEPLOY WEBSITE ON EC2
# =========================================

echo ""
echo "===================================="
echo "DEPLOYING WEBSITE ON EC2"
echo "===================================="

echo "installing apache server"
echo ""
echo "starting apache service and enabling it"
echo ""
echo "navigating into /var/www/html path on Ec2 server"
echo ""
echo "git cloning started cloning hashwithharsh_repo"
echo ""


# << EOF is for running multiple commands on server remotely untill EOF hits ( EOF End )..
# StricthostKeyChecking=no is used to eliminate the confirmation prompt after ssh into server like do you wants to continue...
ssh -o StrictHostKeyChecking=no -i ${KEY_NAME}.pem ubuntu@${PUBLIC_IP} << EOF

sudo apt update -y

sudo apt install apache2 git -y

sudo systemctl start apache2
sudo systemctl enable apache2

cd /var/www/html

sudo rm -rf *

sudo git clone https://github.com/hashwithharsh/hashwithharsh.github.io.git

sudo mv hashwithharsh.github.io/* .

sudo rm -rf hashwithharsh.github.io

sudo systemctl restart apache2

EOF

# =========================================
# FINAL OUTPUT
# =========================================

echo ""
echo "===================================="
echo "WEBSITE DEPLOYED SUCCESSFULLY"
echo "===================================="

echo ""
echo "website url:"
echo "http://${PUBLIC_IP}"

echo ""
echo "ssh command:"
echo "ssh -i ${KEY_NAME}.pem ubuntu@${PUBLIC_IP}"
