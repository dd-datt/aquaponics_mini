#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>

// Pin definitions for ESP8266
#define DHT_PIN 2          // D4 (GPIO2) - DHT22 data
#define PUMP_PIN 14        // D5 (GPIO14) - Transistor/MOSFET for pump (3V-5V)
#define RELAY_LIGHT_PIN 12 // D6 (GPIO12) - Relay IN2 for light (12V)
#define FLOAT_SWITCH_PIN 13 // D7 (GPIO13) - Float switch

// MQTT Configuration
#define MQTT_BROKER "broker.hivemq.com"
#define MQTT_PORT 1883
#define MQTT_CLIENT_ID "esp8266_aquaponics"
#define MQTT_CMD_TOPIC "aquaponics/cmd"
#define MQTT_STATUS_TOPIC "aquaponics/status"

// WiFi Configuration (replace with your credentials)
#define WIFI_SSID "B-LINK_5F35"
#define WIFI_PASSWORD "0123456789"

// Timing
#define PUBLISH_INTERVAL 100   // Publish status every 0.1 second (100ms)
#define RECONNECT_INTERVAL 5000 // Reconnect MQTT every 5 seconds if disconnected

// DHT sensor
DHT dht(DHT_PIN, DHT22);

// MQTT client
WiFiClient espClient;
PubSubClient client(espClient);

// Variables
float temperature = 0.0;
float humidity = 0.0;
bool waterLevel = false;
bool pumpState = false;
bool lightState = false;

unsigned long lastPublishTime = 0;
unsigned long lastReconnectTime = 0;

void testComponents() {
  Serial.println("=== Component Test ===");

  // Test pump (transistor)
  Serial.println("Testing pump (3V-5V)...");
  digitalWrite(PUMP_PIN, HIGH); // Pump ON
  delay(2000);
  digitalWrite(PUMP_PIN, LOW); // Pump OFF

  // Test light relay
  Serial.println("Testing light relay...");
  digitalWrite(RELAY_LIGHT_PIN, LOW); // Relay ON
  delay(2000);
  digitalWrite(RELAY_LIGHT_PIN, HIGH); // Relay OFF

  Serial.println("Relays test complete");

  // Test float switch
  Serial.print("Float switch state: ");
  Serial.println(digitalRead(FLOAT_SWITCH_PIN));

  // Test DHT sensor
  Serial.print("DHT test - Temp: ");
  Serial.print(dht.readTemperature());
  Serial.print("°C, Humidity: ");
  Serial.print(dht.readHumidity());
  Serial.println("%");

  Serial.println("=== Test Complete ===");
}

void setup() {
  Serial.begin(115200);
  delay(100);

  // Initialize pins
  pinMode(PUMP_PIN, OUTPUT);
  pinMode(RELAY_LIGHT_PIN, OUTPUT);
  pinMode(FLOAT_SWITCH_PIN, INPUT_PULLUP);

  // Set outputs to OFF initially
  digitalWrite(PUMP_PIN, LOW); // Pump OFF (transistor)
  digitalWrite(RELAY_LIGHT_PIN, HIGH); // Light OFF (relay active LOW)

  // Initialize DHT sensor
  dht.begin();

  // Test components
  testComponents();
  delay(2000); // Wait for test to complete

  // Connect to WiFi
  setupWiFi();

  // Only setup MQTT if WiFi is connected
  if (WiFi.status() == WL_CONNECTED) {
    // Setup MQTT
    client.setServer(MQTT_BROKER, MQTT_PORT);
    client.setCallback(mqttCallback);
  } else {
    Serial.println("Skipping MQTT setup due to WiFi failure");
  }
}

void loop() {
  // Only handle MQTT if WiFi is connected
  if (WiFi.status() == WL_CONNECTED) {
    // Maintain MQTT connection
    if (!client.connected()) {
      if (millis() - lastReconnectTime > RECONNECT_INTERVAL) {
        lastReconnectTime = millis();
        reconnectMQTT();
      }
    }
    client.loop();
  } else {
    // Try to reconnect WiFi
    if (millis() - lastReconnectTime > RECONNECT_INTERVAL) {
      lastReconnectTime = millis();
      setupWiFi();
    }
  }

  // Read sensors
  readSensors();

  // Publish status periodically (only if connected)
  if (WiFi.status() == WL_CONNECTED && client.connected() &&
      millis() - lastPublishTime > PUBLISH_INTERVAL) {
    publishStatus();
    lastPublishTime = millis();
  }

  delay(100);
}

