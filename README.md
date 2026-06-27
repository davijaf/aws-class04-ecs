# class04_task02 — Containerização + ECR + ECS Fargate (Spring Boot na AWS)

[![Java](https://img.shields.io/badge/Java-21-007396?logo=openjdk&logoColor=white)](https://openjdk.org/projects/jdk/21/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.5-6DB33F?logo=springboot&logoColor=white)](https://spring.io/projects/spring-boot)
[![Docker](https://img.shields.io/badge/Docker-eclipse--temurin%3A21--jre-2496ED?logo=docker&logoColor=white)](https://hub.docker.com/_/eclipse-temurin)
![AWS](https://img.shields.io/badge/AWS-ECR%20%7C%20ECS%20Fargate%20%7C%20ALB-FF9900?logo=amazonaws&logoColor=white)

Lab do treinamento **Assurance — Java → AWS**. API REST mínima em **Spring Boot 3 / Java 21**, **containerizada com Docker**, publicada no **Amazon ECR** (tags imutáveis) e implantada de duas formas: **Docker direto numa EC2** e **ECS Fargate atrás de um ALB**. O endpoint **`/health` mostra a tag/versão deployada**.

> Derivado de `RobertoMVB/aws-class` (branch `develop`), **enxugado para SQS/SNS + health** (removidos RDS/S3/DynamoDB) para focar no fluxo **containerização → registry → deploy**.

## Stack
- **Java 21**, **Spring Boot 3.5** (Web, Actuator)
- **AWS SDK v2** (SQS, SNS)
- **Docker** (`eclipse-temurin:21-jre`) → **Amazon ECR** (IMMUTABLE) → **EC2** / **ECS Fargate + ALB**

## Endpoints
| Método | Rota | Descrição |
|---|---|---|
| GET | `/health` | `{"status":"UP","tag":"<tag>","timestamp":...}` — **tag = versão deployada** |
| GET | `/actuator/health` | health (Spring Actuator) |

A **tag** vem da env `APP_TAG`, *baked* na imagem no build (`--build-arg APP_TAG`) — cada deploy fica rastreável pelo `/health`.

## Configuração (infra/segredos fora do código)
Dados da sua conta (account id, IP da EC2, chave SSH, security group) ficam no **`.env`** (gitignored). Os scripts `deploy-*.sh` leem dele:
```bash
cp .env.example .env   # e preencha
```

## Build local
```bash
mvn clean package -DskipTests
docker build --platform linux/amd64 --build-arg APP_TAG=dev -t minha-api:dev .
docker run --rm -p 8081:8080 minha-api:dev
curl http://localhost:8081/health     # {"status":"UP","tag":"dev",...}
```

## Deploy (scripts)
```bash
./deploy-ecr.sh <tag>     # build -> push ECR -> pull+run na EC2 (porta 8080)
./deploy-ecs.sh <tag>     # task definition + service ECS Fargate (imagem ja no ECR)
```
> O repositório ECR é **IMMUTABLE** → use uma **tag NOVA** a cada deploy (`v1`, `v2`, `4.0.0-latest`, …). O `/health` reflete a tag no ar.

## Estrutura
```
src/main/java/com/aws/class3/
├── Class3Application.java
├── health/controller/HealthController    # GET /health (status + tag)
├── sns/  (config · controller · service) # AWS SDK SNS
└── sqs/  (config · controller · service) # AWS SDK SQS
Dockerfile · .dockerignore
deploy-ecr.sh · deploy-ecs.sh · .env.example
```

---

## Setup passo a passo (notas)
> Notas de referência do lab (comandos genéricos / placeholders).

### Instalar Docker na EC2 (Ubuntu)
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg
sudo mkdir -p /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
docker --version
sudo usermod -aG docker $USER     # rodar docker sem sudo (relogar depois)
docker login
```

### Dockerfile (versão das notas)
> O `Dockerfile` commitado neste repo usa **`eclipse-temurin:21-jre`** (imagem menor, melhor pra t3.micro). A versão das notas:
```dockerfile
FROM eclipse-temurin:21-jdk
WORKDIR /app
COPY target/class3-0.0.1-SNAPSHOT.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-Xms512m", "-Xmx1536m", "-jar", "app.jar"]
```

### Instalar AWS CLI na EC2
```bash
sudo apt update && sudo apt install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip ./aws
aws --version
aws sts get-caller-identity        # confirma o usuario autenticado
aws configure list
aws configure set region <sua-regiao>   # se a regiao nao aparecer
```

### Compilar + build + push pro ECR
```bash
mvn clean package
docker buildx build --platform linux/amd64 -t <SUA-TAG> .
docker tag <SUA-TAG>:latest <ENDERECO-ECR>
aws ecr get-login-password --region <SUA-REGIAO> | docker login --username AWS --password-stdin <ENDERECO-ECR>
docker push <ENDERECO-ECR>:latest
```

---
> ⚠️ **Lab AWS — custo:** ECR, ECS Fargate, EC2 e ALB geram custo contínuo. Ao encerrar: remover service/cluster ECS, ALB + target group, parar a EC2 e `aws ecr delete-repository --force`.
