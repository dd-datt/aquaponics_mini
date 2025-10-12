
// ========================
// Khai báo thư viện sử dụng
// ========================
#include <Preferences.h>   // Lưu trữ dữ liệu vào flash (EEPROM)
#include <WiFi.h>          // Kết nối WiFi
#include <HTTPClient.h>    // Gửi HTTP request
#include "esp_camera.h"   // Điều khiển camera ESP32-CAM
#include <PubSubClient.h>  // Kết nối MQTT
#include "config.h"       // File cấu hình riêng

#// ========================
#// Khai báo chân kết nối camera ESP32-CAM (AI-Thinker)
#// ========================
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


// Chân điều khiển đèn flash
#define FLASH_LED_PIN     4


// ========================
// Biến toàn cục: MQTT, WiFi, lưu trữ cấu hình
// ========================
WiFiClient espClient;           // Đối tượng WiFi
Preferences preferences;        // Đối tượng lưu trữ cấu hình
// Đọc SSID/PASSWORD từ flash nếu có
preferences.begin("wifi", false);
String ssid = preferences.getString("ssid", WIFI_SSID);
String pass = preferences.getString("pass", WIFI_PASSWORD);
preferences.end();
// Gán lại SSID/PASSWORD cho biến toàn cục
strcpy(wifi_ssid, ssid.c_str());
strcpy(wifi_pass, pass.c_str());
PubSubClient client(espClient); // Đối tượng MQTT


// ========================
// Biến thời gian cho các chức năng
// ========================
unsigned long lastCaptureTime = 0;     // Thời gian chụp ảnh lần cuối
unsigned long lastReconnectTime = 0;   // Thời gian thử lại kết nối MQTT lần cuối


// ========================
// Hàm khởi tạo (setup)
// ========================
void setup() {
  Serial.begin(115200);         // Khởi tạo Serial
  delay(100);

  // Khởi tạo chân đèn flash
  pinMode(FLASH_LED_PIN, OUTPUT);
  digitalWrite(FLASH_LED_PIN, LOW);  // Tắt flash khi khởi động

  // Khởi tạo camera
  if (!setupCamera()) {
    Serial.println("Camera setup failed!");
    while (true) {
      delay(1000);
    }
  }

  // Kết nối WiFi
  setupWiFi();

  // Kết nối MQTT
  client.setServer(MQTT_BROKER, MQTT_PORT);
  client.setCallback(mqttCallback);
}


// ========================
// Vòng lặp chính (loop)
// ========================
void loop() {
  // Hiển thị trạng thái WiFi liên tục trên Serial
  static unsigned long lastWiFiStatusPrint = 0;
  if (millis() - lastWiFiStatusPrint > 2000) {
    lastWiFiStatusPrint = millis();
    if (WiFi.status() == WL_CONNECTED) {
      Serial.print("WiFi connected, IP: ");
      Serial.println(WiFi.localIP());
    } else {
      Serial.println("WiFi disconnected, attempting to reconnect...");
    }
  }

  // Tối ưu reconnect WiFi: chỉ thử reconnect mỗi 5 giây
  static unsigned long lastWiFiReconnect = 0;
  if (WiFi.status() != WL_CONNECTED) {
    if (millis() - lastWiFiReconnect > 5000) {
      lastWiFiReconnect = millis();
      WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
      Serial.println("WiFi reconnecting...");
    }
  }

  // Duy trì kết nối MQTT
  if (!client.connected()) {
    if (millis() - lastReconnectTime > RECONNECT_INTERVAL) {
      lastReconnectTime = millis();
      reconnectMQTT();
    }
  }
  client.loop();

  // Định kỳ chụp ảnh và gửi lên server
  if (millis() - lastCaptureTime > CAPTURE_INTERVAL) {
    captureAndSendImage();
    lastCaptureTime = millis();
  }

  delay(100);
}


// ========================
// Hàm khởi tạo camera và cấu hình cảm biến
// ========================
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

  // Cấu hình độ phân giải và chất lượng ảnh
  config.frame_size = FRAMESIZE_UXGA;   // 1600x1200 - tăng độ phân giải
  config.jpeg_quality = 12;             // Chất lượng ảnh JPEG
  config.fb_count = 1;

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x", err);
    return false;
  }

  // Điều chỉnh cảm biến để chụp tốt hơn trong điều kiện thiếu sáng
  sensor_t * s = esp_camera_sensor_get();
  s->set_brightness(s, 1);     // Tăng độ sáng
  s->set_contrast(s, 1);       // Tăng độ tương phản
  s->set_saturation(s, 0);     // Độ bão hòa trung tính
  s->set_special_effect(s, 0); // Không hiệu ứng đặc biệt
  s->set_whitebal(s, 1);       // Bật cân bằng trắng
  s->set_awb_gain(s, 1);       // Bật AWB gain
  s->set_wb_mode(s, 0);        // Chế độ cân bằng trắng tự động
  s->set_exposure_ctrl(s, 1);  // Bật kiểm soát phơi sáng
  s->set_aec2(s, 0);           // Tắt AEC DSP
  s->set_ae_level(s, 1);       // Tăng mức phơi sáng
  s->set_aec_value(s, 300);    // Giá trị phơi sáng
  s->set_gain_ctrl(s, 1);      // Bật kiểm soát gain
  s->set_agc_gain(s, 0);       // Để AEC tự xử lý gain
  s->set_gainceiling(s, (gainceiling_t)0);  // Không giới hạn gain
  s->set_bpc(s, 0);            // Tắt sửa điểm đen
  s->set_wpc(s, 1);            // Bật sửa điểm trắng
  s->set_raw_gma(s, 1);        // Bật raw gamma
  s->set_lenc(s, 1);           // Bật sửa méo ống kính
  s->set_hmirror(s, 0);        // Không lật ngang
  s->set_vflip(s, 0);          // Không lật dọc
  s->set_dcw(s, 1);            // Bật downsize EN
  s->set_colorbar(s, 0);       // Tắt color bar

  return true;
}


