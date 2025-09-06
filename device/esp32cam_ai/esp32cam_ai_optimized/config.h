#ifndef CONFIG_H
#define CONFIG_H

// WiFi Configuration

// Wifi ở nhà NVĐạt
#define WIFI_SSID "B-LINK_5F35"
#define WIFI_PASSWORD "0123456789"

// Wifi phát từ điện thoại
// #define WIFI_SSID "A1"
// #define WIFI_PASSWORD "0123456789"

// Server Configuration
#define SERVER_URL "http://192.168.1.124:5001"  // Địa chỉ IP LAN của laptop chạy Flask server

// MQTT Configuration
#define MQTT_BROKER "192.168.1.124"  // Địa chỉ IP của MQTT broker (cùng với Flask server)
#define MQTT_PORT 1883
#define MQTT_CLIENT_ID "esp32cam_ai"
#define MQTT_CMD_TOPIC "aquaponics/camera"

// Timing
#define CAPTURE_INTERVAL 60000  // Capture image every 60 seconds (1 phút)
#define RECONNECT_INTERVAL 5000

#endif
