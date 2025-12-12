# Guia Completo - MQTT over WebSocket

## 📚 Conteúdo de Aprendizado

Este guia fornece conhecimento aprofundado sobre MQTT over WebSocket.

---

## 🎯 O que é MQTT?

**MQTT (Message Queuing Telemetry Transport)** é um protocolo de mensagens leve baseado no padrão publish/subscribe, projetado para dispositivos com recursos limitados e redes de baixa largura de banda.

### Características Principais

- **Leve**: Overhead mínimo de protocolo
- **Pub/Sub**: Padrão de publicação/subscrição desacoplado
- **QoS**: 3 níveis de qualidade de serviço
- **Retained Messages**: Mensagens persistentes
- **Last Will & Testament**: Notificação de desconexão

### Casos de Uso

- Internet das Coisas (IoT)
- Sensores e atuadores
- Aplicações mobile
- Sistemas de monitoramento
- Home automation

---

## 🌐 O que é WebSocket?

**WebSocket** é um protocolo de comunicação que fornece canais full-duplex sobre uma única conexão TCP.

### Vantagens

- **Bidirecion**: Comunicação em duas vias
- **Tempo Real**: Latência mínima
- **Eficiente**: Menos overhead que HTTP polling
- **Nativo**: Suporte nativo em navegadores

### Diferença vs HTTP

```
HTTP:
Cliente → Request → Servidor
Cliente ← Response ← Servidor
[Conexão fecha]

WebSocket:
Cliente ↔ Dados ↔ Servidor
[Conexão permanece aberta]
```

---

## 🔄 MQTT over WebSocket

Combina o melhor dos dois mundos:
- Eficiência do MQTT
- Acessibilidade do WebSocket no navegador

### Por que usar?

1. **Acesso Universal**: Qualquer navegador pode conectar
2. **Sem Proxy**: Funciona através de firewalls/proxies HTTP
3. **Desenvolvimento Simplificado**: JavaScript nativo
4. **Real-time**: Atualizações instantâneas

---

## 📊 Conceitos MQTT Essenciais

### 1. Topics (Tópicos)

Hierarquia de strings separadas por `/`:

```
home/living-room/temperature
home/bedroom/humidity
sensors/outdoor/pressure
```

**Wildcards:**
- `+` : Um nível único
  - `home/+/temperature` → `home/living-room/temperature`, `home/bedroom/temperature`
- `#` : Múltiplos níveis
  - `home/#` → Todos os tópicos começando com `home/`

### 2. QoS (Quality of Service)

| QoS | Nome | Garantia | Uso |
|-----|------|----------|-----|
| 0 | At most once | Nenhuma | Dados não críticos, telemetria |
| 1 | At least once | Entrega garantida (duplicatas possíveis) | Comandos importantes |
| 2 | Exactly once | Entrega garantida única | Transações financeiras |

### 3. Retained Messages

Mensagens marcadas como `retained` são:
- Armazenadas pelo broker
- Enviadas imediatamente para novos subscribers
- Útil para status/configurações

```javascript
client.publish('device/status', 'online', { 
  qos: 1, 
  retain: true 
});
```

### 4. Last Will & Testament (LWT)

Mensagem automática enviada pelo broker quando cliente desconecta inesperadamente:

```javascript
const options = {
  will: {
    topic: 'device/status',
    payload: 'offline',
    qos: 1,
    retain: true
  }
};
```

### 5. Clean Session

- `true`: Não persiste sessão (subscrições/mensagens perdidas ao desconectar)
- `false`: Persiste sessão (mensagens QoS > 0 são enfileiradas)

---

## 🔧 MQTT.js - Cliente JavaScript

### Instalação

```bash
# Node.js
npm install mqtt

# Browser (CDN)
<script src="https://unpkg.com/mqtt/dist/mqtt.min.js"></script>
```

### Conexão

```javascript
const mqtt = require('mqtt');

const client = mqtt.connect('ws://broker.emqx.io:8083/mqtt', {
  clientId: 'client_' + Math.random().toString(16).substring(2, 8),
  keepalive: 60,
  clean: true,
  reconnectPeriod: 1000
});
```

### Subscribe

```javascript
client.on('connect', () => {
  // Subscribe to single topic
  client.subscribe('sensors/temperature', { qos: 1 });
  
  // Subscribe to multiple topics
  client.subscribe(['sensors/humidity', 'sensors/pressure'], { qos: 1 });
  
  // Subscribe with wildcard
  client.subscribe('sensors/#', { qos: 0 });
});
```

