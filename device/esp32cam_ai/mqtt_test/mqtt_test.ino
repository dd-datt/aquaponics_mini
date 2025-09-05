#include <WiFi.h>
#include <PubSubClient.h>

// WiFi Configuration
#define WIFI_SSID "B-LINK_5F35"
#define WIFI_PASSWORD "0123456789"

// MQTT Configuration
#define MQTT_BROKER "broker.hivemq.com"
#define MQTT_PORT 1883
#define MQTT_CLIENT_ID "esp32cam_test"

// Test topics
#define TEST_PUB_TOPIC "aquaponics/test/pub"
#define TEST_SUB_TOPIC "aquaponics/test/sub"

WiFiClient espClient;
PubSubClient client(espClient);

void setup() {
  Serial.begin(115200);
  Serial.println("\n=== ESP32-CAM MQTT Test ===");

  // Connect to WiFi
  setupWiFi();

  // Setup MQTT
  client.setServer(MQTT_BROKER, MQTT_PORT);
  client.setCallback(mqttCallback);

  Serial.println("💡 Commands:");
  Serial.println("  'c' - Connect to MQTT");
  Serial.println("  'p' - Publish test message");
  Serial.println("  's' - Subscribe to test topic");
  Serial.println("  'u' - Unsubscribe from test topic");
  Serial.println("  'd' - Disconnect MQTT");
  Serial.println("  'r' - Reconnect WiFi");
}

void loop() {
  // Maintain MQTT connection
  client.loop();

  if (Serial.available()) {
    char command = Serial.read();

    if (command == 'c' || command == 'C') {
      connectMQTT();
    } else if (command == 'p' || command == 'P') {
      publishTestMessage();
    } else if (command == 's' || command == 'S') {
      subscribeTestTopic();
    } else if (command == 'u' || command == 'U') {
      unsubscribeTestTopic();
    } else if (command == 'd' || command == 'D') {
      disconnectMQTT();
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
  } else {
    Serial.println("\n❌ WiFi connection failed!");
  }
}

void reconnectWiFi() {
  Serial.println("🔄 Reconnecting WiFi...");
  WiFi.disconnect();
  delay(1000);
  setupWiFi();
}

void connectMQTT() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("❌ WiFi not connected!");
    return;
  }

  Serial.println("🔗 Connecting to MQTT...");

  // Try to connect
  if (client.connect(MQTT_CLIENT_ID)) {
    Serial.println("✅ MQTT connected!");
    Serial.printf("📡 Broker: %s:%d\n", MQTT_BROKER, MQTT_PORT);
    Serial.printf("🆔 Client ID: %s\n", MQTT_CLIENT_ID);
  } else {
    Serial.printf("❌ MQTT connection failed! State: %d\n", client.state());
    Serial.println("Common MQTT connection errors:");
    Serial.println("  -1: Connection refused - incorrect protocol version");
    Serial.println("  -2: Connection refused - identifier rejected");
    Serial.println("  -3: Connection refused - server unavailable");
    Serial.println("  -4: Connection refused - bad username or password");
    Serial.println("  -5: Connection refused - not authorized");
  }
}

void publishTestMessage() {
  if (!client.connected()) {
    Serial.println("❌ MQTT not connected!");
    return;
  }

  String message = "ESP32-CAM Test Message - " + String(millis());
  bool success = client.publish(TEST_PUB_TOPIC, message.c_str());

  if (success) {
    Serial.printf("✅ Published to %s: %s\n", TEST_PUB_TOPIC, message.c_str());
  } else {
    Serial.printf("❌ Failed to publish to %s\n", TEST_PUB_TOPIC);
  }
}

void subscribeTestTopic() {
  if (!client.connected()) {
    Serial.println("❌ MQTT not connected!");
    return;
  }

  bool success = client.subscribe(TEST_SUB_TOPIC);

  if (success) {
    Serial.printf("✅ Subscribed to %s\n", TEST_SUB_TOPIC);
    Serial.println("💡 Try publishing to this topic from another MQTT client to test");
  } else {
    Serial.printf("❌ Failed to subscribe to %s\n", TEST_SUB_TOPIC);
  }
}

void unsubscribeTestTopic() {
  if (!client.connected()) {
    Serial.println("❌ MQTT not connected!");
    return;
  }

  bool success = client.unsubscribe(TEST_SUB_TOPIC);

  if (success) {
    Serial.printf("✅ Unsubscribed from %s\n", TEST_SUB_TOPIC);
  } else {
    Serial.printf("❌ Failed to unsubscribe from %s\n", TEST_SUB_TOPIC);
  }
}

void disconnectMQTT() {
  if (client.connected()) {
    client.disconnect();
    Serial.println("🔌 MQTT disconnected");
  } else {
    Serial.println("📡 MQTT was not connected");
  }
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  Serial.printf("\n📨 MQTT Message received:\n");
  Serial.printf("  📌 Topic: %s\n", topic);
  Serial.printf("  📄 Payload (%d bytes): ", length);

  for (int i = 0; i < length; i++) {
    Serial.print((char)payload[i]);
  }
  Serial.println();

  // Echo back the message
  String response = "ESP32-CAM received: " + String((char*)payload, length);
  client.publish(TEST_PUB_TOPIC, response.c_str());
  Serial.printf("🔄 Echoed back: %s\n", response.c_str());
}
