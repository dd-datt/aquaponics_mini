# ESP32-CAM Optimization Guide

## Vấn đề đã fix:

- App và ESP32 bị lệch nhau về timing chụp ảnh
- Lag khi fetch ảnh liên tục

## Giải pháp:

1. **ESP32-CAM**: Chụp ảnh tự động 1 phút 1 lần + nhận lệnh MQTT để chụp ngay
2. **Flutter App**: Refresh ảnh 1 phút 1 lần + cho phép chụp ảnh ngay khi user yêu cầu

## Files đã cập nhật:

### Flutter App:

- `aquaponics_mini/lib/screens/dashboard.dart`:
  - Đổi refresh interval từ 3 giây thành 1 phút
  - Thêm logic chụp ảnh ngay khi user bấm nút (đợi 2s rồi fetch)
  - Cải thiện UI với switch bật/tắt auto refresh

### ESP32-CAM:

- `esp32cam_ai_optimized.ino`: File mới sử dụng config.h và MQTT
- `esp32cam_ai_mqtt.ino`: File mới với MQTT hardcoded
- `esp32cam_ai_mjpeg_flask.ino`: Cập nhật từ 30s thành 60s
- `config.h`: Cập nhật CAPTURE_INTERVAL thành 60s

## Cách sử dụng:

### 1. Upload ESP32-CAM:

- Sử dụng `esp32cam_ai_optimized.ino` (khuyến nghị)
- Hoặc `esp32cam_ai_mqtt.ino` nếu muốn hardcode config

### 2. Cài đặt Flutter:

- Code đã được cập nhật trong `dashboard.dart`
- Switch "Tự động làm mới ảnh (1 phút/lần)" để bật/tắt auto refresh
- Nút camera để chụp ảnh ngay lập tức

### 3. Kiểm tra:

- ESP32 sẽ tự động chụp và gửi ảnh mỗi 1 phút
- Khi user bấm nút camera, ESP32 sẽ chụp ngay và app sẽ fetch ảnh mới sau 2 giây
- Giảm thiểu lag và tối ưu bandwidth

## Thư viện cần thiết cho ESP32:

- PubSubClient (cho MQTT)
- ArduinoJson (cho parse JSON)
- ESP32 Camera libraries

## MQTT Topics:

- `aquaponics/camera`: Nhận lệnh chụp ảnh `{"capture":true}`
- `aquaponics/status`: Gửi trạng thái ESP32-CAM
