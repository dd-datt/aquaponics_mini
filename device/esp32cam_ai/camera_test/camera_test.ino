#include "esp_camera.h"

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

// LED Flash - optional
#define FLASH_LED_PIN     4

void setup() {
  Serial.begin(115200);
  Serial.println("\n=== ESP32-CAM Camera Test ===");

  // Initialize flash LED
  pinMode(FLASH_LED_PIN, OUTPUT);
  digitalWrite(FLASH_LED_PIN, LOW);

  // Initialize camera
  if (setupCamera()) {
    Serial.println("✅ Camera initialized successfully!");
    Serial.println("📸 Camera test ready. Send 'c' to capture, 'f' to toggle flash");
  } else {
    Serial.println("❌ Camera initialization failed!");
    while (true) {
      delay(1000);
    }
  }
}

void loop() {
  if (Serial.available()) {
    char command = Serial.read();

    if (command == 'c' || command == 'C') {
      captureAndDisplayImage();
    } else if (command == 'f' || command == 'F') {
      toggleFlash();
    } else if (command == 't' || command == 'T') {
      testCameraSettings();
    }
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
    Serial.printf("❌ Camera init failed with error 0x%x\n", err);
    Serial.println("Common errors:");
    Serial.println("- 0x101: Camera not detected");
    Serial.println("- 0x102: Camera not supported");
    Serial.println("- 0x103: Failed to initialize camera");
    Serial.println("- 0x106: Failed to set frame size");
    return false;
  }

  // Get camera sensor
  sensor_t *s = esp_camera_sensor_get();
  if (s) {
    Serial.println("📷 Camera sensor info:");
    Serial.printf("  - Model: OV%04X\n", s->id.PID);
    Serial.printf("  - Frame size: %dx%d\n", s->status.framesize, s->status.quality);
    Serial.printf("  - Pixel format: %s\n", config.pixel_format == PIXFORMAT_JPEG ? "JPEG" : "RGB565");
  }

  return true;
}

void captureAndDisplayImage() {
  Serial.println("\n📸 Capturing image...");

  // Turn on flash briefly
  digitalWrite(FLASH_LED_PIN, HIGH);
  delay(100);

  // Capture image
  camera_fb_t *fb = esp_camera_fb_get();
  digitalWrite(FLASH_LED_PIN, LOW); // Turn off flash

  if (!fb) {
    Serial.println("❌ Camera capture failed!");
    return;
  }

  Serial.printf("✅ Image captured successfully!\n");
  Serial.printf("📊 Image info:\n");
  Serial.printf("  - Size: %d bytes\n", fb->len);
  Serial.printf("  - Width: %d\n", fb->width);
  Serial.printf("  - Height: %d\n", fb->height);
  Serial.printf("  - Format: %s\n", fb->format == PIXFORMAT_JPEG ? "JPEG" : "RGB565");

  // Calculate approximate file size
  float kb = fb->len / 1024.0;
  Serial.printf("  - File size: %.1f KB\n", kb);

  // Show first few bytes for debugging
  Serial.println("📄 First 20 bytes (hex):");
  for (int i = 0; i < 20 && i < fb->len; i++) {
    if (i % 10 == 0) Serial.print("\n  ");
    Serial.printf("%02X ", fb->buf[i]);
  }
  Serial.println();

  // Check if it's a valid JPEG
  if (fb->buf[0] == 0xFF && fb->buf[1] == 0xD8) {
    Serial.println("✅ Valid JPEG header detected");
  } else {
    Serial.println("⚠️  Invalid JPEG header!");
  }

  // Return frame buffer
  esp_camera_fb_return(fb);

  Serial.println("🔄 Frame buffer returned");
  Serial.println("💡 Send 'c' to capture again, 'f' to toggle flash, 't' for settings test");
}

void toggleFlash() {
  static bool flashOn = false;
  flashOn = !flashOn;
  digitalWrite(FLASH_LED_PIN, flashOn ? HIGH : LOW);
  Serial.printf("🔦 Flash %s\n", flashOn ? "ON" : "OFF");
}

void testCameraSettings() {
  Serial.println("\n🧪 Testing camera settings...");

  sensor_t *s = esp_camera_sensor_get();
  if (!s) {
    Serial.println("❌ Cannot get sensor");
    return;
  }

  // Test different frame sizes
  Serial.println("📏 Testing frame sizes:");
  framesize_t sizes[] = {FRAMESIZE_QVGA, FRAMESIZE_VGA, FRAMESIZE_SVGA};
  const char* sizeNames[] = {"QVGA", "VGA", "SVGA"};

  for (int i = 0; i < 3; i++) {
    if (s->set_framesize(s, sizes[i]) == 0) {
      camera_fb_t *fb = esp_camera_fb_get();
      if (fb) {
        Serial.printf("  ✅ %s: %dx%d, %d bytes\n", sizeNames[i], fb->width, fb->height, fb->len);
        esp_camera_fb_return(fb);
      } else {
        Serial.printf("  ❌ %s: Failed to capture\n", sizeNames[i]);
      }
    } else {
      Serial.printf("  ❌ %s: Failed to set\n", sizeNames[i]);
    }
  }

  // Reset to VGA
  s->set_framesize(s, FRAMESIZE_VGA);
  Serial.println("🔄 Reset to VGA");
}
