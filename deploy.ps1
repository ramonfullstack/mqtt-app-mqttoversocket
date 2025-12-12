# MQTT over WebSocket - Deployment Script (PowerShell)
# Script para automatizar deploy local e em cloud

$ErrorActionPreference = "Stop"

# Cores para output
function Write-Info {
    Write-Host "[INFO] $args" -ForegroundColor Green
}

function Write-Warn {
    Write-Host "[WARN] $args" -ForegroundColor Yellow
}

function Write-Error-Custom {
    Write-Host "[ERROR] $args" -ForegroundColor Red
}

# Banner
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  MQTT over WebSocket - Deploy Tool  " -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Menu principal
function Show-Menu {
    Write-Host "Escolha uma opção:"
    Write-Host "1) Deploy Local (Docker Compose)"
    Write-Host "2) Build Docker Images"
    Write-Host "3) Deploy no GCP (Terraform + GKE)"
    Write-Host "4) Verificar Status"
    Write-Host "5) Logs"
    Write-Host "6) Limpar Recursos"
    Write-Host "0) Sair"
    Write-Host ""
    
    $option = Read-Host "Opção"
    return $option
}

# Deploy local com Docker Compose
function Deploy-Local {
    Write-Info "Iniciando deploy local com Docker Compose..."
    
    # Verificar se Docker está rodando
    try {
        docker info | Out-Null
    } catch {
        Write-Error-Custom "Docker não está rodando!"
        return
    }
    
    # Criar .env se não existir
    if (-not (Test-Path .env)) {
        Write-Warn ".env não encontrado. Copiando de .env.example..."
        Copy-Item .env.example .env
    }
    
    # Build e start dos containers
    Write-Info "Building e iniciando containers..."
    docker-compose up -d --build
    
    # Aguardar services ficarem healthy
    Write-Info "Aguardando services ficarem prontos..."
    Start-Sleep -Seconds 10
    
    # Verificar status
    docker-compose ps
    
    Write-Host ""
    Write-Info "✅ Deploy local concluído!"
    Write-Host ""
    Write-Host "Acesse:"
    Write-Host "  - Frontend: http://localhost:8080"
    Write-Host "  - Backend API: http://localhost:3000/health"
    Write-Host "  - EMQX Dashboard: http://localhost:18083 (admin/public)"
    Write-Host "  - MQTT WebSocket: ws://localhost:8083/mqtt"
}

# Build Docker images
function Build-Images {
    Write-Info "Building Docker images..."
    
    $tag = Read-Host "Tag version (default: latest)"
    if ([string]::IsNullOrEmpty($tag)) { $tag = "latest" }
    
    $projectId = Read-Host "GCP Project ID (deixe vazio para local only)"
    
    if ([string]::IsNullOrEmpty($projectId)) {
        # Local build
        Write-Info "Building backend..."
        docker build -t mqtt-backend:$tag ./backend
        
        Write-Info "Building frontend..."
        docker build -t mqtt-frontend:$tag ./frontend
    } else {
        # Build for GCR
        Write-Info "Building and pushing to GCR..."
        
        gcloud auth configure-docker
        
        Write-Info "Building backend..."
        docker build -t "gcr.io/$projectId/mqtt-backend:$tag" ./backend
        docker push "gcr.io/$projectId/mqtt-backend:$tag"
        
        Write-Info "Building frontend..."
        docker build -t "gcr.io/$projectId/mqtt-frontend:$tag" ./frontend
        docker push "gcr.io/$projectId/mqtt-frontend:$tag"
    }
    
    Write-Info "✅ Build concluído!"
}

