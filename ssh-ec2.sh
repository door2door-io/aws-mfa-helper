#!/bin/bash

# This script assumes that Session Manager Plugin for the AWS CLI is already installed
# https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html#install-plugin-verify

# Script to establish an EC2 connection
# for bash users:
# $ echo "alias ssh-ec2=\"~/path-to-repository/ssh-ec2.sh\"" >> ~/.bash_profile
# for zsh users:
# $ echo "alias ssh-ec2=\"~/path-to-repository/ssh-ec2.sh\"" >> ~/.zshrc
if [ $# -ne 2 ]
  then
    echo -e "You must provide: \\n" \
        "  1) the application name, such as 'drt-server', 'drt-users', etc.\\n" \
        "  2) environment name, such as 'dev', 'staging', 'sandbox' and 'production'\\n\\n" \
        "Example usage: \\n" \
        "./ssh_ec2.sh drt-server staging"
    exit
fi

export APPLICATION=$1
export ENVIRONMENT=$2
REGION="eu-central-1"

case $ENVIRONMENT in
  dev)
    AWS_ACCOUNT="d2d-drt-devel"
    ;;
  staging)
    AWS_ACCOUNT="d2d-drt-staging"
    ;;

  sandbox)
    AWS_ACCOUNT="d2d-drt-sandbox"
    ;;
  production)
    AWS_ACCOUNT="d2d-drt-prod"
esac

GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
RESET_COLOR=`tput sgr0`

if [ -d "${AWS_ACCOUNT}" ]; then
    echo "No AWS account was found for environment: $ENVIRONMENT"
    exit 1
fi

echo "AWS account found: $AWS_ACCOUNT"

INSTANCES=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$APPLICATION-$ENVIRONMENT" "Name=instance-state-name,Values=running" --profile $AWS_ACCOUNT --region $REGION | jq '.Reservations[0].Instances[0]')

if [ "$INSTANCES" = "null" ]; then
    echo "No EC2 instance could be found for the application: $APPLICATION-$ENVIRONMENT"
    exit 1
fi

INSTANCES_ID=$INSTANCES | jq '.InstanceId'


INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$APPLICATION-$ENVIRONMENT" "Name=instance-state-name,Values=running" --profile $AWS_ACCOUNT --region $REGION | jq '.Reservations[0].Instances[0].InstanceId' | sed 's/"//g')

echo -e "Starting SSH session to application $APPLICATION-$ENVIRONMENT...\\n"

# Adjustment to fetch DBs for ECS applications
DB_APPLICATION=$(echo $APPLICATION | sed -e 's/\(ecs\-\)//g')

DB_INSTANCES=$(aws rds describe-db-instances --db-instance-identifier $DB_APPLICATION-pg-$ENVIRONMENT --profile $AWS_ACCOUNT --region $REGION | jq '.DBInstances[0]')
DB_HOST=$( jq '.Endpoint.Address' <<< "${DB_INSTANCES}" | sed 's/"//g')
DB_PORT=$( jq '.Endpoint.Port' <<< "${DB_INSTANCES}" )

if [[ ! "${DB_HOST}" ]]; then
  DB_CLUSTERS=$(aws rds describe-db-clusters --db-cluster-identifier $APPLICATION-pg-$ENVIRONMENT-cluster --profile $AWS_ACCOUNT --region $REGION | jq '.DBClusters[0]')
  DB_HOST=$( jq '.Endpoint' <<< "${DB_CLUSTERS}" | sed 's/"//g')
  DB_PORT=$( jq '.Port' <<< "${DB_CLUSTERS}" )
fi

if [[ "${DB_HOST}" ]]; then
  echo -e "If you want to access the database from this application follow these steps:\\n"

  echo -e "1. Install sudocat in the EC2 instance you are connecting to by executing"
  echo -e " ${GREEN}sudo yum install -y socat${RESET_COLOR} \\n"
  echo -e "2. Create a bidirectional byte stream from EC2 to RDS"
  echo -e " ${GREEN}sudo socat TCP-LISTEN:$DB_PORT,reuseaddr,fork TCP4:$DB_HOST:$DB_PORT${RESET_COLOR}\\n"
  echo -e "3. Open another tab in your terminal to create a tunnel to RDS and run the following command"
  echo -e "  ${GREEN}aws ssm start-session --target $INSTANCE_ID --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"$DB_PORT\"], \"localPortNumber\":[\"$DB_PORT\"]}' --profile $AWS_ACCOUNT${RESET_COLOR} --region $REGION \\n"
  echo -e "4. Now you can connect locally without the need of using the bastion host. As additional step, use localhost as host for the database. As an example for postgres:"
  echo -e " ${GREEN}psql -h localhost -p $DB_PORT -U <user> -d <database>${RESET_COLOR} \\n"
