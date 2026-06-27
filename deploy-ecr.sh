#!/usr/bin/env bash
# Pipeline: build -> ECR (IMMUTABLE) -> push -> deploy na EC2 (pull via instance role)
# Projeto enxuto (so SQS/SNS + health) -> roda com o instance role, SEM banco.
# A tag e "baked" na imagem (--build-arg APP_TAG) e aparece em GET /health.
#
# Config sensivel (account/IP/chave) vem do .env (gitignored) -> copie de .env.example.
# PRE-REQUISITOS (IAM): ec2-user com ECR FullAccess; role da EC2 com ECR ReadOnly; Docker Desktop aberto.
#
# Uso:  ./deploy-ecr.sh [TAG]   (default v1; repo IMMUTABLE -> use TAG NOVA a cada push)
set -euo pipefail

[ -f .env ] && { set -a; . ./.env; set +a; }
: "${ACCOUNT:?defina ACCOUNT no .env (cp .env.example .env)}"
REGION="${REGION:-us-east-2}"
REPO=class04_part02
TAG="${1:-v1}"
IMAGE_LOCAL="minha-api:${TAG}"
REGISTRY="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"
ECR_IMAGE="${REGISTRY}/${REPO}:${TAG}"
: "${EC2_HOST:?defina EC2_HOST no .env}"
EC2_USER="${EC2_USER:-ubuntu}"
: "${EC2_KEY:?defina EC2_KEY no .env}"
EC2_KEY="${EC2_KEY/#\~/$HOME}"

echo "==> 1) empacotar + buildar imagem (${IMAGE_LOCAL}, APP_TAG=${TAG})"
mvn clean package -DskipTests
docker build --platform linux/amd64 --build-arg APP_TAG="${TAG}" -t "${IMAGE_LOCAL}" .

echo "==> 2) garantir repo ECR IMMUTABLE (${REPO})"
aws ecr describe-repositories --repository-names "${REPO}" --region "${REGION}" >/dev/null 2>&1 \
  || aws ecr create-repository --repository-name "${REPO}" \
       --image-tag-mutability IMMUTABLE \
       --image-scanning-configuration scanOnPush=true \
       --region "${REGION}"

echo "==> 3) login + tag + push (${ECR_IMAGE})"
aws ecr get-login-password --region "${REGION}" \
  | docker login --username AWS --password-stdin "${REGISTRY}"
docker tag "${IMAGE_LOCAL}" "${ECR_IMAGE}"
docker push "${ECR_IMAGE}"

echo "==> 4) deploy na EC2 (pull via instance role + run na 8080)"
ssh -i "${EC2_KEY}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "${EC2_USER}@${EC2_HOST}" \
    REGISTRY="${REGISTRY}" REGION="${REGION}" ECR_IMAGE="${ECR_IMAGE}" bash -s <<'REMOTE'
  set -e
  aws ecr get-login-password --region "$REGION" | sudo docker login --username AWS --password-stdin "$REGISTRY"
  sudo docker pull "$ECR_IMAGE"
  sudo docker rm -f class04 2>/dev/null || true
  sudo docker run -d --name class04 --restart unless-stopped -p 8080:8080 \
    -e AWS_REGION="$REGION" \
    -e JAVA_TOOL_OPTIONS="-Xmx256m" \
    "$ECR_IMAGE"
  sudo docker ps --filter name=class04 --format "rodando: {{.Image}} ({{.Status}})"
REMOTE

echo ""
echo "==> OK. Teste:  curl http://${EC2_HOST}:8080/health   (deve mostrar a tag deployada)"
