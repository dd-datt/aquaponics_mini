// ESP32-CAM: MJPEG stream + gửi ảnh định kỳ lên Flask AI server
// Copy code này, chỉnh lại SSID, PASSWORD, SERVER_URL cho phù hợp
#include <WiFi.h>
#include "esp_camera.h"
#include <WebServer.h>
#include <HTTPClient.h>

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

// ==== WIFI & SERVER CONFIG ====
const char* ssid = "B-LINK_5F35";
const char* password = "0123456789";
const char* SERVER_URL = "http://192.168.1.124:5001/predict";



// ==== GỬI ẢNH ĐỊNH KỲ ====
unsigned long lastSend = 0;
const unsigned long SEND_INTERVAL = 60000; // ms (60s = 1 phút)

void setup() {
  Serial.begin(115200);
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
  config.frame_size = FRAMESIZE_VGA; // 640x480, nét nhất mà ESP32-CAM hỗ trợ ổn định
  config.jpeg_quality = 10; // Chất lượng cao nhất (0 là cao nhất, 63 thấp nhất)
  config.fb_count = 1;
  if (esp_camera_init(&config) != ESP_OK) {
    Serial.println("Camera init failed");
    while (1);
  }
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500); Serial.print(".");
  }
  Serial.println("\nWiFi connected");
  Serial.print("IP: "); Serial.println(WiFi.localIP());
  // Không cần khởi động web server stream video
}

void loop() {
  // Định kỳ gửi ảnh lên Flask server mỗi 1 phút (60s)
  if (millis() - lastSend > SEND_INTERVAL) {
    sendImageToFlask();
    lastSend = millis();
    Serial.print("Captured and sent at: ");
    Serial.println(millis() / 1000);
  }
}



void sendImageToFlask() {
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Camera capture failed (Flask)");
    return;
  }
  HTTPClient http;
  String boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW";
  String bodyStart = "--" + boundary + "\r\nContent-Disposition: form-data; name=\"image\"; filename=\"capture.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n";
  String bodyEnd = "\r\n--" + boundary + "--\r\n";
  size_t totalSize = bodyStart.length() + fb->len + bodyEnd.length();
  uint8_t *multipartData = (uint8_t *)malloc(totalSize);
  if (!multipartData) {
    Serial.println("Failed to allocate memory for multipart data");
    esp_camera_fb_return(fb);
    return;
  }
  memcpy(multipartData, (uint8_t *)bodyStart.c_str(), bodyStart.length());
  memcpy(multipartData + bodyStart.length(), fb->buf, fb->len);
  memcpy(multipartData + bodyStart.length() + fb->len, (uint8_t *)bodyEnd.c_str(), bodyEnd.length());
  http.begin(SERVER_URL);
  http.addHeader("Content-Type", "multipart/form-data; boundary=" + boundary);
  int httpResponseCode = http.POST(multipartData, totalSize);
  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.println("Flask response: " + response);
  } else {
    Serial.printf("HTTP POST failed, error: %d\n", httpResponseCode);
  }
  http.end();
  free(multipartData);
  esp_camera_fb_return(fb);
}
