// ESP32-CAM: Chụp ảnh 1 phút/lần + nhận lệnh MQTT để chụp ngay
#include <WiFi.h>
#include "esp_camera.h"
#include <HTTPClient.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include "config.h"

// ==== CAMERA PINS (AI-Thinker) ====
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

WiFiClient espClient;
PubSubClient client(espClient);

// ==== TIMING ====
unsigned long lastSend = 0;
bool captureRequested = false; // Flag để chụp ảnh ngay khi có yêu cầu

void setup() {
  Serial.begin(115200);
  
  // Cấu hình camera
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_VGA; // 640x480
  config.jpeg_quality = 10; // Chất lượng cao nhất
  config.fb_count = 1;
  
  if (esp_camera_init(&config) != ESP_OK) {
    Serial.println("Camera init failed");
    while (1);
  }
  
  // Kết nối WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500); 
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");
  Serial.print("IP: "); 
  Serial.println(WiFi.localIP());
  
  // Cấu hình MQTT
  client.setServer(MQTT_BROKER, MQTT_PORT);
  client.setCallback(onMqttMessage);
  
  // Kết nối MQTT
  reconnectMqtt();
  
  Serial.println("ESP32-CAM ready - Auto capture every 60s + MQTT control");
}

void loop() {
  // Duy trì kết nối MQTT
  if (!client.connected()) {
    reconnectMqtt();
  }
  client.loop();
  
  // Chụp ảnh định kỳ mỗi 1 phút HOẶC khi có yêu cầu từ MQTT
  if ((millis() - lastSend > CAPTURE_INTERVAL) || captureRequested) {
    sendImageToFlask();
    lastSend = millis();
    captureRequested = false;
    
    Serial.print("Captured and sent at: ");
    Serial.println(millis() / 1000);
    
    // Báo trạng thái qua MQTT
    client.publish("aquaponics/status", "ESP32-CAM: Đã chụp và gửi ảnh");
  }
  
  delay(100); // Giảm CPU load
}

void reconnectMqtt() {
  // Kiểm tra kết nối TCP tới MQTT broker trước khi connect MQTT
  WiFiClient testClient;
  Serial.print("Testing TCP connection to MQTT broker...");
  if (!testClient.connect(MQTT_BROKER, MQTT_PORT)) {
    Serial.println("FAILED: Không thể kết nối TCP tới MQTT broker. Kiểm tra lại IP, cổng, firewall, broker.");
    delay(RECONNECT_INTERVAL);
    return;
  } else {
    Serial.println("OK");
    testClient.stop();
  }
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    if (client.connect(MQTT_CLIENT_ID)) {
      Serial.println("connected");
      client.subscribe(MQTT_CMD_TOPIC);
      client.publish("aquaponics/status", "ESP32-CAM: Đã kết nối MQTT");
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(RECONNECT_INTERVAL);
    }
  }
}

void onMqttMessage(char* topic, byte* payload, unsigned int length) {
  // Chuyển payload thành string
  String message = "";
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  
  Serial.print("Received MQTT: ");
  Serial.println(message);
  
  // Nếu nhận được lệnh chụp ảnh
  if (String(topic) == MQTT_CMD_TOPIC) {
    // Parse JSON
    StaticJsonDocument<200> doc;
    DeserializationError error = deserializeJson(doc, message);
    
    if (!error && doc["capture"] == true) {
      Serial.println("Capture requested via MQTT");
      captureRequested = true; // Set flag để chụp ngay trong loop()
    }
  }
}

void sendImageToFlask() {
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Camera capture failed");
    client.publish("aquaponics/status", "ESP32-CAM: Lỗi chụp ảnh");
    return;
  }
  
  HTTPClient http;
  String boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW";
  String bodyStart = "--" + boundary + "\r\nContent-Disposition: form-data; name=\"image\"; filename=\"capture.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n";
  String bodyEnd = "\r\n--" + boundary + "--\r\n";
  size_t totalSize = bodyStart.length() + fb->len + bodyEnd.length();
  
  uint8_t *multipartData = (uint8_t *)malloc(totalSize);
  if (!multipartData) {
    Serial.println("Failed to allocate memory");
    esp_camera_fb_return(fb);
    client.publish("aquaponics/status", "ESP32-CAM: Lỗi bộ nhớ");
    return;
  }
  
  memcpy(multipartData, (uint8_t *)bodyStart.c_str(), bodyStart.length());
  memcpy(multipartData + bodyStart.length(), fb->buf, fb->len);
  memcpy(multipartData + bodyStart.length() + fb->len, (uint8_t *)bodyEnd.c_str(), bodyEnd.length());
  
  http.begin(SERVER_URL "/predict");
  http.addHeader("Content-Type", "multipart/form-data; boundary=" + boundary);
  
  int httpResponseCode = http.POST(multipartData, totalSize);
  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.println("Flask response: " + response);
    client.publish("aquaponics/status", "ESP32-CAM: Đã gửi ảnh thành công");
  } else {
    Serial.printf("HTTP POST failed, error: %d\n", httpResponseCode);
    client.publish("aquaponics/status", "ESP32-CAM: Lỗi gửi ảnh");
  }
  
  http.end();
  free(multipartData);
  esp_camera_fb_return(fb);
}