### Publish

```javascript
// Simple string
client.publish('sensors/temperature', '25.5', { qos: 1 });

// JSON object
const data = {
  temperature: 25.5,
  humidity: 65,
  timestamp: Date.now()
};
client.publish('sensors/data', JSON.stringify(data), { 
  qos: 1,
  retain: false 
});
```

### Receive Messages

```javascript
client.on('message', (topic, message, packet) => {
  console.log(`Topic: ${topic}`);
  console.log(`Message: ${message.toString()}`);
  console.log(`QoS: ${packet.qos}`);
  
  // Parse JSON
  try {
    const data = JSON.parse(message.toString());
    console.log('Data:', data);
  } catch (e) {
    // Not JSON
  }
});
```

### Event Handlers

```javascript
client.on('connect', () => {
  console.log('Connected');
});

client.on('error', (err) => {
  console.error('Connection error:', err);
});

client.on('reconnect', () => {
  console.log('Reconnecting...');
});

client.on('close', () => {
  console.log('Connection closed');
});

client.on('offline', () => {
  console.log('Client offline');
});
```

---

## 🏗️ Arquitetura do Projeto

```
┌─────────────────────────────────────────────────┐
│                   Internet                       │
└─────────────────┬───────────────────────────────┘
                  │
         ┌────────▼────────┐
         │  Load Balancer  │
         └────────┬────────┘
                  │
    ┌─────────────┴─────────────┐
    │                           │
┌───▼────┐                 ┌────▼───┐
│Frontend│                 │Backend │
│(Nginx) │                 │(Node)  │
└───┬────┘                 └────┬───┘
    │                           │
    │         ┌─────────────────┘
    │         │
    └────┬────┘
         │
    ┌────▼────┐
    │  EMQX   │
    │ Broker  │
    └─────────┘
         │
    ┌────▼────┐
    │ Storage │
    └─────────┘
```

---

## 🐳 Docker & Docker Compose

### Por que usar Docker?

- **Portabilidade**: Roda em qualquer lugar
- **Isolamento**: Ambientes independentes
- **Reprodutibilidade**: Sempre o mesmo comportamento
- **Escalabilidade**: Fácil de escalar

### Comandos Úteis

```bash
# Build e start
docker-compose up -d --build

# Ver logs
docker-compose logs -f

# Parar containers
docker-compose down

# Remover volumes
docker-compose down -v

# Verificar status
docker-compose ps

# Executar comando em container
docker-compose exec backend sh
```

### Estrutura docker-compose.yml

```yaml
version: '3.8'

services:
  emqx:
    image: emqx/emqx:latest
    ports:
      - "1883:1883"   # MQTT
      - "8083:8083"   # WebSocket
      - "18083:18083" # Dashboard
    environment:
      - EMQX_NAME=emqx
    volumes:
      - emqx-data:/opt/emqx/data
    networks:
      - mqtt-network

volumes:
  emqx-data:

networks:
  mqtt-network:
    driver: bridge
```

---

## ☸️ Kubernetes & GKE

### Conceitos Básicos

**Pod**: Menor unidade deployável
**Deployment**: Gerencia réplicas de Pods
**Service**: Expõe Pods na rede
**Ingress**: Roteamento HTTP/HTTPS

### Comandos kubectl

```bash
# Listar recursos
kubectl get pods
kubectl get services
kubectl get deployments

# Descrever recurso
kubectl describe pod <pod-name>

# Ver logs
kubectl logs <pod-name>
kubectl logs -f <pod-name>  # follow

# Port forward (local access)
kubectl port-forward svc/emqx 8083:8083

# Executar comando em pod
kubectl exec -it <pod-name> -- sh

# Aplicar manifests
kubectl apply -f k8s-manifests.yaml

# Deletar recursos
kubectl delete -f k8s-manifests.yaml
```

---

## 🔐 Segurança

### MQTT Authentication

```javascript
const client = mqtt.connect('ws://broker.emqx.io:8083/mqtt', {
  username: 'myuser',
  password: 'mypassword'
});
```

### TLS/SSL (WebSocket Secure)

