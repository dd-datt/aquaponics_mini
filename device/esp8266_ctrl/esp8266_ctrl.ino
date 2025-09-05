#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>

// Pin definitions for ESP8266
#define DHT_PIN 2          // D4 (GPIO2) - DHT22 data
#define PUMP_PIN 12        // D6 (GPIO12) - Transistor/MOSFET for pump (3V-5V)
#define RELAY_LIGHT_PIN 5  // D1 (GPIO5) - Relay IN2 for light (12V), active LOW
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
#define PUBLISH_INTERVAL 1000   // Publish status every 1 second
#define RECONNECT_INTERVAL 5000 // Reconnect MQTT every 5 seconds if disconnected

// DHT sensor
DHT dht(DHT_PIN, DHT22);

// MQTT client
WiFiClient espClient;
PubSubClient client(espClient);

// State variables (defaults OFF)
float temperature = 0.0;
float humidity = 0.0;
bool waterLevel = false;
bool pumpState = false;   // OFF by default
bool lightState = false;  // OFF by default

unsigned long lastPublishTime = 0;
unsigned long lastReconnectTime = 0;

// Helper to set pump output (centralized mapping)
void setPump(bool on) {
  pumpState = on;
  // Transistor/MOSFET: HIGH = ON, LOW = OFF
  digitalWrite(PUMP_PIN, on ? HIGH : LOW);
  Serial.print("Pump ");
  Serial.println(on ? "ON" : "OFF");
}

// Helper to set light output (relay active LOW)
void setLight(bool on) {
  lightState = on;
  // Relay is active LOW: LOW = ON, HIGH = OFF
  digitalWrite(RELAY_LIGHT_PIN, on ? LOW : HIGH);
  Serial.print("Light ");
  Serial.println(on ? "ON" : "OFF");
}

void setup() {
  Serial.begin(115200);
  delay(100);

  // Initialize pins
  pinMode(PUMP_PIN, OUTPUT);
  pinMode(RELAY_LIGHT_PIN, OUTPUT);
  pinMode(FLOAT_SWITCH_PIN, INPUT_PULLUP);

  // Ensure outputs are OFF by default
  digitalWrite(PUMP_PIN, LOW);        // Pump OFF
  digitalWrite(RELAY_LIGHT_PIN, HIGH); // Light OFF (relay inactive)

  // Initialize DHT sensor
  dht.begin();

  // Connect to WiFi and MQTT
  setupWiFi();
  client.setServer(MQTT_BROKER, MQTT_PORT);
  client.setCallback(mqttCallback);
}

void loop() {
  // Maintain WiFi
  if (WiFi.status() != WL_CONNECTED) {
    if (millis() - lastReconnectTime > RECONNECT_INTERVAL) {
      lastReconnectTime = millis();
      setupWiFi();
    }
  }

  // Maintain MQTT
  if (WiFi.status() == WL_CONNECTED) {
    if (!client.connected()) {
      if (millis() - lastReconnectTime > RECONNECT_INTERVAL) {
        lastReconnectTime = millis();
        reconnectMQTT();
      }
    } else {
      client.loop();
    }
  }

  // Read sensors (non-blocking-ish)
  readSensors();

  // Publish status periodically
  if (WiFi.status() == WL_CONNECTED && client.connected() &&
      millis() - lastPublishTime > PUBLISH_INTERVAL) {
    publishStatus();
    lastPublishTime = millis();
  }

  delay(100);
}

void setupWiFi() {
  Serial.print("Connecting to WiFi '");
  Serial.print(WIFI_SSID);
  Serial.println("'...");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {  // ~10s timeout
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nWiFi connection failed (check credentials)");
  }
}

void reconnectMQTT() {
  Serial.println("Attempting MQTT connection...");
  if (client.connect(MQTT_CLIENT_ID)) {
    Serial.println("MQTT connected");
    // Subscribe to generic and topic-specific commands (both supported)
    client.subscribe(MQTT_CMD_TOPIC);
    client.subscribe("aquaponics/cmd/pump");
    client.subscribe("aquaponics/cmd/light");
  } else {
    Serial.print("MQTT connection failed, rc=");
    Serial.println(client.state());
    // try random client id once
    String clientId = String(MQTT_CLIENT_ID) + String(random(0xffff), HEX);
    if (client.connect(clientId.c_str())) {
      Serial.println("MQTT connected with random client ID");
      client.subscribe(MQTT_CMD_TOPIC);
      client.subscribe("aquaponics/cmd/pump");
      client.subscribe("aquaponics/cmd/light");
    }
  }
}

