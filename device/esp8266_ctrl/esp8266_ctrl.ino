
// ========================
// Khai báo thư viện sử dụng
// ========================
#include <ESP8266WiFi.h>         // Kết nối WiFi
#include <PubSubClient.h>        // Kết nối MQTT
#include <DHT.h>                 // Đọc cảm biến nhiệt độ/độ ẩm DHT22
#include <Servo.h>               // Điều khiển servo
#include <ArduinoJson.h>         // Phân tích cú pháp JSON


// ========================
// Khai báo chân kết nối phần cứng
// ========================
#define DHT_PIN 2            // D4 (GPIO2) - DHT22 data
#define PUMP_PIN 14          // D5 (GPIO14) - Relay IN1 cho bơm lọc (active LOW)
#define RELAY_LIGHT_PIN 12   // D6 (GPIO12) - Relay IN2 cho đèn (active LOW)
#define AIR_PIN 5            // D1 (GPIO5)  - Relay IN3 cho máy sục khí (active LOW)
#define PUMP_REFILL_PIN 16   // D0 (GPIO16) - Relay IN4 cho bơm nước bổ sung (active LOW)
#define SERVO_PIN 4          // D2 (GPIO4)  - Servo SG90 cho cho ăn
#define FLOAT_SWITCH_PIN 13  // D7 (GPIO13) - Công tắc phao (INPUT_PULLUP)


// ========================
// Cấu hình MQTT
// ========================
#define MQTT_BROKER "broker.hivemq.com"      // Địa chỉ broker MQTT
#define MQTT_PORT 1883                       // Cổng MQTT
#define MQTT_CLIENT_ID "esp8266_aquaponics" // Tên client MQTT
#define MQTT_CMD_TOPIC "aquaponics/cmd"     // Chủ đề nhận lệnh
#define MQTT_STATUS_TOPIC "aquaponics/status" // Chủ đề gửi trạng thái


// ========================
// Cấu hình WiFi (có thể thay đổi qua MQTT)
// ========================
String wifiSsid = "B-LINK_5F35";      // Tên WiFi
String wifiPassword = "0123456789";   // Mật khẩu WiFi


// ========================
// Các thông số thời gian
// ========================
#define PUBLISH_INTERVAL 500     // Thời gian gửi trạng thái (ms)
#define RECONNECT_INTERVAL 5000  // Thời gian thử lại kết nối MQTT (ms)
#define FEED_HOLD_TIME 700       // Thời gian giữ servo khi cho ăn (ms)
#define FEED_DEFAULT_ANGLE 180   // Góc mặc định của servo khi cho ăn


// ========================
// Biến trạng thái và đối tượng cảm biến
// ========================
DHT dht(DHT_PIN, DHT22);                // Đối tượng cảm biến DHT22
WiFiClient espClient;                   // Đối tượng WiFi
PubSubClient client(espClient);         // Đối tượng MQTT

// Biến lưu trạng thái hệ thống
float temperature = 0.0;                // Nhiệt độ
float humidity = 0.0;                   // Độ ẩm
bool waterLevel = false;                // Mực nước (true=đầy, false=thiếu)
bool pumpState = false;                 // Trạng thái bơm lọc
bool lightState = false;                // Trạng thái đèn
bool airState = false;                  // Trạng thái máy sục khí
bool pumpRefillState = false;           // Trạng thái bơm bổ sung nước
Servo feedServo;                        // Đối tượng servo cho ăn
unsigned long lastFeedTime = 0;         // Thời gian lần cuối cho ăn
bool feeding = false;                   // Đang cho ăn hay không
unsigned long feedStartTime = 0;        // Thời gian bắt đầu cho ăn
int feedTargetAngle = 0;                // Góc servo khi cho ăn
enum FeedState { IDLE, MOVING_TO_ANGLE, HOLDING, RETURNING } feedState = IDLE; // Trạng thái cho ăn

// Biến thời gian cho các chức năng
unsigned long lastPublishTime = 0;      // Thời gian gửi trạng thái lần cuối
unsigned long lastReconnectTime = 0;    // Thời gian thử lại kết nối lần cuối

// ========================
// Hàm điều khiển các thiết bị (bơm, đèn, khí, bơm bổ sung, servo)
// ========================
// Hàm bật/tắt bơm lọc
void setPump(bool on) {
  pumpState = on;
  digitalWrite(PUMP_PIN, on ? LOW : HIGH); // Relay active LOW
  Serial.print("Pump "); Serial.println(on ? "ON" : "OFF");
}

// Hàm bật/tắt đèn
void setLight(bool on) {
  lightState = on;
  digitalWrite(RELAY_LIGHT_PIN, on ? LOW : HIGH); // Relay active LOW
  Serial.print("Light "); Serial.println(on ? "ON" : "OFF");
}