```javascript
const client = mqtt.connect('wss://broker.emqx.io:8084/mqtt', {
  rejectUnauthorized: false, // apenas para dev!
  // Em produção:
  // ca: fs.readFileSync('ca.crt'),
  // cert: fs.readFileSync('client.crt'),
  // key: fs.readFileSync('client.key')
});
```

### Best Practices

1. **Sempre use WSS em produção**
2. **Implemente autenticação**
3. **Use ACLs (Access Control Lists)**
4. **Valide payloads**
5. **Limite rate de mensagens**
6. **Monitore conexões suspeitas**

---

## 📈 Monitoramento

### EMQX Dashboard

Acesse: http://localhost:18083

Monitorar:
- Conexões ativas
- Mensagens por segundo
- Subscrições
- Tópicos ativos
- Performance

### Métricas Importantes

- **Connection Rate**: Conexões/segundo
- **Message Rate**: Mensagens/segundo
- **Subscription Count**: Total de subscrições
- **Bytes In/Out**: Throughput
- **CPU/Memory Usage**: Recursos

---

## 🧪 Testes

### Teste Manual com MQTTX

1. Download: https://mqttx.app/
2. Connect: `ws://localhost:8083/mqtt`
3. Subscribe: `test/#`
4. Publish: `test/topic` → `Hello MQTT!`

### Teste Programático

```javascript
// Publisher
const publisher = mqtt.connect('ws://localhost:8083/mqtt');
publisher.on('connect', () => {
  setInterval(() => {
    const data = {
      temperature: Math.random() * 30 + 10,
      timestamp: Date.now()
    };
    publisher.publish('sensors/temp', JSON.stringify(data));
  }, 1000);
});

// Subscriber
const subscriber = mqtt.connect('ws://localhost:8083/mqtt');
subscriber.on('connect', () => {
  subscriber.subscribe('sensors/#');
});
subscriber.on('message', (topic, message) => {
  console.log(`${topic}: ${message}`);
});
```

---

## 🚀 Performance Tips

### 1. Otimizar QoS
Use QoS 0 quando possível (menor overhead)

### 2. Batch Publishing
Agrupe mensagens quando possível

### 3. Comprimir Payloads
Use compressão para payloads grandes

### 4. Connection Pooling
Reuse conexões quando possível

### 5. Clean Session
Use `clean: true` para clientes temporários

---

## 🎓 Recursos de Aprendizado

### Documentação Oficial
- [MQTT.org](https://mqtt.org/)
- [MQTT.js GitHub](https://github.com/mqttjs/MQTT.js)
- [EMQX Docs](https://docs.emqx.com/)

### Tutoriais
- [MQTT Guide - EMQX](https://www.emqx.com/en/mqtt-guide)
- [HiveMQ MQTT Essentials](https://www.hivemq.com/mqtt-essentials/)

### Ferramentas
- [MQTTX](https://mqttx.app/) - Cliente GUI
- [Mosquitto](https://mosquitto.org/) - Broker e CLI tools

---

## 💡 Exemplos de Casos de Uso

### 1. Dashboard IoT
```javascript
// Subscribe to all sensors
client.subscribe('sensors/#');

// Update UI on message
client.on('message', (topic, message) => {
  const data = JSON.parse(message);
  updateChart(topic, data.value);
});
```

### 2. Chat Application
```javascript
// Subscribe to chat room
client.subscribe('chat/room1');

// Send message
function sendMessage(text) {
  const msg = {
    user: username,
    text: text,
    timestamp: Date.now()
  };
  client.publish('chat/room1', JSON.stringify(msg));
}
```

### 3. Remote Control
```javascript
// Device subscribes to commands
client.subscribe('devices/device123/commands');

client.on('message', (topic, message) => {
  const cmd = JSON.parse(message);
  executeCommand(cmd);
  
  // Send response
  client.publish('devices/device123/status', 
    JSON.stringify({ status: 'executed', cmd: cmd.id }));
});
```

---

## 🔍 Troubleshooting

### Conexão falha
- Verifique URL (ws:// vs wss://)
- Confirme porta correta (8083 para WS, 8084 para WSS)
- Inclua path `/mqtt`
- Verifique firewall

### Mensagens não chegam
- Confirme QoS levels
- Verifique wildcard patterns
- Teste com MQTTX
- Verifique logs do broker

### Performance ruim
- Reduza QoS
- Otimize payload size
- Implemente batching
- Verifique recursos do broker

---

Bons estudos! 🚀
