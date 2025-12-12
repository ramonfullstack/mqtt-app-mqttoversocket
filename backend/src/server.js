const express = require('express');
const mqtt = require('mqtt');
const cors = require('cors');
const winston = require('winston');
require('dotenv').config();

// Logger configuration
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
});

// Express app setup
const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.BACKEND_PORT || 3000;
const MQTT_BROKER_HOST = process.env.MQTT_BROKER_HOST || 'localhost';
const MQTT_BROKER_PORT = process.env.MQTT_BROKER_PORT || 1883;

// MQTT Client configuration
const mqttOptions = {
  clientId: `backend_${Math.random().toString(16).substring(2, 10)}`,
  keepalive: 60,
  protocolId: 'MQTT',
  protocolVersion: 5,
  clean: true,
  reconnectPeriod: 1000,
  connectTimeout: 30 * 1000,
  will: {
    topic: 'backend/status',
    payload: JSON.stringify({ status: 'offline', timestamp: Date.now() }),
    qos: 1,
    retain: true
  }
};

// Connect to MQTT Broker
const mqttBrokerUrl = `mqtt://${MQTT_BROKER_HOST}:${MQTT_BROKER_PORT}`;
logger.info(`Connecting to MQTT Broker: ${mqttBrokerUrl}`);

const mqttClient = mqtt.connect(mqttBrokerUrl, mqttOptions);

// MQTT Event Handlers
mqttClient.on('connect', () => {
  logger.info('✅ Connected to MQTT Broker successfully');
  
  // Subscribe to topics
  mqttClient.subscribe('sensors/#', { qos: 1 }, (err) => {
    if (err) {
      logger.error('Failed to subscribe to sensors/#:', err);
    } else {
      logger.info('📡 Subscribed to sensors/#');
    }
  });

  mqttClient.subscribe('commands/#', { qos: 1 }, (err) => {
    if (err) {
      logger.error('Failed to subscribe to commands/#:', err);
    } else {
      logger.info('📡 Subscribed to commands/#');
    }
  });

  // Publish online status
  mqttClient.publish(
    'backend/status',
    JSON.stringify({ status: 'online', timestamp: Date.now() }),
    { qos: 1, retain: true }
  );
});

mqttClient.on('error', (err) => {
  logger.error('❌ MQTT Connection error:', err);
});

mqttClient.on('reconnect', () => {
  logger.warn('🔄 Reconnecting to MQTT Broker...');
});

mqttClient.on('message', (topic, message, packet) => {
  try {
    const payload = message.toString();
    logger.info(`📨 Message received - Topic: ${topic}, Payload: ${payload}`);
    
    // Process message based on topic
    if (topic.startsWith('sensors/')) {
      handleSensorData(topic, payload);
    } else if (topic.startsWith('commands/')) {
      handleCommand(topic, payload);
    }
  } catch (error) {
    logger.error('Error processing message:', error);
  }
});

// Message handlers
function handleSensorData(topic, payload) {
  try {
    const data = JSON.parse(payload);
    logger.info(`🌡️  Sensor data from ${topic}:`, data);
    
    // Example: Store to database, trigger alerts, etc.
    // For now, just log it
  } catch (error) {
    logger.error('Error parsing sensor data:', error);
  }
}

function handleCommand(topic, payload) {
  logger.info(`⚡ Command received on ${topic}: ${payload}`);
  
  // Example: Execute command, control devices, etc.
  // Respond to the command
  const responseTopic = topic.replace('commands/', 'responses/');
  mqttClient.publish(
    responseTopic,
    JSON.stringify({ status: 'executed', timestamp: Date.now() }),
    { qos: 1 }
  );
}

// REST API Endpoints

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    mqtt: mqttClient.connected ? 'connected' : 'disconnected',
    uptime: process.uptime()
  });
});

// Get MQTT connection info
app.get('/api/mqtt/info', (req, res) => {
  res.json({
    broker: mqttBrokerUrl,
    connected: mqttClient.connected,
    clientId: mqttOptions.clientId
  });
});

// Publish message via REST API
app.post('/api/mqtt/publish', (req, res) => {
  const { topic, message, qos = 0, retain = false } = req.body;
  
  if (!topic || !message) {
    return res.status(400).json({ error: 'Topic and message are required' });
  }

  const payload = typeof message === 'string' ? message : JSON.stringify(message);
  
  mqttClient.publish(topic, payload, { qos, retain }, (err) => {
    if (err) {
      logger.error('Failed to publish message:', err);
      return res.status(500).json({ error: 'Failed to publish message' });
    }
    
    logger.info(`📤 Published to ${topic}: ${payload}`);
    res.json({ success: true, topic, message: payload });
  });
});

// Subscribe to topic via REST API
app.post('/api/mqtt/subscribe', (req, res) => {
  const { topic, qos = 0 } = req.body;
  
  if (!topic) {
    return res.status(400).json({ error: 'Topic is required' });
  }

  mqttClient.subscribe(topic, { qos }, (err) => {
    if (err) {
      logger.error('Failed to subscribe:', err);
      return res.status(500).json({ error: 'Failed to subscribe' });
    }
    
    logger.info(`📡 Subscribed to ${topic}`);
    res.json({ success: true, topic });
  });
});

// Get list of topics (simulated - MQTT doesn't have native topic listing)
app.get('/api/mqtt/topics', (req, res) => {
  // This is a simplified version - in production, you'd track this
  res.json({
    topics: [
      'sensors/temperature',
      'sensors/humidity',
      'sensors/pressure',
      'commands/led',
      'commands/relay',
      'backend/status'
    ]
  });
});

// WebSocket endpoint info
app.get('/api/websocket/info', (req, res) => {
  res.json({
    ws: `ws://${MQTT_BROKER_HOST}:${process.env.MQTT_WS_PORT || 8083}/mqtt`,
    wss: `wss://${MQTT_BROKER_HOST}:${process.env.MQTT_WSS_PORT || 8084}/mqtt`,
    protocol: 'MQTT 5.0'
  });
});

// Simulate sensor data (for testing)
app.post('/api/simulate/sensor', (req, res) => {
  const { sensorType = 'temperature' } = req.body;
  
  const sensorData = {
    temperature: { value: (Math.random() * 30 + 10).toFixed(2), unit: '°C' },
    humidity: { value: (Math.random() * 60 + 30).toFixed(2), unit: '%' },
    pressure: { value: (Math.random() * 100 + 950).toFixed(2), unit: 'hPa' }
  };

  const data = sensorData[sensorType] || sensorData.temperature;
  const topic = `sensors/${sensorType}`;
  const payload = JSON.stringify({
    ...data,
    timestamp: Date.now(),
    sensor_id: `sensor_${Math.random().toString(16).substring(2, 8)}`
  });

  mqttClient.publish(topic, payload, { qos: 1 }, (err) => {
    if (err) {
      return res.status(500).json({ error: 'Failed to simulate sensor' });
    }
    
    res.json({ success: true, topic, data: JSON.parse(payload) });
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Express error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, () => {
  logger.info(`🚀 Backend server running on port ${PORT}`);
  logger.info(`📊 Health check: http://localhost:${PORT}/health`);
  logger.info(`📡 MQTT Broker: ${mqttBrokerUrl}`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  logger.info('Shutting down gracefully...');
  
  mqttClient.publish(
    'backend/status',
    JSON.stringify({ status: 'offline', timestamp: Date.now() }),
    { qos: 1, retain: true },
    () => {
      mqttClient.end();
      process.exit(0);
    }
  );
});
