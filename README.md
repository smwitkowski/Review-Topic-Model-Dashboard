
aws ecs create-cluster --cluster-name fargate-cluster

aws ecs register-task-definition --cli-input-json file://example-task.json

aws ecs create-service --cluster fargate-cluster --service-name fargate-service --task-definition sample-fargate:1 --desired-count 1 --launch-type "FARGATE" --network-configuration "awsvpcConfiguration={subnets=[subnet-089ec97b46ddf7242],securityGroups=[sg-0fc07c7ff27f19268]}"

aws ecs create-service --cluster fargate-cluster --service-name fargate-service --task-definition sample-fargate:1 --desired-count 1 --launch-type "FARGATE" --network-configuration "awsvpcConfiguration={subnets=[subnet-089ec97b46ddf7242],securityGroups=[sg-0fc07c7ff27f19268],assignPublicIp=ENABLED}"

