#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <Servo.h>
#include <ArduinoJson.h> // Thêm thư viện ArduinoJson để phân tích JSON dễ dàng hơn

// Pin definitions for ESP8266
#define DHT_PIN 2            // D4 (GPIO2) - DHT22 data
#define PUMP_PIN 14          // D5 (GPIO14) - Relay IN1 for pump (bơm lọc) - active LOW
#define RELAY_LIGHT_PIN 12   // D6 (GPIO12) - Relay IN2 for light       - active LOW
#define AIR_PIN 5            // D1 (GPIO5)  - Relay IN3 for air         - active LOW
#define PUMP_REFILL_PIN 16   // D0 (GPIO16) - Relay IN4 for pump_refill - active LOW
#define SERVO_PIN 4          // D2 (GPIO4)  - Servo SG90
#define FLOAT_SWITCH_PIN 13  // D7 (GPIO13) - Float switch (INPUT_PULLUP)

// MQTT Configuration
#define MQTT_BROKER "broker.hivemq.com"
#define MQTT_PORT 1883
#define MQTT_CLIENT_ID "esp8266_aquaponics"
#define MQTT_CMD_TOPIC "aquaponics/cmd"
#define MQTT_STATUS_TOPIC "aquaponics/status"

// WiFi Configuration (có thể thay đổi động qua MQTT)
String wifiSsid = "B-LINK_5F35";
String wifiPassword = "0123456789";

// Timing
#define PUBLISH_INTERVAL 500     // Publish status every 0.5 second
#define RECONNECT_INTERVAL 5000  // Reconnect MQTT every 5 seconds if disconnected
#define FEED_HOLD_TIME 700       // Default hold time for servo feeding
#define FEED_DEFAULT_ANGLE 180   // Default angle for servo feeding (tối đa)

// DHT sensor
DHT dht(DHT_PIN, DHT22);

// MQTT client
WiFiClient espClient;
PubSubClient client(espClient);

// State variables (defaults OFF)
float temperature = 0.0;
float humidity = 0.0;
bool waterLevel = false;        // true=FULL (HIGH), false=LOW
bool pumpState = false;         // OFF by default (bơm lọc)
bool lightState = false;        // OFF by default
bool airState = false;          // OFF by default
bool pumpRefillState = false;   // OFF by default
Servo feedServo;
unsigned long lastFeedTime = 0;
bool feeding = false;
unsigned long feedStartTime = 0;
int feedTargetAngle = 0;
enum FeedState { IDLE, MOVING_TO_ANGLE, HOLDING, RETURNING } feedState = IDLE;

// Timing variables
unsigned long lastPublishTime = 0;
unsigned long lastReconnectTime = 0;

// ---------- Helpers: actuators ----------
void setPump(bool on) {
  pumpState = on;
  digitalWrite(PUMP_PIN, on ? LOW : HIGH); // Relay active LOW
  Serial.print("Pump "); Serial.println(on ? "ON" : "OFF");
}

void setLight(bool on) {
  lightState = on;
  digitalWrite(RELAY_LIGHT_PIN, on ? LOW : HIGH); // Relay active LOW
  Serial.print("Light "); Serial.println(on ? "ON" : "OFF");
}

void setAir(bool on) {
  airState = on;
  digitalWrite(AIR_PIN, on ? LOW : HIGH); // Relay active LOW
  Serial.print("Air "); Serial.println(on ? "ON" : "OFF");
}

void setPumpRefill(bool on) {
  pumpRefillState = on;
  digitalWrite(PUMP_REFILL_PIN, on ? LOW : HIGH); // Relay active LOW
  Serial.print("PumpRefill "); Serial.println(on ? "ON" : "OFF");
}

void startFeed(int angle, int holdMs) {
  if (feeding) return;
  feeding = true;
  feedState = MOVING_TO_ANGLE;
  feedTargetAngle = angle;
  feedServo.attach(SERVO_PIN);
  feedServo.write(angle);
  feedStartTime = millis();
  Serial.print("Feed started: angle="); Serial.print(angle);
  Serial.print(", holdMs="); Serial.println(holdMs);
}

// Non-blocking feed handling
void handleFeed() {
  if (!feeding) return;

  unsigned long currentTime = millis();
  switch (feedState) {
    case MOVING_TO_ANGLE:
      if (currentTime - feedStartTime >= 400) { // Time to reach angle
        feedState = HOLDING;
        feedStartTime = currentTime;
      }
      break;
    case HOLDING:
      if (currentTime - feedStartTime >= FEED_HOLD_TIME) {
        feedServo.write(0);
        feedState = RETURNING;
        feedStartTime = currentTime;
      }
      break;
    case RETURNING:
      if (currentTime - feedStartTime >= 400) { // Time to return to 0
        feedServo.detach();
        feeding = false;
        feedState = IDLE;
        Serial.println("Feed completed");
      }
      break;
    default:
      break;
  }
}

// ---------- WiFi & MQTT ----------
void setupWiFi() {
  Serial.println("==============================");
  Serial.print("Connecting to WiFi: "); Serial.println(wifiSsid);
  WiFi.begin(wifiSsid.c_str(), wifiPassword.c_str());

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nConnected to WiFi!");
    Serial.print("IP Address: "); Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nWiFi connection failed (check credentials)");
  }
}

// Hàm đổi WiFi credentials
void changeWiFi(const char* ssid, const char* pass) {
  Serial.println("Changing WiFi credentials...");
  wifiSsid = String(ssid);
  wifiPassword = String(pass);
  WiFi.disconnect();
  delay(500);
  setupWiFi();
}