void setupWiFi() {
  Serial.println("Connecting to WiFi...");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {  // Timeout after 10 seconds
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("");
    Serial.println("WiFi connected");
    Serial.println("IP address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("");
    Serial.println("WiFi connection failed! Check credentials.");
  }
}

void reconnectMQTT() {
  Serial.println("Attempting MQTT connection...");
  if (client.connect(MQTT_CLIENT_ID)) {
    Serial.println("MQTT connected");
    client.subscribe(MQTT_CMD_TOPIC);
  } else {
    Serial.print("MQTT connection failed, rc=");
    Serial.println(client.state());
    // Try different client ID if connection fails
    String clientId = String(MQTT_CLIENT_ID) + String(random(0xffff), HEX);
    if (client.connect(clientId.c_str())) {
      Serial.println("MQTT connected with random client ID");
      client.subscribe(MQTT_CMD_TOPIC);
    }
  }
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");

  String message = "";
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.println(message);

  // Parse JSON command more robustly
  message.trim(); // Remove whitespace

  // Check for pump command
  int pumpIndex = message.indexOf("\"pump\"");
  if (pumpIndex != -1) {
    int colonIndex = message.indexOf(":", pumpIndex);
    if (colonIndex != -1) {
      int valueStart = message.indexOf("true", colonIndex);
      if (valueStart != -1 && valueStart < message.indexOf(",", colonIndex)) {
        pumpState = true;
        digitalWrite(PUMP_PIN, HIGH); // Pump ON (transistor HIGH)
      } else {
        int valueStart = message.indexOf("false", colonIndex);
        if (valueStart != -1 && valueStart < message.indexOf(",", colonIndex)) {
          pumpState = false;
          digitalWrite(PUMP_PIN, LOW); // Pump OFF (transistor LOW)
        }
      }
    }
  }

  // Check for light command
  int lightIndex = message.indexOf("\"light\"");
  if (lightIndex != -1) {
    int colonIndex = message.indexOf(":", lightIndex);
    if (colonIndex != -1) {
      int valueStart = message.indexOf("true", colonIndex);
      if (valueStart != -1 && valueStart < message.indexOf(",", colonIndex)) {
        lightState = true;
        digitalWrite(RELAY_LIGHT_PIN, LOW); // Relay ON
      } else {
        int valueStart = message.indexOf("false", colonIndex);
        if (valueStart != -1 && valueStart < message.indexOf(",", colonIndex)) {
          lightState = false;
          digitalWrite(RELAY_LIGHT_PIN, HIGH); // Relay OFF
        }
      }
    }
  }

  Serial.print("Pump: ");
  Serial.print(pumpState ? "ON" : "OFF");
  Serial.print(", Light: ");
  Serial.println(lightState ? "ON" : "OFF");
}

void readSensors() {
  // Read DHT22
  temperature = dht.readTemperature();
  humidity = dht.readHumidity();

  // Check if readings are valid
  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("Failed to read from DHT sensor!");
    temperature = 0.0;
    humidity = 0.0;
  }

  // Read float switch (LOW when water level is high - adjust logic based on your wiring)
  // If float switch is normally open: LOW = water high, HIGH = water low
  // If float switch is normally closed: HIGH = water high, LOW = water low
  waterLevel = (digitalRead(FLOAT_SWITCH_PIN) == LOW); // true = water level high

  Serial.print("Temperature: ");
  Serial.print(temperature);
  Serial.print("°C, Humidity: ");
  Serial.print(humidity);
  Serial.print("%, Water Level: ");
  Serial.println(waterLevel ? "HIGH" : "LOW");
}

void publishStatus() {
  if (!client.connected()) {
    Serial.println("Cannot publish: MQTT not connected");
    return;
  }

  String statusMessage = "{";
  statusMessage += "\"temp\":" + String(temperature) + ",";
  statusMessage += "\"humidity\":" + String(humidity) + ",";
  statusMessage += "\"water\":\"" + String(waterLevel ? "Đầy" : "Thấp") + "\",";
  statusMessage += "\"pump\":" + String(pumpState ? "true" : "false") + ",";
  statusMessage += "\"light\":" + String(lightState ? "true" : "false");
  statusMessage += "}";

  if (client.publish(MQTT_STATUS_TOPIC, statusMessage.c_str())) {
    Serial.println("Published status: " + statusMessage);
  } else {
    Serial.println("Failed to publish status");
  }
}