// ========================
// Hàm kết nối WiFi
// ========================
void setupWiFi() {
  Serial.println("Connecting to WiFi...");
  WiFi.begin(wifi_ssid, wifi_pass);
  // Biến lưu SSID/PASSWORD động
  char wifi_ssid[32] = WIFI_SSID;
  char wifi_pass[64] = WIFI_PASSWORD;

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
    // Gửi trạng thái WiFi lên MQTT
    client.publish("aquaponics/status", "ESP32-CAM: WiFi connected");
  } else {
    Serial.println("");
    Serial.println("WiFi connection failed! Check credentials.");
    client.publish("aquaponics/status", "ESP32-CAM: WiFi connection failed");
  }
}


// ========================
// Hàm kết nối lại MQTT
// ========================
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


// ========================
// Hàm xử lý lệnh nhận qua MQTT (callback)
// ========================
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");

  String message = "";
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.println(message);

  // Kiểm tra lệnh chụp ảnh
  if (message.indexOf("\"capture\":true") != -1) {
    Serial.println("Received capture command");
    captureAndSendImage();
    return;
  }

  // Kiểm tra lệnh đổi WiFi: {"wifi":{"ssid":"...","pass":"..."}}
  if (message.indexOf("wifi") != -1) {
    int ssidStart = message.indexOf("\"ssid\":");
    int passStart = message.indexOf("\"pass\":");
    if (ssidStart != -1 && passStart != -1) {
      int ssidQuote1 = message.indexOf('"', ssidStart + 7);
      int ssidQuote2 = message.indexOf('"', ssidQuote1 + 1);
      int passQuote1 = message.indexOf('"', passStart + 7);
      int passQuote2 = message.indexOf('"', passQuote1 + 1);
      if (ssidQuote1 != -1 && ssidQuote2 != -1 && passQuote1 != -1 && passQuote2 != -1) {
        String newSsid = message.substring(ssidQuote1 + 1, ssidQuote2);
        String newPass = message.substring(passQuote1 + 1, passQuote2);
        Serial.printf("Received WiFi change: SSID=%s, PASS=%s\n", newSsid.c_str(), newPass.c_str());
        preferences.begin("wifi", false);
        preferences.putString("ssid", newSsid);
        preferences.putString("pass", newPass);
        preferences.end();
        strcpy(wifi_ssid, newSsid.c_str());
        strcpy(wifi_pass, newPass.c_str());
        WiFi.disconnect();
        delay(500);
        WiFi.begin(wifi_ssid, wifi_pass);
        client.publish("aquaponics/status", "ESP32-CAM: WiFi changed, reconnecting...");
      }
    }
  }
}


// ========================
// Hàm chụp ảnh và gửi lên server AI
// ========================
void captureAndSendImage() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Cannot send image: WiFi not connected");
    client.publish("aquaponics/status", "ESP32-CAM: Cannot send image, WiFi not connected");
    return;
  }

  // Tắt flash khi chụp ảnh
  digitalWrite(FLASH_LED_PIN, LOW);

  // Chụp ảnh
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Camera capture failed");
    client.publish("aquaponics/status", "ESP32-CAM: Camera capture failed");
    // Không tắt flash khi lỗi
    return;
  }

  // Không tắt flash sau khi chụp, flash luôn bật

  Serial.printf("Captured image: %d bytes\n", fb->len);

  // Gửi ảnh lên server AI
  if (sendImageToServer(fb->buf, fb->len)) {
    Serial.println("Image sent successfully");
    client.publish("aquaponics/status", "ESP32-CAM: Image sent successfully");
  } else {
    Serial.println("Failed to send image");
    client.publish("aquaponics/status", "ESP32-CAM: Failed to send image");
  }

  // Trả lại bộ nhớ ảnh
  esp_camera_fb_return(fb);
}


// ========================
// Hàm gửi ảnh lên server AI qua HTTP POST
// ========================
bool sendImageToServer(uint8_t *imageData, size_t imageSize) {
  HTTPClient http;

  String url = String(SERVER_URL) + "/predict";
  http.begin(url);
  http.addHeader("Content-Type", "multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW");

  // Tạo dữ liệu multipart/form-data
  String boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW";
  String bodyStart = "--" + boundary + "\r\nContent-Disposition: form-data; name=\"image\"; filename=\"capture.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n";
  String bodyEnd = "\r\n--" + boundary + "--\r\n";

  size_t totalSize = bodyStart.length() + imageSize + bodyEnd.length();
  uint8_t *multipartData = (uint8_t *)malloc(totalSize);
  if (!multipartData) {
    Serial.println("Failed to allocate memory for multipart data");
    return false;
  }

  // Sao chép dữ liệu vào bộ nhớ
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
