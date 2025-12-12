# MQTT over WebSocket - Projeto de Aprendizado

Este projeto demonstra uma aplicação completa MQTT over WebSocket com deploy em GCP usando Docker e Terraform.

## 📋 Sobre o Projeto

Uma aplicação de referência para aprender MQTT sobre WebSocket, incluindo:
- ✅ Cliente WebSocket em HTML/JavaScript
- ✅ Backend Node.js com MQTT.js
- ✅ Broker EMQX containerizado
- ✅ Deploy automatizado no GCP com Terraform
- ✅ Containerização completa com Docker

## 🏗️ Arquitetura

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   Browser   │────────▶│    EMQX     │◀────────│   Backend   │
│  (WebSocket)│         │   Broker    │         │  (Node.js)  │
└─────────────┘         └─────────────┘         └─────────────┘
     WS/WSS              Ports: 1883,              MQTT.js
                         8083, 8084
```

## 🚀 Quick Start

### Pré-requisitos
- Docker & Docker Compose
- Node.js >= 18
- Terraform (para deploy no GCP)
- GCP Account (para deploy em cloud)

### Executar Localmente

```bash
# Clone o repositório
git clone <seu-repo>
cd MqttOverSocket

# Subir todos os serviços
docker-compose up -d

# Acessar a aplicação
# Frontend: http://localhost:8080
# EMQX Dashboard: http://localhost:18083 (admin/public)
```

### Deploy no GCP

```bash
# Configurar credenciais GCP
export GOOGLE_CREDENTIALS="path/to/your/credentials.json"

# Inicializar Terraform
cd terraform
terraform init

# Planejar deploy
terraform plan

# Aplicar mudanças
terraform apply
```

## 📁 Estrutura do Projeto

```
MqttOverSocket/
├── backend/              # API Node.js
│   ├── src/
│   │   └── server.js
│   ├── package.json
│   └── Dockerfile
├── frontend/            # Cliente WebSocket
│   ├── index.html
│   ├── js/
│   │   └── mqtt-client.js
│   ├── css/
│   │   └── style.css
│   └── Dockerfile
├── terraform/           # IaC para GCP
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── gke.tf
├── docker-compose.yml
└── README.md
```

## 🔧 Configuração

### Variáveis de Ambiente

Crie um arquivo `.env` na raiz do projeto:

```env
# MQTT Broker
MQTT_BROKER_HOST=emqx
MQTT_BROKER_PORT=1883
MQTT_WS_PORT=8083
MQTT_WSS_PORT=8084

# Backend
BACKEND_PORT=3000

# GCP
GCP_PROJECT_ID=your-project-id
GCP_REGION=us-central1
GCP_ZONE=us-central1-a
```

## 📖 Recursos de Aprendizado

Este projeto foi criado seguindo o guia oficial da EMQX:
- [MQTT over WebSocket Guide](https://www.emqx.com/en/blog/connect-to-mqtt-broker-with-websocket)

### Conceitos Cobertos

1. **MQTT Protocol**
   - Publish/Subscribe pattern
   - QoS levels (0, 1, 2)
   - Topics e Wildcards
   - Retained messages
   - Last Will & Testament

2. **WebSocket**
   - Full-duplex communication
   - WS vs WSS (WebSocket Secure)
   - Connection management

3. **EMQX Broker**
   - Dashboard management
   - Authentication & Authorization
   - Rule Engine
   - Data Integration

4. **DevOps**
   - Docker containerization
   - Docker Compose orchestration
   - Terraform infrastructure as code
   - GCP deployment (GKE, Cloud SQL, Load Balancer)

## 🧪 Testando

### Teste Manual com MQTTX
1. Baixe [MQTTX](https://mqttx.app/)
2. Configure conexão:
   - Host: `ws://localhost:8083/mqtt`
   - Client ID: `mqttx_test`
3. Subscribe ao tópico: `test/topic`
4. Publique mensagens

### Teste Programático

```javascript
// Conectar ao broker
const client = mqtt.connect('ws://localhost:8083/mqtt', {
  clientId: 'test_client_' + Math.random().toString(16).substring(2, 10)
});

// Subscribe
client.subscribe('test/topic');

// Publish
client.publish('test/topic', 'Hello MQTT!');

// Receive
client.on('message', (topic, message) => {
  console.log(`${topic}: ${message.toString()}`);
});
```

## 🔐 Segurança

Para produção, sempre use:
- ✅ WSS (WebSocket Secure) com certificados válidos
- ✅ Autenticação MQTT (username/password)
- ✅ ACL (Access Control Lists)
- ✅ TLS/SSL para todas as conexões
- ✅ Firewall rules apropriadas

## 📊 Monitoramento

- **EMQX Dashboard**: http://localhost:18083
- **Métricas**: Prometheus + Grafana (configuração futura)
- **Logs**: Docker logs ou Cloud Logging (GCP)

## 🛠️ Troubleshooting

### Porta 8083 já em uso
```bash
# Parar containers
docker-compose down

# Verificar portas
netstat -ano | findstr :8083

# Liberar porta ou mudar no docker-compose.yml
```

### Conexão WebSocket falhando
- Verifique se o path é `/mqtt`
- Confirme protocolo: `ws://` ou `wss://`
- Verifique logs do EMQX: `docker logs emqx`

## 🤝 Contribuindo

Sinta-se livre para contribuir com melhorias!

## 📄 Licença

MIT License

## 🔗 Links Úteis

- [MQTT.js Documentation](https://github.com/mqttjs/MQTT.js)
- [EMQX Documentation](https://docs.emqx.com/)
- [MQTT Specification](https://mqtt.org/)
- [WebSocket API](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket)
