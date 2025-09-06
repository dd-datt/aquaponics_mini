# ESP32-CAM Fix: Tách file để tránh lỗi redefinition

## Vấn đề đã fix

- **Lỗi compile**: `redefinition of 'const char* ssid'` và các lỗi tương tự
- **Nguyên nhân**: Arduino IDE gộp tất cả file .ino trong cùng thư mục thành 1 file
- **Giải pháp**: Tách từng phiên bản vào thư mục riêng

## Cấu trúc thư mục mới

```
device/esp32cam_ai/
├── esp32cam_ai_optimized/          # KHUYẾN NGHỊ SỬ DỤNG
│   ├── esp32cam_ai_optimized.ino   # Code chính
│   └── config.h                    # File cấu hình
├── esp32cam_ai_mqtt_version/       # Phiên bản hardcode
│   └── esp32cam_ai_mqtt_version.ino
├── esp32cam_ai_mjpeg_flask.ino     # Phiên bản cũ (chỉ HTTP)
└── README_FIX.md                   # File này
```

## Cách sử dụng

### 1. Mở Arduino IDE

- File → Open → Chọn 1 trong 2 thư mục:
  - `esp32cam_ai_optimized/esp32cam_ai_optimized.ino` (khuyến nghị)
  - `esp32cam_ai_mqtt_version/esp32cam_ai_mqtt_version.ino`

### 2. Cấu hình

- **esp32cam_ai_optimized**: Sửa trong file `config.h`
- **esp32cam_ai_mqtt_version**: Sửa trực tiếp trong code

### 3. Thư viện cần thiết

- PubSubClient (MQTT)
- ArduinoJson (JSON parsing)
- ESP32 Camera libraries

### 4. Upload lên ESP32-CAM

- Chọn board: "AI Thinker ESP32-CAM"
- Chọn port tương ứng
- Upload code

## Tính năng

- ✅ Chụp ảnh tự động mỗi 1 phút
- ✅ Nhận lệnh MQTT để chụp ngay (`{"capture":true}`)
- ✅ Gửi trạng thái qua MQTT
- ✅ Gửi ảnh lên Flask AI server

## MQTT Topics

- `aquaponics/camera`: Nhận lệnh chụp ảnh
- `aquaponics/status`: Gửi trạng thái ESP32-CAM

## Test

Sau khi upload, mở Serial Monitor (115200 baud) để xem log.
