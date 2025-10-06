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
#define MQTT_CLIENT_ID "esp32cam_ai_2" // Đảm bảo mỗi thiết bị dùng một client ID khác nhau, ví dụ: "esp32cam_ai_1", "esp32cam_ai_2", ...
#define MQTT_CMD_TOPIC "aquaponics/camera_cmd"

// Timing
#define CAPTURE_INTERVAL 60000  // Capture image every 60 seconds (1 phút)
#define RECONNECT_INTERVAL 5000

#endif