fi

# Use BI ECS application as jump host to connect with Redshift
if [[ $APPLICATION = 'ecs-redash' || $APPLICATION = 'ecs-airflow' ]]; then
   DB_CLUSTERS=$(aws redshift describe-clusters --profile $AWS_ACCOUNT --cluster-identifier redshift-$ENVIRONMENT --region $REGION | jq '.Clusters[0]')
   REDSHIFT_HOST=$( jq '.Endpoint.Address' <<< "${DB_CLUSTERS}" | sed 's/"//g')
   REDSHIFT_PORT=$( jq '.Endpoint.Port' <<< "${DB_CLUSTERS}" )
fi
if [[ "${REDSHIFT_HOST}" ]]; then
  echo -e "If you want to access the Redshift database from this application follow these steps:\\n"

  echo -e "1. Install sudocat in the EC2 instance you are connecting to by executing"
  echo -e " ${GREEN}sudo yum install -y socat${RESET_COLOR} \\n"
  echo -e "2. Create a bidirectional byte stream from EC2 to Redshift"
  echo -e " ${GREEN}sudo socat TCP-LISTEN:$REDSHIFT_PORT,reuseaddr,fork TCP4:$REDSHIFT_HOST:$REDSHIFT_PORT${RESET_COLOR}\\n"
  echo -e "3. Open another tab in your terminal to create a tunnel to Redshift and run the following command"
  echo -e " ${GREEN}aws ssm start-session --target $INSTANCE_ID --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"$REDSHIFT_PORT\"], \"localPortNumber\":[\"$REDSHIFT_PORT\"]}' --profile $AWS_ACCOUNT${RESET_COLOR} --region $REGION \\n"
  echo -e "4. Now you can connect locally without the need of using the bastion host. As additional step, use localhost as host for the database. As an example for postgres:"
  echo -e " ${GREEN}psql -h localhost -p $REDSHIFT_PORT -U <user> -d <database>${RESET_COLOR} \\n"
fi

# Use drt-srever application as jump host to connect to ActiveMQ
if [[ $APPLICATION = 'drt-server' ]]; then
   AMQ_BROKER=$(aws mq list-brokers --profile $AWS_ACCOUNT --region $REGION | jq '.BrokerSummaries[0].BrokerId' | sed 's/"//g')
   AMQ_PORT=8162
   AMQ_HOST="mq.eu-central-1.amazonaws.com"
fi
if [[ "${AMQ_BROKER}" ]]; then
  echo -e "If you want to access the ActiveMQ wb console follow these steps:\\n"

  echo -e "1. Install sudocat in the EC2 instance you are connecting to by executing"
  echo -e " ${GREEN}sudo yum install -y socat${RESET_COLOR} \\n"
  echo -e "2. Create a bidirectional byte stream from EC2 to ActiveMQ"
  echo -e " ${GREEN}sudo socat TCP-LISTEN:$AMQ_PORT,reuseaddr,fork TCP4:$AMQ_BROKER-1.$AMQ_HOST:$AMQ_PORT${RESET_COLOR}\\n"
  if [[ $ENVIRONMENT = 'production' ]]; then
      echo -e " ${YELLOW}every week, the connection swaps to the other URL, you have to try-and-repeat to figure out the correct one${RESET_COLOR}\\n"
      echo -e " ${YELLOW}sudo socat TCP-LISTEN:$AMQ_PORT,reuseaddr,fork TCP4:$AMQ_BROKER-2.$AMQ_HOST:$AMQ_PORT${RESET_COLOR}\\n"
  fi
  echo -e "3. Open another tab in your terminal to create a tunnel to ActiveMQ and run the following command"
  echo -e " ${GREEN}aws ssm start-session --target $INSTANCE_ID --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"$AMQ_PORT\"], \"localPortNumber\":[\"$AMQ_PORT\"]}' --profile $AWS_ACCOUNT${RESET_COLOR} --region $REGION \\n"
  echo -e "4. Now you can connect locally without the need of using the bastion host. Be sure to use HTTPS when connecting:"
  echo -e " ${GREEN}https://localhost:$AMQ_PORT${RESET_COLOR} \\n"
fi

aws ssm start-session --target $INSTANCE_ID --profile $AWS_ACCOUNT --region $REGION
