#!/bin/bash

# This script assumes that Session Manager Plugin for the AWS CLI is already installed
# https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html#install-plugin-verify


# ./ec2-ssh.sh d2d-drt-devel drt-server-dev
# $1 is an AWS profile
# $2 is the name of the application (EC2 tag)

if [ -z "$1" ] || [ -z "$2" ]
then
  echo "Example use: " \
       "./ec2-ssh.sh d2d-drt-devel drt-server-dev"
  echo "> Argument 1: '$1' is an AWS profile"
  echo "> Argument 2: '$2' is the name of the application (EC2 tag)"
  exit 0
fi

INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$2" --profile=$1 --region=eu-central-1 | jq '.Reservations[0].Instances[0].InstanceId')

echo "Instance ID: $INSTANCE_ID"

if [ -z "$INSTANCE_ID" ]
then
  echo "No EC2 instaces exist with $2 name"
  exit 0
else
  echo "Run in your terminal:"
  echo "aws ssm start-session --target $INSTANCE_ID --profile $1 --region eu-central-1"
fi
