# Terraform GCP Deployment Guide

Este diretório contém a infraestrutura como código (IaC) para deploy da aplicação MQTT over WebSocket no Google Cloud Platform.

## 📋 Pré-requisitos

1. **Google Cloud SDK** instalado e configurado
2. **Terraform** >= 1.0
3. **kubectl** para gerenciar o cluster Kubernetes
4. Conta GCP com billing ativado
5. Projeto GCP criado

## 🚀 Setup Inicial

### 1. Configurar Google Cloud SDK

```bash
# Autenticar no GCP
gcloud auth login

# Configurar projeto
gcloud config set project YOUR_PROJECT_ID

# Criar credenciais para Terraform
gcloud auth application-default login
```

### 2. Habilitar APIs necessárias

```bash
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

### 3. Configurar variáveis Terraform

```bash
# Copiar arquivo de exemplo
cp terraform.tfvars.example terraform.tfvars

# Editar com seus valores
# vim terraform.tfvars
```

## 📦 Deploy da Infraestrutura

### Passo 1: Inicializar Terraform

```bash
terraform init
```

### Passo 2: Planejar mudanças

```bash
terraform plan
```

### Passo 3: Aplicar configuração

```bash
terraform apply
```

Digite `yes` quando solicitado.

## ☸️ Configurar Kubernetes

### Conectar ao cluster GKE

```bash
# Obter credenciais do cluster
gcloud container clusters get-credentials mqtt-websocket-gke \
  --region us-central1 \
  --project YOUR_PROJECT_ID

# Verificar conexão
kubectl cluster-info
kubectl get nodes
```

### Deploy da aplicação

```bash
# Criar namespace
kubectl apply -f k8s-manifests.yaml

# Verificar pods
kubectl get pods -n mqtt-app

# Verificar services
kubectl get svc -n mqtt-app
```

## 🏗️ Recursos Criados

O Terraform criará os seguintes recursos:

### Rede
- ✅ VPC Network customizada
- ✅ Subnet com IP ranges para pods e services
- ✅ Firewall rules para MQTT, HTTP, SSH

### Compute
- ✅ GKE Cluster (regional)
- ✅ Node Pool com autoscaling
- ✅ Workload Identity habilitado

### Storage
- ✅ Cloud Storage bucket para dados EMQX
- ✅ Persistent volumes para Kubernetes

### Networking
- ✅ Load Balancer com IP estático
- ✅ Network policies habilitadas

## 💰 Estimativa de Custos

Configuração padrão (região us-central1):

| Recurso | Custo Mensal Estimado |
|---------|----------------------|
| GKE Cluster | $75 |
| 2x e2-medium nodes | $50 |
| Load Balancer | $18 |
| Storage (50GB) | $10 |
| Network egress | ~$10 |
| **TOTAL** | **~$163/mês** |

> 💡 Para reduzir custos:
> - Use `gke_machine_type = "e2-small"` (menos performance)
> - Reduza `gke_num_nodes = 1`
> - Use cluster zonal ao invés de regional

## 🔐 Segurança

### Configurar IP allowlist para SSH

No arquivo `terraform.tfvars`:

```hcl
allowed_ssh_ips = ["YOUR_IP/32"]
```

### Certificados SSL/TLS

Para produção, configure SSL:

1. Instalar cert-manager:
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

2. Configurar Let's Encrypt:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: gce
```

## 📊 Monitoramento

### Acessar dashboards

```bash
# EMQX Dashboard
kubectl port-forward -n mqtt-app svc/emqx 18083:18083
# Acesse: http://localhost:18083 (admin/public)

# Frontend
kubectl port-forward -n mqtt-app svc/mqtt-frontend 8080:80
# Acesse: http://localhost:8080
```

### Logs

```bash
# Ver logs do EMQX
kubectl logs -n mqtt-app -l app=emqx -f

# Ver logs do backend
kubectl logs -n mqtt-app -l app=mqtt-backend -f

# Ver logs do frontend
kubectl logs -n mqtt-app -l app=mqtt-frontend -f
```

## 🔄 Atualizar Aplicação

### Build e push de imagens

```bash
# Configurar Docker para GCR
gcloud auth configure-docker

# Build backend
cd ../backend
docker build -t gcr.io/YOUR_PROJECT_ID/mqtt-backend:v1.0 .
docker push gcr.io/YOUR_PROJECT_ID/mqtt-backend:v1.0

# Build frontend
cd ../frontend
docker build -t gcr.io/YOUR_PROJECT_ID/mqtt-frontend:v1.0 .
docker push gcr.io/YOUR_PROJECT_ID/mqtt-frontend:v1.0
```

### Atualizar deployment

```bash
# Atualizar imagem do backend
kubectl set image deployment/mqtt-backend \
  backend=gcr.io/YOUR_PROJECT_ID/mqtt-backend:v1.1 \
  -n mqtt-app

# Verificar rollout
kubectl rollout status deployment/mqtt-backend -n mqtt-app
```

## 🧹 Limpeza de Recursos

### Deletar aplicação Kubernetes

```bash
kubectl delete namespace mqtt-app
```

### Destruir infraestrutura Terraform

```bash
terraform destroy
```

**⚠️ ATENÇÃO:** Isso deletará todos os recursos e dados!

## 🐛 Troubleshooting

### Pods não iniciam

```bash
# Ver eventos
kubectl get events -n mqtt-app --sort-by='.lastTimestamp'

# Descrever pod
kubectl describe pod POD_NAME -n mqtt-app
```

### Problemas de rede

```bash
# Testar conectividade MQTT
kubectl run -it --rm test --image=alpine --restart=Never -n mqtt-app -- sh
# Dentro do pod:
apk add mosquitto-clients
mosquitto_pub -h emqx -t test/topic -m "hello"
```

### Quota excedida

```bash
# Verificar quotas
gcloud compute project-info describe --project=YOUR_PROJECT_ID
```

## 📚 Recursos Adicionais

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [EMQX Kubernetes Operator](https://www.emqx.io/docs/en/v5.0/deploy/install-k8s.html)
- [GCP Pricing Calculator](https://cloud.google.com/products/calculator)

## 🆘 Suporte

Para issues e dúvidas, abra uma issue no repositório do projeto.
