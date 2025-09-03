// Pin definitions for ESP8266
#define DHT_PIN 2          // D4 (GPIO2) - DHT22 data
#define RELAY_PUMP_PIN 14  // D5 (GPIO14) - Relay IN1 for pump
#define RELAY_LIGHT_PIN 12 // D6 (GPIO12) - Relay IN2 for light
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
#define PUBLISH_INTERVAL 5000  // Publish status every 5 seconds
#define RECONNECT_INTERVAL 5000 // Reconnect MQTT every 5 seconds if disconnected
