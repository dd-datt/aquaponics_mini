#include <WiFi.h>
#include <HTTPClient.h>
#include "esp_camera.h"

#include <PubSubClient.h>
#include "config.h"

// Camera pins for ESP32-CAM (AI-Thinker module)
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

// MQTT client
WiFiClient espClient;
PubSubClient client(espClient);

// Timing variables
unsigned long lastCaptureTime = 0;
unsigned long lastReconnectTime = 0;

void setup() {
  Serial.begin(115200);
  delay(100);

  // Initialize camera
  if (!setupCamera()) {
    Serial.println("Camera setup failed!");
    return;
  }

  // Connect to WiFi
  setupWiFi();

  // Setup MQTT
  client.setServer(MQTT_BROKER, MQTT_PORT);
  client.setCallback(mqttCallback);
}

void loop() {
  // Maintain MQTT connection
  if (!client.connected()) {
    if (millis() - lastReconnectTime > RECONNECT_INTERVAL) {
      lastReconnectTime = millis();
      reconnectMQTT();
    }
  }
  client.loop();

  // Capture and send image periodically
  if (millis() - lastCaptureTime > CAPTURE_INTERVAL) {
    captureAndSendImage();
    lastCaptureTime = millis();
  }

  delay(100);
}

bool setupCamera() {
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

  // Frame size and quality
  config.frame_size = FRAMESIZE_VGA;  // 640x480
  config.jpeg_quality = 12;           // 0-63, lower number = higher quality
  config.fb_count = 1;

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x", err);
    return false;
  }

  return true;
}

void setupWiFi() {
  Serial.println("Connecting to WiFi...");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("");
    Serial.println("WiFi connected");
    Serial.println("IP address: ");
    Serial.println(WiFi.localIP());
    // Publish trạng thái WiFi lên MQTT
    client.publish("aquaponics/status", "ESP32-CAM: WiFi connected");
  } else {
    Serial.println("");
    Serial.println("WiFi connection failed! Check credentials.");
    client.publish("aquaponics/status", "ESP32-CAM: WiFi connection failed");
  }
}

void reconnectMQTT() {
  Serial.println("Attempting MQTT connection...");
  if (client.connect(MQTT_CLIENT_ID)) {
    Serial.println("MQTT connected");
    client.subscribe(MQTT_CMD_TOPIC);
    client.publish("aquaponics/status", "ESP32-CAM: MQTT connected");
  } else {
    Serial.print("MQTT connection failed, rc=");
    Serial.println(client.state());
    client.publish("aquaponics/status", "ESP32-CAM: MQTT connection failed");
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

  // Check for capture command
  if (message.indexOf("\"capture\":true") != -1) {
    Serial.println("Received capture command");
    captureAndSendImage();
  }
}

void captureAndSendImage() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Cannot send image: WiFi not connected");
    client.publish("aquaponics/status", "ESP32-CAM: Cannot send image, WiFi not connected");
    return;
  }

  // Capture image
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Camera capture failed");
    client.publish("aquaponics/status", "ESP32-CAM: Camera capture failed");
    return;
  }

  Serial.printf("Captured image: %d bytes\n", fb->len);

  // Send to server
  if (sendImageToServer(fb->buf, fb->len)) {
    Serial.println("Image sent successfully");
    client.publish("aquaponics/status", "ESP32-CAM: Image sent successfully");
  } else {
    Serial.println("Failed to send image");
    client.publish("aquaponics/status", "ESP32-CAM: Failed to send image");
  }

  // Return frame buffer
  esp_camera_fb_return(fb);
}

bool sendImageToServer(uint8_t *imageData, size_t imageSize) {
  HTTPClient http;

  String url = String(SERVER_URL) + "/predict";
  http.begin(url);
  http.addHeader("Content-Type", "multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW");

  // Create multipart form data
  String boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW";
  String bodyStart = "--" + boundary + "\r\nContent-Disposition: form-data; name=\"image\"; filename=\"capture.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n";
  String bodyEnd = "\r\n--" + boundary + "--\r\n";

  size_t totalSize = bodyStart.length() + imageSize + bodyEnd.length();
  uint8_t *multipartData = (uint8_t *)malloc(totalSize);
  if (!multipartData) {
    Serial.println("Failed to allocate memory for multipart data");
    return false;
  }

  // Copy data
  memcpy(multipartData, (uint8_t *)bodyStart.c_str(), bodyStart.length());
  memcpy(multipartData + bodyStart.length(), imageData, imageSize);
  memcpy(multipartData + bodyStart.length() + imageSize, (uint8_t *)bodyEnd.c_str(), bodyEnd.length());

  int httpResponseCode = http.POST(multipartData, totalSize);

  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.println("Server response: " + response);
    http.end();
    free(multipartData);
    return true;
  } else {
    Serial.printf("HTTP POST failed, error: %d\n", httpResponseCode);
    http.end();
    free(multipartData);
    return false;
  }
}
