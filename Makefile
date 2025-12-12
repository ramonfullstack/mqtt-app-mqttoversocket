# Makefile para facilitar comandos comuns

.PHONY: help build up down logs clean deploy-gcp

help: ## Mostra esta mensagem de ajuda
	@echo "Comandos disponíveis:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Build das imagens Docker
	docker-compose build

up: ## Inicia todos os serviços
	docker-compose up -d

down: ## Para todos os serviços
	docker-compose down

logs: ## Mostra logs de todos os serviços
	docker-compose logs -f

logs-emqx: ## Mostra logs do EMQX
	docker-compose logs -f emqx

logs-backend: ## Mostra logs do backend
	docker-compose logs -f backend

logs-frontend: ## Mostra logs do frontend
	docker-compose logs -f frontend

restart: ## Reinicia todos os serviços
	docker-compose restart

status: ## Mostra status dos serviços
	docker-compose ps

clean: ## Remove containers, volumes e imagens
	docker-compose down -v
	docker rmi mqtt-backend mqtt-frontend || true

dev: ## Inicia ambiente de desenvolvimento
	docker-compose up

test-mqtt: ## Testa conexão MQTT
	@echo "Testing MQTT connection..."
	@curl -s http://localhost:3000/health | jq .

open-dashboard: ## Abre EMQX Dashboard no navegador
	@echo "Opening EMQX Dashboard..."
	@echo "URL: http://localhost:18083"
	@echo "User: admin"
	@echo "Pass: public"

open-frontend: ## Abre Frontend no navegador
	@echo "Opening Frontend..."
	@echo "URL: http://localhost:8080"

install-backend: ## Instala dependências do backend
	cd backend && npm install

install-frontend: ## Preparar frontend (nenhuma dependência npm necessária)
	@echo "Frontend uses CDN for MQTT.js - no npm install needed"

deploy-gcp-init: ## Inicializa Terraform
	cd terraform && terraform init

deploy-gcp-plan: ## Planejar deploy no GCP
	cd terraform && terraform plan

deploy-gcp-apply: ## Aplicar deploy no GCP
	cd terraform && terraform apply

deploy-gcp-destroy: ## Destruir infraestrutura GCP
	cd terraform && terraform destroy

k8s-apply: ## Aplicar manifests Kubernetes
	kubectl apply -f terraform/k8s-manifests.yaml

k8s-delete: ## Deletar recursos Kubernetes
	kubectl delete -f terraform/k8s-manifests.yaml

k8s-status: ## Ver status dos pods Kubernetes
	kubectl get pods -n mqtt-app

k8s-logs-emqx: ## Ver logs EMQX no Kubernetes
	kubectl logs -n mqtt-app -l app=emqx -f

k8s-logs-backend: ## Ver logs backend no Kubernetes
	kubectl logs -n mqtt-app -l app=mqtt-backend -f

k8s-logs-frontend: ## Ver logs frontend no Kubernetes
	kubectl logs -n mqtt-app -l app=mqtt-frontend -f

docker-build-backend: ## Build imagem backend
	docker build -t mqtt-backend:latest ./backend

docker-build-frontend: ## Build imagem frontend
	docker build -t mqtt-frontend:latest ./frontend

docker-push-gcr: ## Push imagens para GCR (requires PROJECT_ID env var)
	@if [ -z "$(PROJECT_ID)" ]; then \
		echo "Error: PROJECT_ID not set. Usage: make docker-push-gcr PROJECT_ID=your-project-id"; \
		exit 1; \
	fi
	docker tag mqtt-backend:latest gcr.io/$(PROJECT_ID)/mqtt-backend:latest
	docker tag mqtt-frontend:latest gcr.io/$(PROJECT_ID)/mqtt-frontend:latest
	docker push gcr.io/$(PROJECT_ID)/mqtt-backend:latest
	docker push gcr.io/$(PROJECT_ID)/mqtt-frontend:latest

all: build up ## Build e inicia todos os serviços