void reconnectMQTT() {
  Serial.println("Attempting MQTT connection...");
  String clientId = String(MQTT_CLIENT_ID) + String(random(0xffff), HEX);
  if (client.connect(clientId.c_str())) {
    Serial.println("MQTT connected");
    client.subscribe(MQTT_CMD_TOPIC);
    Serial.println("✅ Subscribed to: " + String(MQTT_CMD_TOPIC));
  } else {
    Serial.print("MQTT connection failed, rc="); Serial.println(client.state());
  }
}

// ---------- MQTT callback (INDEPENDENT BUTTON CONTROL) ----------
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String msg; msg.reserve(length + 1);
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  msg.trim();

  Serial.print("MQTT msg ["); Serial.print(topic); Serial.print("]: "); Serial.println(msg);

  // Chỉ xử lý JSON messages
  if (!msg.startsWith("{") || !msg.endsWith("}")) {
    Serial.println("❌ Ignoring non-JSON message");
    return;
  }

  // Sử dụng ArduinoJson để phân tích
  StaticJsonDocument<200> doc;
  DeserializationError error = deserializeJson(doc, msg);
  if (error) {
    Serial.print("❌ JSON parse error: "); Serial.println(error.c_str());
    return;
  }

  // MỖI NÚT 1 CHỨC NĂNG - HOÀN TOÀN ĐỘC LẬP
  if (doc.containsKey("pump")) {
    bool value = doc["pump"];
    setPump(value);
    Serial.println(value ? "🟢 PUMP ONLY: ON" : "🔴 PUMP ONLY: OFF");
  }

  if (doc.containsKey("light")) {
    bool value = doc["light"];
    setLight(value);
    Serial.println(value ? "🟡 LIGHT ONLY: ON" : "⚫ LIGHT ONLY: OFF");
  }

  if (doc.containsKey("air")) {
    bool value = doc["air"];
    setAir(value);
    Serial.println(value ? "🔵 AIR ONLY: ON" : "⚪ AIR ONLY: OFF");
  }

  if (doc.containsKey("feed")) {
    int angle = doc["feed"].containsKey("angle") ? doc["feed"]["angle"] : FEED_DEFAULT_ANGLE;
    int holdMs = doc["feed"].containsKey("hold_ms") ? doc["feed"]["hold_ms"] : FEED_HOLD_TIME;
    startFeed(angle, holdMs);
    Serial.println("🍽️ FEED ONLY: Executed");
  }

  // Nhận lệnh đổi WiFi
  if (doc.containsKey("wifi")) {
    const char* ssid = doc["wifi"]["ssid"] | "";
    const char* pass = doc["wifi"]["pass"] | "";
    if (strlen(ssid) > 0) {
      changeWiFi(ssid, pass);
      Serial.println("✅ WiFi credentials updated via MQTT");
    } else {
      Serial.println("❌ WiFi SSID missing in command");
    }
  }

  Serial.println("✅ Command processed - Each device independent");
}

// ---------- Sensors & status ----------
void readSensors() {
  float t = dht.readTemperature();
  float h = dht.readHumidity();
  if (!isnan(t) && !isnan(h)) {
    temperature = t;
    humidity = h;
  }
  waterLevel = (digitalRead(FLOAT_SWITCH_PIN) == HIGH);
}

void publishStatus() {
  if (!client.connected()) return;

  StaticJsonDocument<200> doc;
  doc["temp"] = temperature;
  doc["humidity"] = humidity;
  doc["water"] = waterLevel;
  doc["pump"] = pumpState;
  doc["light"] = lightState;
  doc["air"] = airState;
  doc["pump_refill"] = pumpRefillState;

  String statusMessage;
  serializeJson(doc, statusMessage);
  
  if (!client.publish(MQTT_STATUS_TOPIC, statusMessage.c_str())) {
    Serial.println("Failed to publish status");
  } else {
    Serial.println("Status published: " + statusMessage);
  }
}

// ---------- Setup & Loop ----------
void setup() {
  Serial.begin(115200);
  delay(100);

  pinMode(PUMP_PIN, OUTPUT);
  pinMode(RELAY_LIGHT_PIN, OUTPUT);
  pinMode(AIR_PIN, OUTPUT);
  pinMode(PUMP_REFILL_PIN, OUTPUT);
  pinMode(FLOAT_SWITCH_PIN, INPUT_PULLUP);

  // Ensure outputs are OFF by default
  digitalWrite(PUMP_PIN, HIGH);
  digitalWrite(RELAY_LIGHT_PIN, HIGH);
  digitalWrite(AIR_PIN, HIGH);
  digitalWrite(PUMP_REFILL_PIN, HIGH);

  dht.begin();
  setupWiFi();
  client.setServer(MQTT_BROKER, MQTT_PORT);
  client.setCallback(mqttCallback);
}

void loop() {
  // Maintain WiFi
  if (WiFi.status() != WL_CONNECTED && millis() - lastReconnectTime > RECONNECT_INTERVAL) {
    lastReconnectTime = millis();
    setupWiFi();
  }

  // Maintain MQTT
  if (WiFi.status() == WL_CONNECTED && !client.connected() && millis() - lastReconnectTime > RECONNECT_INTERVAL) {
    lastReconnectTime = millis();
    reconnectMQTT();
  } else {
    client.loop();
  }

  readSensors();
  
  // Điều khiển bơm thường (refill) theo mực nước (tự động)
  if (!waterLevel && !pumpRefillState) {
    setPumpRefill(true);
  } else if (waterLevel && pumpRefillState) {
    setPumpRefill(false);
  }

  // Xử lý servo feeding không chặn
  handleFeed();

  // Publish status
  if (WiFi.status() == WL_CONNECTED && client.connected() && millis() - lastPublishTime > PUBLISH_INTERVAL) {
    publishStatus();
    lastPublishTime = millis();
  }

  delay(50); // Giảm delay để tăng responsiveness
}