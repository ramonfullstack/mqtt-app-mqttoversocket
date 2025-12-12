// MQTT Client Application
let client = null;
let stats = {
    sent: 0,
    received: 0,
    topics: new Set(),
    connectTime: null
};
let uptimeInterval = null;

// DOM Elements
const elements = {
    brokerUrl: document.getElementById('broker-url'),
    clientId: document.getElementById('client-id'),
    username: document.getElementById('username'),
    password: document.getElementById('password'),
    connectBtn: document.getElementById('connect-btn'),
    disconnectBtn: document.getElementById('disconnect-btn'),
    statusDot: document.getElementById('status-dot'),
    statusText: document.getElementById('status-text'),
    subscribeTopic: document.getElementById('subscribe-topic'),
    subscribeQos: document.getElementById('subscribe-qos'),
    subscribeBtn: document.getElementById('subscribe-btn'),
    topicsList: document.getElementById('topics-list'),
    publishTopic: document.getElementById('publish-topic'),
    publishMessage: document.getElementById('publish-message'),
    publishQos: document.getElementById('publish-qos'),
    publishRetain: document.getElementById('publish-retain'),
    publishBtn: document.getElementById('publish-btn'),
    messagesContainer: document.getElementById('messages-container'),
    clearMessagesBtn: document.getElementById('clear-messages-btn'),
    autoScroll: document.getElementById('auto-scroll'),
    statSent: document.getElementById('stat-sent'),
    statReceived: document.getElementById('stat-received'),
    statTopics: document.getElementById('stat-topics'),
    statUptime: document.getElementById('stat-uptime')
};

// Generate random client ID
function generateClientId() {
    return 'mqttjs_' + Math.random().toString(16).substring(2, 10);
}

// Initialize
function init() {
    elements.clientId.value = generateClientId();
    
    // Event listeners
    elements.connectBtn.addEventListener('click', connect);
    elements.disconnectBtn.addEventListener('click', disconnect);
    elements.subscribeBtn.addEventListener('click', subscribe);
    elements.publishBtn.addEventListener('click', publish);
    elements.clearMessagesBtn.addEventListener('click', clearMessages);
    
    // Enter key handlers
    elements.subscribeTopic.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') subscribe();
    });
    
    elements.publishMessage.addEventListener('keypress', (e) => {
        if (e.key === 'Enter' && e.ctrlKey) publish();
    });
    
    log('info', 'Aplicação iniciada. Pronta para conectar!');
}

// Connect to MQTT broker
function connect() {
    const brokerUrl = elements.brokerUrl.value.trim();
    const clientId = elements.clientId.value.trim();
    const username = elements.username.value.trim();
    const password = elements.password.value.trim();
    
    if (!brokerUrl) {
        alert('Por favor, insira a URL do broker');
        return;
    }
    
    log('info', `Conectando ao broker: ${brokerUrl}`);
    
    const options = {
        keepalive: 60,
        clientId: clientId,
        protocolId: 'MQTT',
        protocolVersion: 5,
        clean: true,
        reconnectPeriod: 1000,
        connectTimeout: 30 * 1000,
        will: {
            topic: 'client/status',
            payload: JSON.stringify({ 
                clientId: clientId, 
                status: 'offline', 
                timestamp: Date.now() 
            }),
            qos: 1,
            retain: true
        }
    };
    
    if (username) options.username = username;
    if (password) options.password = password;
    
    try {
        client = mqtt.connect(brokerUrl, options);
        
        client.on('connect', onConnect);
        client.on('error', onError);
        client.on('reconnect', onReconnect);
        client.on('message', onMessage);
        client.on('close', onClose);
        
    } catch (error) {
        log('error', `Erro ao conectar: ${error.message}`);
        updateConnectionStatus(false);
    }
}

// Event handlers
function onConnect() {
    log('success', '✅ Conectado ao broker MQTT!');
    updateConnectionStatus(true);
    stats.connectTime = Date.now();
    startUptimeCounter();
    
    // Publish online status
    if (client) {
        client.publish(
            'client/status',
            JSON.stringify({ 
                clientId: elements.clientId.value, 
                status: 'online', 
                timestamp: Date.now() 
            }),
            { qos: 1, retain: true }
        );
    }
}

function onError(err) {
    log('error', `❌ Erro: ${err.message}`);
    updateConnectionStatus(false);
}

function onReconnect() {
    log('warning', '🔄 Reconectando...');
}

function onMessage(topic, message, packet) {
    stats.received++;
    updateStats();
    
    const payload = message.toString();
    log('message', `📨 [${topic}] ${payload}`);
    
    // Add message to container
    addMessageToUI(topic, payload, 'received');
}

function onClose() {
    log('warning', 'Conexão fechada');
    updateConnectionStatus(false);
    stopUptimeCounter();
}

// Disconnect from broker
function disconnect() {
    if (client) {
        // Publish offline status before disconnecting
        client.publish(
            'client/status',
            JSON.stringify({ 
                clientId: elements.clientId.value, 
                status: 'offline', 
                timestamp: Date.now() 
            }),
            { qos: 1, retain: true },
            () => {
                client.end();
                client = null;
                log('info', 'Desconectado do broker');
                updateConnectionStatus(false);
                stopUptimeCounter();
            }
        );
    }
}

