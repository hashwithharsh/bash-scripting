#!/bin/bash

##################################################################################
# author - Harsh yadav (hashwithharsh)
# date - 12 may 2026
# details - to check all ec2 instance information.
##################################################################################

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
# SHOW ALL EC2 INSTANCES
# =========================================

echo ""
echo "===================================="
echo "ALL EC2 INSTANCES"
echo "===================================="

aws ec2 describe-instances \
--region $AWS_REGION \
--query 'Reservations[*].Instances[*].[Tags[0].Value,InstanceId,State.Name,PublicIpAddress,SecurityGroups[*].groupname]' \
--output table

echo "Ec2-instance scanning complete... Thanks for using this script"
