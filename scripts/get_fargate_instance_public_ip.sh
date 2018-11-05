#!/bin/bash
#####
# Example:
# /bin/bash ./get_fargate_instance_public_ip.sh $( terraform output file_management_api_fargate_cluster )

ecs_cluster=$1

fargate_task_arn=$(aws ecs list-tasks --cluster $ecs_cluster --query "taskArns[0]" | awk -F'/' '{ print $2 }' | cut -d\" -f1)

fargate_task_eni=$(aws ecs describe-tasks --cluster $ecs_cluster --tasks $fargate_task_arn --query "tasks[0].attachments[0].details[1].value"| cut -d\" -f2)

public_ip=$(aws ec2 describe-network-interfaces --network-interface-ids $fargate_task_eni \
	--query "NetworkInterfaces[0].Association.PublicIp" | cut -d\" -f2)

echo "API Endpoint: http://$public_ip:5000"
