#include <WiFi.h>
#include <HTTPClient.h>

// WiFi Configuration
#define WIFI_SSID "B-LINK_5F35"
#define WIFI_PASSWORD "0123456789"

// Test server URL (you can use httpbin.org for testing)
#define TEST_URL "http://httpbin.org/post"

void setup() {
  Serial.begin(115200);
  Serial.println("\n=== ESP32-CAM WiFi & HTTP Test ===");

  // Connect to WiFi
  setupWiFi();

  Serial.println("💡 Commands:");
  Serial.println("  't' - Test HTTP GET");
  Serial.println("  'p' - Test HTTP POST");
  Serial.println("  's' - Show WiFi status");
  Serial.println("  'r' - Reconnect WiFi");
}

void loop() {
  if (Serial.available()) {
    char command = Serial.read();

    if (command == 't' || command == 'T') {
      testHTTPGet();
    } else if (command == 'p' || command == 'P') {
      testHTTPPost();
    } else if (command == 's' || command == 'S') {
      showWiFiStatus();
    } else if (command == 'r' || command == 'R') {
      reconnectWiFi();
    }
  }

  delay(100);
}

void setupWiFi() {
  Serial.println("🔗 Connecting to WiFi...");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ WiFi connected!");
    Serial.print("📡 IP Address: ");
    Serial.println(WiFi.localIP());
    Serial.print("📶 Signal strength: ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
  } else {
    Serial.println("\n❌ WiFi connection failed!");
    Serial.println("💡 Check:");
    Serial.println("  - WiFi credentials");
    Serial.println("  - WiFi signal strength");
    Serial.println("  - Router settings");
  }
}

void reconnectWiFi() {
  Serial.println("🔄 Reconnecting WiFi...");
  WiFi.disconnect();
  delay(1000);
  setupWiFi();
}

void showWiFiStatus() {
  Serial.println("\n📊 WiFi Status:");
  Serial.printf("  - Connected: %s\n", WiFi.status() == WL_CONNECTED ? "Yes" : "No");
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("  - IP: %s\n", WiFi.localIP().toString().c_str());
    Serial.printf("  - Gateway: %s\n", WiFi.gatewayIP().toString().c_str());
    Serial.printf("  - Subnet: %s\n", WiFi.subnetMask().toString().c_str());
    Serial.printf("  - DNS: %s\n", WiFi.dnsIP().toString().c_str());
    Serial.printf("  - MAC: %s\n", WiFi.macAddress().c_str());
    Serial.printf("  - Signal: %d dBm\n", WiFi.RSSI());
  }
}

void testHTTPGet() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("❌ WiFi not connected!");
    return;
  }

  Serial.println("\n🌐 Testing HTTP GET...");

  HTTPClient http;
  http.begin("http://httpbin.org/get");

  int httpCode = http.GET();

  if (httpCode > 0) {
    Serial.printf("✅ HTTP GET success! Code: %d\n", httpCode);
    String payload = http.getString();
    Serial.println("📄 Response:");
    Serial.println(payload.substring(0, 200) + "...");
  } else {
    Serial.printf("❌ HTTP GET failed! Error: %d\n", httpCode);
    Serial.println("Common errors:");
    Serial.println("  - HTTPC_ERROR_CONNECTION_REFUSED (-1)");
    Serial.println("  - HTTPC_ERROR_SEND_HEADER_FAILED (-2)");
    Serial.println("  - HTTPC_ERROR_SEND_PAYLOAD_FAILED (-3)");
    Serial.println("  - HTTPC_ERROR_NOT_CONNECTED (-4)");
  }

  http.end();
}

void testHTTPPost() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("❌ WiFi not connected!");
    return;
  }

  Serial.println("\n📤 Testing HTTP POST...");

  HTTPClient http;
  http.begin(TEST_URL);
  http.addHeader("Content-Type", "application/json");

  String jsonData = "{\"test\":\"esp32-cam\",\"timestamp\":" + String(millis()) + "}";

  int httpCode = http.POST(jsonData);

  if (httpCode > 0) {
    Serial.printf("✅ HTTP POST success! Code: %d\n", httpCode);
    String payload = http.getString();
    Serial.println("📄 Response:");
    Serial.println(payload.substring(0, 200) + "...");
  } else {
    Serial.printf("❌ HTTP POST failed! Error: %d\n", httpCode);
  }

  http.end();
}