// Subscribe to topic
function subscribe() {
    if (!client || !client.connected) {
        alert('Não conectado ao broker');
        return;
    }
    
    const topic = elements.subscribeTopic.value.trim();
    const qos = parseInt(elements.subscribeQos.value);
    
    if (!topic) {
        alert('Por favor, insira um tópico');
        return;
    }
    
    client.subscribe(topic, { qos }, (err) => {
        if (err) {
            log('error', `Erro ao inscrever em ${topic}: ${err.message}`);
        } else {
            stats.topics.add(topic);
            updateStats();
            log('success', `📡 Inscrito em: ${topic} (QoS ${qos})`);
            addTopicToList(topic, qos);
            elements.subscribeTopic.value = '';
        }
    });
}

// Publish message
function publish() {
    if (!client || !client.connected) {
        alert('Não conectado ao broker');
        return;
    }
    
    const topic = elements.publishTopic.value.trim();
    const message = elements.publishMessage.value.trim();
    const qos = parseInt(elements.publishQos.value);
    const retain = elements.publishRetain.checked;
    
    if (!topic || !message) {
        alert('Por favor, preencha tópico e mensagem');
        return;
    }
    
    client.publish(topic, message, { qos, retain }, (err) => {
        if (err) {
            log('error', `Erro ao publicar: ${err.message}`);
        } else {
            stats.sent++;
            updateStats();
            log('success', `📤 Publicado em ${topic}: ${message}`);
            addMessageToUI(topic, message, 'sent');
        }
    });
}

// Quick actions
function quickSubscribe(topic) {
    if (!client || !client.connected) {
        alert('Não conectado ao broker');
        return;
    }
    
    elements.subscribeTopic.value = topic;
    subscribe();
}

function quickPublish(topic, data) {
    if (!client || !client.connected) {
        alert('Não conectado ao broker');
        return;
    }
    
    elements.publishTopic.value = topic;
    elements.publishMessage.value = JSON.stringify(data);
    publish();
}

async function simulateSensor() {
    if (!client || !client.connected) {
        alert('Não conectado ao broker');
        return;
    }
    
    try {
        const response = await fetch('http://localhost:3000/api/simulate/sensor', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ sensorType: 'temperature' })
        });
        
        if (response.ok) {
            log('success', '🌡️ Dados de sensor simulados com sucesso');
        }
    } catch (error) {
        log('warning', 'Backend não disponível. Usando simulação local...');
        
        // Local simulation fallback
        const sensorData = {
            value: (Math.random() * 30 + 10).toFixed(2),
            unit: '°C',
            timestamp: Date.now()
        };
        
        client.publish('sensors/temperature', JSON.stringify(sensorData), { qos: 1 });
    }
}

// UI helper functions
function updateConnectionStatus(connected) {
    elements.connectBtn.disabled = connected;
    elements.disconnectBtn.disabled = !connected;
    elements.subscribeBtn.disabled = !connected;
    elements.publishBtn.disabled = !connected;
    
    if (connected) {
        elements.statusDot.className = 'status-dot connected';
        elements.statusText.textContent = 'Conectado';
    } else {
        elements.statusDot.className = 'status-dot disconnected';
        elements.statusText.textContent = 'Desconectado';
    }
}

function addTopicToList(topic, qos) {
    const li = document.createElement('li');
    li.innerHTML = `
        <span class="topic-name">${topic}</span>
        <span class="topic-qos">QoS ${qos}</span>
        <button class="btn-unsubscribe" onclick="unsubscribe('${topic}')">×</button>
    `;
    elements.topicsList.appendChild(li);
}

function unsubscribe(topic) {
    if (!client || !client.connected) return;
    
    client.unsubscribe(topic, (err) => {
        if (!err) {
            stats.topics.delete(topic);
            updateStats();
            log('info', `Desinscrito de: ${topic}`);
            
            // Remove from UI
            const items = elements.topicsList.getElementsByTagName('li');
            for (let item of items) {
                if (item.querySelector('.topic-name').textContent === topic) {
                    item.remove();
                    break;
                }
            }
        }
    });
}

function addMessageToUI(topic, payload, type) {
    const messageDiv = document.createElement('div');
    messageDiv.className = `message message-${type}`;
    
    const timestamp = new Date().toLocaleTimeString('pt-BR');
    const icon = type === 'sent' ? '📤' : '📨';
    
    messageDiv.innerHTML = `
        <div class="message-header">
            <span class="message-icon">${icon}</span>
            <span class="message-topic">${topic}</span>
            <span class="message-time">${timestamp}</span>
        </div>
        <div class="message-payload">${payload}</div>
    `;
    
    elements.messagesContainer.appendChild(messageDiv);
    
    if (elements.autoScroll.checked) {
        elements.messagesContainer.scrollTop = elements.messagesContainer.scrollHeight;
    }
}

function clearMessages() {
    elements.messagesContainer.innerHTML = '';
    log('info', 'Mensagens limpas');
}

function log(type, message) {
    console.log(`[${type.toUpperCase()}] ${message}`);
}

function updateStats() {
    elements.statSent.textContent = stats.sent;
    elements.statReceived.textContent = stats.received;
    elements.statTopics.textContent = stats.topics.size;
}

function startUptimeCounter() {
    uptimeInterval = setInterval(() => {
        if (stats.connectTime) {
            const uptime = Date.now() - stats.connectTime;
            const hours = Math.floor(uptime / 3600000);
            const minutes = Math.floor((uptime % 3600000) / 60000);
            const seconds = Math.floor((uptime % 60000) / 1000);
            
            elements.statUptime.textContent = 
                `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
        }
    }, 1000);
}

function stopUptimeCounter() {
    if (uptimeInterval) {
        clearInterval(uptimeInterval);
        uptimeInterval = null;
        elements.statUptime.textContent = '00:00:00';
        stats.connectTime = null;
    }
}

// Initialize application
document.addEventListener('DOMContentLoaded', init);
