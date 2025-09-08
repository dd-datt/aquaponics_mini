#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>

// Pin definitions for ESP8266
#define DHT_PIN 2          // D4 (GPIO2) - DHT22 data
#include <Servo.h>
#define PUMP_PIN 14        // D5 (GPIO14) - Relay IN1 for pump (bơm lọc)
#define RELAY_LIGHT_PIN 12 // D6 (GPIO12) - Relay IN2 for light
#define AIR_PIN 5          // D1 (GPIO5)  - Relay IN3 for air (sủi khí)
#define PUMP_REFILL_PIN 16 // D0 (GPIO16) - Relay IN4 for pump_refill (bơm thường)
#define SERVO_PIN 4        // D2 (GPIO4)  - Servo SG90
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
bool pumpState = false;   // OFF by default (bơm lọc)
bool lightState = false;  // OFF by default
bool airState = false;    // OFF by default
bool pumpRefillState = false; // OFF by default
Servo feedServo;
unsigned long lastFeedTime = 0;
bool feeding = false;
int lastFeedAngle = 0;

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
void setAir(bool on) {
  airState = on;
  digitalWrite(AIR_PIN, on ? LOW : HIGH); // Relay active LOW
  Serial.print("Air ");
  Serial.println(on ? "ON" : "OFF");
}

void setPumpRefill(bool on) {
  pumpRefillState = on;
  digitalWrite(PUMP_REFILL_PIN, on ? LOW : HIGH); // Relay active LOW
  Serial.print("PumpRefill ");
  Serial.println(on ? "ON" : "OFF");
}

void doFeed(int angle, int holdMs) {
  if (feeding) return;
  feeding = true;
  feedServo.attach(SERVO_PIN);
  feedServo.write(angle);
  lastFeedAngle = angle;
  delay(holdMs);
  feedServo.write(0);
  delay(400);
  feedServo.detach();
  feeding = false;
  Serial.print("Feed: angle=");
  Serial.print(angle);
  Serial.print(", holdMs=");
  Serial.println(holdMs);
}
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
  pinMode(AIR_PIN, OUTPUT);
  pinMode(PUMP_REFILL_PIN, OUTPUT);
  pinMode(FLOAT_SWITCH_PIN, INPUT_PULLUP);

  // Ensure outputs are OFF by default
  digitalWrite(PUMP_PIN, LOW);        // Pump OFF
  digitalWrite(RELAY_LIGHT_PIN, HIGH); // Light OFF (relay inactive)
  digitalWrite(AIR_PIN, HIGH);        // Air OFF
  digitalWrite(PUMP_REFILL_PIN, HIGH); // Pump refill OFF

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

  // Auto control: refill pump when float switch LOW
  if (!waterLevel) {
    setPumpRefill(true);
  } else {
    setPumpRefill(false);
  }

  // Publish status periodically
  if (WiFi.status() == WL_CONNECTED && client.connected() &&
      millis() - lastPublishTime > PUBLISH_INTERVAL) {
    publishStatus();
    lastPublishTime = millis();
  }

  delay(100);
}

void setupWiFi() {
  Serial.println("==============================");
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);
  Serial.println("==============================");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {  // ~10s timeout
    delay(500);
    Serial.print(".");
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n==============================");
    Serial.println("Connected to WiFi!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
    Serial.println("==============================");
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
  // Parse JSON for multi-control
  if (msg.startsWith("{") && msg.endsWith("}")) {
    // crude parse for air, pump_refill, feed
    if (msg.indexOf("air") != -1) {
      int v = parseBoolValueAfter(msg, "air");
      if (v == 1) setAir(true);
      else if (v == 0) setAir(false);
    }
    if (msg.indexOf("pump_refill") != -1) {
      int v = parseBoolValueAfter(msg, "pump_refill");
      if (v == 1) setPumpRefill(true);
      else if (v == 0) setPumpRefill(false);
    }
    if (msg.indexOf("feed") != -1) {
      int a = msg.indexOf("angle");
      int h = msg.indexOf("hold_ms");
      int angle = 60;
      int hold = 700;
      if (a != -1) {
        int colon = msg.indexOf(':', a);
        int comma = msg.indexOf(',', colon);
        if (comma == -1) comma = msg.indexOf('}', colon);
        if (comma == -1) comma = msg.length();
        angle = msg.substring(colon+1, comma).toInt();
      }
      if (h != -1) {
        int colon = msg.indexOf(':', h);
        int comma = msg.indexOf(',', colon);
        if (comma == -1) comma = msg.indexOf('}', colon);
        if (comma == -1) comma = msg.length();
        hold = msg.substring(colon+1, comma).toInt();
      }
      doFeed(angle, hold);
    }
  }
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
  // ...existing code...
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
  statusMessage += "\"light\":" + String(lightState ? "true" : "false") + ",";
  statusMessage += "\"air\":" + String(airState ? "true" : "false") + ",";
  statusMessage += "\"pump_refill\":" + String(pumpRefillState ? "true" : "false");
  statusMessage += "}";

  if (!client.publish(MQTT_STATUS_TOPIC, statusMessage.c_str())) {
    Serial.println("Failed to publish status");
  }
}
