#ifndef CONFIG_H
#define CONFIG_H

// WiFi Configuration

// Wifi ở nhà NVĐạt
#define WIFI_SSID "B-LINK_5F35"
#define WIFI_PASSWORD "0123456789"

// // Wifi phát từ điện thoại
// #define WIFI_SSID "B-LINK_5F35"
// #define WIFI_PASSWORD "0123456789"

// Server Configuration
#define SERVER_URL "https://aquaponics-mini.onrender.com"

// MQTT Configuration (optional, for receiving commands)
#define MQTT_BROKER "broker.hivemq.com"
#define MQTT_PORT 1883
#define MQTT_CLIENT_ID "esp32cam_ai"
#define MQTT_CMD_TOPIC "aquaponics/camera_cmd"

// Timing
#define CAPTURE_INTERVAL 30000  // Capture image every 30 seconds
#define RECONNECT_INTERVAL 5000

#endif
