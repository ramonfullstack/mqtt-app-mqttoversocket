#!/bin/bash

# MQTT over WebSocket - Deployment Script
# Este script automatiza o processo de deploy local e em cloud

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para printar mensagens coloridas
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Banner
echo "======================================"
echo "  MQTT over WebSocket - Deploy Tool  "
echo "======================================"
echo ""

# Menu principal
show_menu() {
    echo "Escolha uma opção:"
    echo "1) Deploy Local (Docker Compose)"
    echo "2) Build Docker Images"
    echo "3) Deploy no GCP (Terraform + GKE)"
    echo "4) Verificar Status"
    echo "5) Logs"
    echo "6) Limpar Recursos"
    echo "0) Sair"
    echo ""
    read -p "Opção: " option
    return $option
}

# Deploy local com Docker Compose
deploy_local() {
    print_info "Iniciando deploy local com Docker Compose..."
    
    # Verificar se Docker está rodando
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker não está rodando!"
        exit 1
    fi
    
    # Criar .env se não existir
    if [ ! -f .env ]; then
        print_warn ".env não encontrado. Copiando de .env.example..."
        cp .env.example .env
    fi
    
    # Build e start dos containers
    print_info "Building e iniciando containers..."
    docker-compose up -d --build
    
    # Aguardar services ficarem healthy
    print_info "Aguardando services ficarem prontos..."
    sleep 10
    
    # Verificar status
    docker-compose ps
    
    echo ""
    print_info "✅ Deploy local concluído!"
    echo ""
    echo "Acesse:"
    echo "  - Frontend: http://localhost:8080"
    echo "  - Backend API: http://localhost:3000/health"
    echo "  - EMQX Dashboard: http://localhost:18083 (admin/public)"
    echo "  - MQTT WebSocket: ws://localhost:8083/mqtt"
}

# Build Docker images
build_images() {
    print_info "Building Docker images..."
    
    read -p "Tag version (default: latest): " tag
    tag=${tag:-latest}
    
    read -p "GCP Project ID (leave empty for local only): " project_id
    
    if [ -z "$project_id" ]; then
        # Local build
        print_info "Building backend..."
        docker build -t mqtt-backend:$tag ./backend
        
        print_info "Building frontend..."
        docker build -t mqtt-frontend:$tag ./frontend
    else
        # Build for GCR
        print_info "Building and pushing to GCR..."
        
        gcloud auth configure-docker
        
        print_info "Building backend..."
        docker build -t gcr.io/$project_id/mqtt-backend:$tag ./backend
        docker push gcr.io/$project_id/mqtt-backend:$tag
        
        print_info "Building frontend..."
        docker build -t gcr.io/$project_id/mqtt-frontend:$tag ./frontend
        docker push gcr.io/$project_id/mqtt-frontend:$tag
    fi
    
    print_info "✅ Build concluído!"
}

# Deploy no GCP
deploy_gcp() {
    print_info "Iniciando deploy no GCP..."
    
    # Verificar se terraform está instalado
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform não está instalado!"
        exit 1
    fi
    
    # Verificar se gcloud está instalado
    if ! command -v gcloud &> /dev/null; then
        print_error "Google Cloud SDK não está instalado!"
        exit 1
    fi
    
    cd terraform
    
    # Verificar se terraform.tfvars existe
    if [ ! -f terraform.tfvars ]; then
        print_error "terraform.tfvars não encontrado!"
        print_warn "Copie terraform.tfvars.example e configure seus valores"
        exit 1
    fi
    
    # Terraform init
    print_info "Inicializando Terraform..."
    terraform init
    
    # Terraform plan
    print_info "Planejando mudanças..."
    terraform plan -out=tfplan
    
    # Confirmar apply
    read -p "Aplicar mudanças? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_warn "Deploy cancelado"
        cd ..
        return
    fi
    
    # Terraform apply
    print_info "Aplicando configuração..."
    terraform apply tfplan
    
    # Obter outputs
    cluster_name=$(terraform output -raw gke_cluster_name)
    project_id=$(terraform output -raw project_id)
    region=$(terraform output -raw region)
    
    # Configurar kubectl
    print_info "Configurando kubectl..."
    gcloud container clusters get-credentials $cluster_name \
        --region $region \
        --project $project_id
    
    # Deploy K8s manifests
    print_info "Deploying aplicação no Kubernetes..."
    
    # Substituir PROJECT_ID no manifest
    sed "s/PROJECT_ID/$project_id/g" k8s-manifests.yaml | kubectl apply -f -
    
    # Aguardar pods ficarem ready
    print_info "Aguardando pods ficarem prontos..."
    kubectl wait --for=condition=ready pod -l app=emqx -n mqtt-app --timeout=300s
    
    print_info "✅ Deploy GCP concluído!"
    
    # Mostrar IPs
    echo ""
    echo "Load Balancer IPs:"
    kubectl get svc -n mqtt-app
    
    cd ..
}