// Simple, robust payload parsing for ON/OFF commands.
// Accepts payloads like: "ON", "OFF", "1", "0", "true", "false", or JSON like "{\"pump\":true}".
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String msg = "";
  for (unsigned int i = 0; i < length; i++) {
    msg += (char)payload[i];
  }
  msg.trim();
  msg.toLowerCase();

  Serial.print("MQTT msg [");
  Serial.print(topic);
  Serial.print("]: ");
  Serial.println(msg);

  // Helper: parse boolean value that follows a specific key in the payload
  // Returns: 1 (true/on/1), 0 (false/off/0), -1 unknown/not found
  auto parseBoolValueAfter = [&](const String &payload, const String &key) -> int {
    int k = payload.indexOf(key);
    if (k == -1) return -1;
    int colon = payload.indexOf(':', k);
    if (colon == -1) return -1;
    // look in the substring after the colon for known tokens until next comma/brace
    int endPos = payload.indexOf(',', colon);
    int bracePos = payload.indexOf('}', colon);
    if (endPos == -1 || (bracePos != -1 && bracePos < endPos)) endPos = bracePos;
    if (endPos == -1) endPos = payload.length();
    String part = payload.substring(colon + 1, endPos);
    part.trim();
    // remove surrounding quotes if present
    if (part.startsWith("\"") && part.endsWith("\"") && part.length() >= 2) {
      part = part.substring(1, part.length() - 1);
    }
    part.toLowerCase();
    if (part.indexOf("on") != -1) return 1;
    if (part.indexOf("off") != -1) return 0;
    if (part.indexOf("true") != -1) return 1;
    if (part.indexOf("false") != -1) return 0;
    if (part == "1") return 1;
    if (part == "0") return 0;
    return -1;
  };

  // If topic specifically addresses pump or light, use the payload directly
  String top = String(topic);
  if (top.endsWith("/pump")) {
    int v = parseBoolValueAfter(msg, "pump");
    if (v == -1) v = parseBoolValueAfter(msg, ""); // fallback: try whole payload
    if (v == 1) setPump(true);
    else if (v == 0) setPump(false);
    return;
  }
  if (top.endsWith("/light")) {
    int v = parseBoolValueAfter(msg, "light");
    if (v == -1) v = parseBoolValueAfter(msg, "");
    if (v == 1) setLight(true);
    else if (v == 0) setLight(false);
    return;
  }

  // Generic command topic: check for keywords
  if (msg.indexOf("pump") != -1) {
    int v = parseBoolValueAfter(msg, "pump");
    if (v == 1) setPump(true);
    else if (v == 0) setPump(false);
  }

  if (msg.indexOf("light") != -1) {
    int v = parseBoolValueAfter(msg, "light");
    if (v == 1) setLight(true);
    else if (v == 0) setLight(false);
  }
}

void readSensors() {
  // Read DHT22 (non-blocking read is limited by library)
  float t = dht.readTemperature();
  float h = dht.readHumidity();
  if (!isnan(t) && !isnan(h)) {
    temperature = t;
    humidity = h;
  }

  // Read float switch (adjust logic as needed for your wiring)
  waterLevel = (digitalRead(FLOAT_SWITCH_PIN) == HIGH);
}

void publishStatus() {
  if (!client.connected()) return;

  String statusMessage = "{";
  statusMessage += "\"temp\":" + String(temperature) + ",";
  statusMessage += "\"humidity\":" + String(humidity) + ",";
  statusMessage += "\"water\":\"" + String(waterLevel ? "FULL" : "LOW") + "\",";
  statusMessage += "\"pump\":" + String(pumpState ? "true" : "false") + ",";
  statusMessage += "\"light\":" + String(lightState ? "true" : "false");
  statusMessage += "}";

  if (!client.publish(MQTT_STATUS_TOPIC, statusMessage.c_str())) {
    Serial.println("Failed to publish status");
  }
}