// Hàm bật/tắt máy sục khí
void setAir(bool on) {
  airState = on;
  digitalWrite(AIR_PIN, on ? LOW : HIGH); // Relay active LOW
  Serial.print("Air "); Serial.println(on ? "ON" : "OFF");
}

// Hàm bật/tắt bơm bổ sung nước
void setPumpRefill(bool on) {
  pumpRefillState = on;
  digitalWrite(PUMP_REFILL_PIN, on ? LOW : HIGH); // Relay active LOW
  Serial.print("PumpRefill "); Serial.println(on ? "ON" : "OFF");
}

// Hàm bắt đầu cho ăn bằng servo
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

// Xử lý cho ăn không chặn (non-blocking)
void handleFeed() {
  if (!feeding) return;

  unsigned long currentTime = millis();
  switch (feedState) {
    case MOVING_TO_ANGLE:
      if (currentTime - feedStartTime >= 400) { // Thời gian di chuyển đến góc cho ăn
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
      if (currentTime - feedStartTime >= 400) { // Thời gian trả về góc 0
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

// ========================
// Các hàm kết nối WiFi & MQTT
// ========================
// Hàm kết nối WiFi
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

// Hàm đổi thông tin WiFi
void changeWiFi(const char* ssid, const char* pass) {
  Serial.println("Changing WiFi credentials...");
  wifiSsid = String(ssid);
  wifiPassword = String(pass);
  WiFi.disconnect();
  delay(500);
  setupWiFi();
}

// Hàm kết nối lại MQTT
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

// ========================
// Hàm xử lý lệnh nhận qua MQTT (callback)
// ========================
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  // Nhận và xử lý lệnh từ MQTT
  String msg; msg.reserve(length + 1);
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  msg.trim();

  Serial.print("MQTT msg ["); Serial.print(topic); Serial.print("]: "); Serial.println(msg);

  // Chỉ xử lý các message dạng JSON
  if (!msg.startsWith("{") || !msg.endsWith("}")) {
    Serial.println("❌ Ignoring non-JSON message");
    return;
  }

  // Phân tích cú pháp JSON
  StaticJsonDocument<200> doc;
  DeserializationError error = deserializeJson(doc, msg);
  if (error) {
    Serial.print("❌ JSON parse error: "); Serial.println(error.c_str());
    return;
  }

  // Xử lý từng chức năng độc lập
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

// ========================
// Đọc cảm biến và gửi trạng thái lên MQTT
// ========================
// Đọc dữ liệu từ cảm biến
void readSensors() {
  float t = dht.readTemperature();
  float h = dht.readHumidity();
  if (!isnan(t) && !isnan(h)) {
    temperature = t;
    humidity = h;
  }
  waterLevel = (digitalRead(FLOAT_SWITCH_PIN) == HIGH);
}

// Gửi trạng thái hệ thống lên MQTT
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

// ========================
// Hàm khởi tạo (setup) và vòng lặp chính (loop)
// ========================
void setup() {
  // Khởi tạo các chân và đối tượng
  Serial.begin(115200);
  delay(100);

  pinMode(PUMP_PIN, OUTPUT);
  pinMode(RELAY_LIGHT_PIN, OUTPUT);
  pinMode(AIR_PIN, OUTPUT);
  pinMode(PUMP_REFILL_PIN, OUTPUT);
  pinMode(FLOAT_SWITCH_PIN, INPUT_PULLUP);

  // Đảm bảo các thiết bị tắt khi khởi động
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
  // Duy trì kết nối WiFi
  if (WiFi.status() != WL_CONNECTED && millis() - lastReconnectTime > RECONNECT_INTERVAL) {
    lastReconnectTime = millis();
    setupWiFi();
  }

  // Duy trì kết nối MQTT
  if (WiFi.status() == WL_CONNECTED && !client.connected() && millis() - lastReconnectTime > RECONNECT_INTERVAL) {
    lastReconnectTime = millis();
    reconnectMQTT();
  } else {
    client.loop();
  }

  readSensors(); // Đọc cảm biến
  
  // Điều khiển bơm bổ sung nước tự động theo mực nước
  if (!waterLevel && !pumpRefillState) {
    setPumpRefill(true);
  } else if (waterLevel && pumpRefillState) {
    setPumpRefill(false);
  }

  handleFeed(); // Xử lý servo cho ăn

  // Gửi trạng thái lên MQTT
  if (WiFi.status() == WL_CONNECTED && client.connected() && millis() - lastPublishTime > PUBLISH_INTERVAL) {
    publishStatus();
    lastPublishTime = millis();
  }

  delay(50); // Giảm delay để tăng độ phản hồi
}