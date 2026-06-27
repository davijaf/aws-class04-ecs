#!/usr/bin/env bash
# Deploy no ECS Fargate da imagem class04_part02 (ja no ECR).
# Config sensivel (account/SG) vem do .env (gitignored) -> copie de .env.example.
#
# PRE-REQUISITOS (IAM, uma vez): role ecsTaskExecutionRole; ec2-user com iam:PassRole (ou AmazonECS_FullAccess).
# Ja provisionado: cluster class04-fargate, log group /ecs/class04-fargate, SG (8080), subnets publicas.
#
# Uso:  ./deploy-ecs.sh [TAG]    (default v3)
set -euo pipefail

[ -f .env ] && { set -a; . ./.env; set +a; }
: "${ACCOUNT:?defina ACCOUNT no .env (cp .env.example .env)}"
REGION="${REGION:-us-east-2}"
CLUSTER=class04-fargate
REPO=class04_part02
TAG="${1:-v3}"
IMAGE="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/${REPO}:${TAG}"
EXEC_ROLE="arn:aws:iam::${ACCOUNT}:role/ecsTaskExecutionRole"
LOG_GROUP=/ecs/class04-fargate
: "${SG:?defina SG (security group da task, porta 8080) no .env}"
FAMILY=class04-task
SERVICE=class04-svc

SUBNETS=$(aws ec2 describe-subnets --region "$REGION" \
  --filters "Name=default-for-az,Values=true" --query 'Subnets[].SubnetId' --output text | tr '\t' ',')

echo "==> 1) registrar task definition (${FAMILY} -> ${IMAGE})"
cat > /tmp/class04-taskdef.json <<JSON
{
  "family": "${FAMILY}",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "${EXEC_ROLE}",
  "containerDefinitions": [{
    "name": "class04",
    "image": "${IMAGE}",
    "essential": true,
    "portMappings": [{"containerPort": 8080, "protocol": "tcp"}],
    "environment": [{"name": "APP_TAG", "value": "${TAG}"}],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${LOG_GROUP}",
        "awslogs-region": "${REGION}",
        "awslogs-stream-prefix": "class04"
      }
    }
  }]
}
JSON
aws ecs register-task-definition --region "$REGION" \
  --cli-input-json "file:///tmp/class04-taskdef.json" \
  --query 'taskDefinition.taskDefinitionArn' --output text

echo "==> 2) criar/atualizar service Fargate (${SERVICE}, desired=1, IP publico)"
NETCFG="awsvpcConfiguration={subnets=[${SUBNETS}],securityGroups=[${SG}],assignPublicIp=ENABLED}"
if aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" --region "$REGION" \
     --query 'services[0].status' --output text 2>/dev/null | grep -q ACTIVE; then
  aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" \
    --task-definition "$FAMILY" --force-new-deployment --region "$REGION" \
    --query 'service.serviceName' --output text
else
  aws ecs create-service --cluster "$CLUSTER" --service-name "$SERVICE" \
    --task-definition "$FAMILY" --desired-count 1 --launch-type FARGATE \
    --network-configuration "$NETCFG" --region "$REGION" \
    --query 'service.serviceName' --output text
fi

echo "==> 3) aguardando service estabilizar (Fargate puxa a imagem + sobe)..."
aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE" --region "$REGION"

echo "==> 4) descobrindo IP publico da task"
TASK=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE" --region "$REGION" --query 'taskArns[0]' --output text)
ENI=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK" --region "$REGION" \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
IP=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI" --region "$REGION" \
  --query 'NetworkInterfaces[0].Association.PublicIp' --output text)

echo ""
echo "==> OK. Task ECS Fargate no ar:"
echo "    curl http://${IP}:8080/health    (deve mostrar \"tag\":\"${TAG}\")"