# Verificar status
check_status() {
    echo "Escolha o ambiente:"
    echo "1) Local (Docker Compose)"
    echo "2) GCP (Kubernetes)"
    read -p "Opção: " env_option
    
    if [ "$env_option" -eq 1 ]; then
        print_info "Status dos containers locais:"
        docker-compose ps
        
        echo ""
        print_info "Health checks:"
        echo "Backend: $(curl -s http://localhost:3000/health | jq -r .status || echo 'Failed')"
        echo "Frontend: $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080)"
        echo "EMQX: $(curl -s -o /dev/null -w '%{http_code}' http://localhost:18083)"
    else
        print_info "Status dos pods no Kubernetes:"
        kubectl get pods -n mqtt-app
        
        echo ""
        print_info "Services:"
        kubectl get svc -n mqtt-app
    fi
}

# Ver logs
view_logs() {
    echo "Escolha o ambiente:"
    echo "1) Local (Docker Compose)"
    echo "2) GCP (Kubernetes)"
    read -p "Opção: " env_option
    
    if [ "$env_option" -eq 1 ]; then
        echo "Escolha o serviço:"
        echo "1) EMQX"
        echo "2) Backend"
        echo "3) Frontend"
        echo "4) Todos"
        read -p "Opção: " service_option
        
        case $service_option in
            1) docker-compose logs -f emqx ;;
            2) docker-compose logs -f backend ;;
            3) docker-compose logs -f frontend ;;
            4) docker-compose logs -f ;;
        esac
    else
        echo "Escolha o serviço:"
        echo "1) EMQX"
        echo "2) Backend"
        echo "3) Frontend"
        read -p "Opção: " service_option
        
        case $service_option in
            1) kubectl logs -n mqtt-app -l app=emqx -f ;;
            2) kubectl logs -n mqtt-app -l app=mqtt-backend -f ;;
            3) kubectl logs -n mqtt-app -l app=mqtt-frontend -f ;;
        esac
    fi
}

# Limpar recursos
cleanup() {
    echo "Escolha o ambiente para limpar:"
    echo "1) Local (Docker Compose)"
    echo "2) GCP (Terraform)"
    read -p "Opção: " env_option
    
    read -p "⚠️  ATENÇÃO: Isso deletará todos os recursos. Confirma? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_warn "Limpeza cancelada"
        return
    fi
    
    if [ "$env_option" -eq 1 ]; then
        print_info "Parando e removendo containers..."
        docker-compose down -v
        
        print_info "Removendo imagens..."
        docker rmi mqtt-backend mqtt-frontend 2>/dev/null || true
        
        print_info "✅ Limpeza local concluída!"
    else
        cd terraform
        print_info "Destruindo infraestrutura GCP..."
        terraform destroy
        cd ..
        
        print_info "✅ Limpeza GCP concluída!"
    fi
}

# Main loop
while true; do
    show_menu
    option=$?
    
    case $option in
        1) deploy_local ;;
        2) build_images ;;
        3) deploy_gcp ;;
        4) check_status ;;
        5) view_logs ;;
        6) cleanup ;;
        0) 
            print_info "Saindo..."
            exit 0
            ;;
        *)
            print_error "Opção inválida!"
            ;;
    esac
    
    echo ""
    read -p "Pressione Enter para continuar..."
    clear
done
