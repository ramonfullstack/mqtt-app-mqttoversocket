# Backend Node.js - MQTT over WebSocket

Backend em Node.js que conecta ao broker EMQX e fornece uma API REST para interagir com MQTT.

## Funcionalidades

- ✅ Conexão MQTT com broker EMQX
- ✅ Subscribe/Publish via API REST
- ✅ Handlers para sensores e comandos
- ✅ Logging estruturado com Winston
- ✅ Health checks
- ✅ Simulador de dados de sensores

## Endpoints da API

### GET /health
Verifica status do servidor e conexão MQTT.

```bash
curl http://localhost:3000/health
```

### GET /api/mqtt/info
Retorna informações sobre a conexão MQTT.

### POST /api/mqtt/publish
Publica uma mensagem em um tópico.

```bash
curl -X POST http://localhost:3000/api/mqtt/publish \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "sensors/temperature",
    "message": {"value": 25.5, "unit": "°C"},
    "qos": 1,
    "retain": false
  }'
```

### POST /api/mqtt/subscribe
Inscreve em um tópico.

```bash
curl -X POST http://localhost:3000/api/mqtt/subscribe \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "sensors/#",
    "qos": 1
  }'
```

### POST /api/simulate/sensor
Simula dados de sensor para testes.

```bash
curl -X POST http://localhost:3000/api/simulate/sensor \
  -H "Content-Type: application/json" \
  -d '{"sensorType": "temperature"}'
```

## Desenvolvimento Local

```bash
# Instalar dependências
npm install

# Executar em modo dev
npm run dev

# Executar em produção
npm start
```

## Variáveis de Ambiente

```env
MQTT_BROKER_HOST=localhost
MQTT_BROKER_PORT=1883
BACKEND_PORT=3000
NODE_ENV=development
```