# Deploy no GCP
function Deploy-GCP {
    Write-Info "Iniciando deploy no GCP..."
    
    # Verificar se terraform está instalado
    if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
        Write-Error-Custom "Terraform não está instalado!"
        return
    }
    
    # Verificar se gcloud está instalado
    if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
        Write-Error-Custom "Google Cloud SDK não está instalado!"
        return
    }
    
    Set-Location terraform
    
    # Verificar se terraform.tfvars existe
    if (-not (Test-Path terraform.tfvars)) {
        Write-Error-Custom "terraform.tfvars não encontrado!"
        Write-Warn "Copie terraform.tfvars.example e configure seus valores"
        Set-Location ..
        return
    }
    
    # Terraform init
    Write-Info "Inicializando Terraform..."
    terraform init
    
    # Terraform plan
    Write-Info "Planejando mudanças..."
    terraform plan -out=tfplan
    
    # Confirmar apply
    $confirm = Read-Host "Aplicar mudanças? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Warn "Deploy cancelado"
        Set-Location ..
        return
    }
    
    # Terraform apply
    Write-Info "Aplicando configuração..."
    terraform apply tfplan
    
    Write-Info "✅ Deploy GCP concluído!"
    
    Set-Location ..
}

# Verificar status
function Check-Status {
    Write-Host "Escolha o ambiente:"
    Write-Host "1) Local (Docker Compose)"
    Write-Host "2) GCP (Kubernetes)"
    $envOption = Read-Host "Opção"
    
    if ($envOption -eq 1) {
        Write-Info "Status dos containers locais:"
        docker-compose ps
        
        Write-Host ""
        Write-Info "Health checks:"
        try {
            $backend = Invoke-RestMethod -Uri "http://localhost:3000/health" -Method Get
            Write-Host "Backend: $($backend.status)"
        } catch {
            Write-Host "Backend: Failed"
        }
    } else {
        Write-Info "Status dos pods no Kubernetes:"
        kubectl get pods -n mqtt-app
        
        Write-Host ""
        Write-Info "Services:"
        kubectl get svc -n mqtt-app
    }
}

# Ver logs
function View-Logs {
    Write-Host "Escolha o ambiente:"
    Write-Host "1) Local (Docker Compose)"
    Write-Host "2) GCP (Kubernetes)"
    $envOption = Read-Host "Opção"
    
    if ($envOption -eq 1) {
        Write-Host "Escolha o serviço:"
        Write-Host "1) EMQX"
        Write-Host "2) Backend"
        Write-Host "3) Frontend"
        Write-Host "4) Todos"
        $serviceOption = Read-Host "Opção"
        
        switch ($serviceOption) {
            1 { docker-compose logs -f emqx }
            2 { docker-compose logs -f backend }
            3 { docker-compose logs -f frontend }
            4 { docker-compose logs -f }
        }
    } else {
        Write-Host "Escolha o serviço:"
        Write-Host "1) EMQX"
        Write-Host "2) Backend"
        Write-Host "3) Frontend"
        $serviceOption = Read-Host "Opção"
        
        switch ($serviceOption) {
            1 { kubectl logs -n mqtt-app -l app=emqx -f }
            2 { kubectl logs -n mqtt-app -l app=mqtt-backend -f }
            3 { kubectl logs -n mqtt-app -l app=mqtt-frontend -f }
        }
    }
}

# Limpar recursos
function Cleanup {
    Write-Host "Escolha o ambiente para limpar:"
    Write-Host "1) Local (Docker Compose)"
    Write-Host "2) GCP (Terraform)"
    $envOption = Read-Host "Opção"
    
    $confirm = Read-Host "⚠️  ATENÇÃO: Isso deletará todos os recursos. Confirma? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Warn "Limpeza cancelada"
        return
    }
    
    if ($envOption -eq 1) {
        Write-Info "Parando e removendo containers..."
        docker-compose down -v
        
        Write-Info "Removendo imagens..."
        docker rmi mqtt-backend mqtt-frontend 2>$null
        
        Write-Info "✅ Limpeza local concluída!"
    } else {
        Set-Location terraform
        Write-Info "Destruindo infraestrutura GCP..."
        terraform destroy
        Set-Location ..
        
        Write-Info "✅ Limpeza GCP concluída!"
    }
}

# Main loop
while ($true) {
    $option = Show-Menu
    
    switch ($option) {
        1 { Deploy-Local }
        2 { Build-Images }
        3 { Deploy-GCP }
        4 { Check-Status }
        5 { View-Logs }
        6 { Cleanup }
        0 { 
            Write-Info "Saindo..."
            exit 0
        }
        default {
            Write-Error-Custom "Opção inválida!"
        }
    }
    
    Write-Host ""
    Read-Host "Pressione Enter para continuar..."
    Clear-Host
}
