# Aquaponics Mini - Hệ thống Thông minh Ứng dụng IoT và AI

![Aquaponics Mini](https://via.placeholder.com/150)

## Mục lục

- Giới thiệu
- Tính năng
- Cấu trúc dự án
- Giao thức giao tiếp
- Thành phần
- Hướng dẫn cài đặt
- Kiểm thử
- Khuyến nghị bảo mật
- Lộ trình phát triển
- Ghi chú
- Tác giả
- Giấy phép

## Giới thiệu

Aquaponics Mini là một hệ thống aquaponics thông minh kết hợp giữa trồng thủy canh và nuôi cá cảnh, tích hợp công nghệ **IoT** và **AI**. Hệ thống hỗ trợ:

- Giám sát và điều khiển từ xa qua **ứng dụng Flutter**.
- Nhận diện tình trạng lá cây (khỏe, héo, vàng) bằng **AI Computer Vision**.
- Cảnh báo thời gian thực về các sự cố (tràn khay, cạn bể) qua **MQTT**.

Hệ thống bao gồm ba thành phần độc lập giao tiếp qua internet:

1. **Thiết bị IoT**: ESP8266 điều khiển và ESP32-CAM chụp ảnh.
2. **Server AI**: Server dựa trên Flask xử lý ảnh và dự đoán AI.
3. **Ứng dụng Flutter**: Giao diện người dùng để điều khiển và hiển thị thông tin.

## Tính năng

- **Điều khiển từ xa**: Bật/tắt bơm nước, đèn qua ứng dụng Flutter.
- **Giám sát thời gian thực**: Nhiệt độ, độ ẩm, trạng thái khay/bể.
- **Nhận diện AI**: Phân tích tình trạng lá cây (khỏe, héo, vàng) từ ảnh chụp.
- **Cảnh báo sự cố**: Thông báo khi khay tràn hoặc bể cạn qua MQTT.

## Cấu trúc dự án

```
aquaponics-mini/
├─ device/
│  ├─ esp8266_ctrl/                  # ESP8266: bơm/đèn + cảm biến + cảnh báo tràn
│  │  ├─ esp8266_ctrl.ino
│  │  └─ config.h                     # WIFI_SSID, WIFI_PASS, MQTT_HOST, ...
│  └─ esp32cam_ai/                   # ESP32-CAM: chụp ảnh, gửi server AI
│     ├─ esp32cam_ai.ino
│     └─ config.h                     # SERVER_URL, WIFI_*
├─ server_ai/
│  ├─ server.py                      # Flask API: /predict /last-image /last-prediction
│  ├─ requirements.txt
│  └─ .env.example                   # FLASK_PORT, TOKEN (tùy chọn)
├─ aquaponics_mini/                  # App Flutter
│  ├─ pubspec.yaml
│  └─ lib/
│     ├─ main.dart
│     ├─ services/mqtt_service.dart
│     ├─ services/api_service.dart
│     └─ screens/dashboard.dart
└─ docs/
   ├─ topics_and_api.md             # MQTT topics + REST endpoints
   └─ wiring.md                     # Sơ đồ đấu nối & chân
```

## Giao thức giao tiếp

- **MQTT (ESP8266 ↔ Ứng dụng)**
  - `aquaponics/cmd` (ứng dụng → thiết bị): `{"cmd":"pump_on","duration":10}`, `{"cmd":"light","state":1}`
  - `aquaponics/status` (thiết bị → ứng dụng): `{"pump":0,"light":1,"tray":"LOW","tank":"OK","temp":27.4,"hum":70,"alert":"none","ts":...}`
- **REST (ESP32-CAM/Ứng dụng ↔ Flask)**
  - `POST /predict` (image/jpeg) → `{"label":"healthy|wilting|yellowing","confidence":0.93,"ts":...}`
  - `GET /last-image` → ảnh JPEG mới nhất
  - `GET /last-prediction` → JSON kết quả AI mới nhất

## Thành phần

- **ESP8266 (NodeMCU/Wemos D1 Mini)**: Quản lý MQTT, đọc cảm biến DHT22 và phao, điều khiển relay bơm/đèn, phát hiện và cảnh báo tràn/cạn.
- **ESP32-CAM**: Chụp ảnh định kỳ hoặc theo lệnh, gửi ảnh đến server Flask để phân tích.
- **Server Flask (Python)**: Nhận ảnh, chạy mô hình AI (TFLite hoặc mock), lưu và cung cấp ảnh/kết quả; mở public bằng **ngrok**.
- **Ứng dụng Flutter**: Giao diện điều khiển (bơm/đèn), hiển thị trạng thái, cảnh báo, ảnh và nhãn AI.

## Hướng dẫn cài đặt

### 1. Server AI

```bash
cd server_ai
python -m venv .venv && source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python server.py
ngrok http 5000  # lấy URL https://xxxxx.ngrok-free.app
```

- Cập nhật URL ngrok vào `device/esp32cam_ai/config.h` (SERVER_URL) và `app_flutter/lib/services/api_service.dart`.

### 2. Thiết bị

- Mở **Arduino IDE**:
  - Nạp `device/esp8266_ctrl/esp8266_ctrl.ino` (chỉnh `config.h`: Wi-Fi, MQTT broker).
  - Nạp `device/esp32cam_ai/esp32cam_ai.ino` (chỉnh `config.h`: Wi-Fi, SERVER_URL).
- Gợi ý broker demo: `broker.hivemq.com:1883`.

### 3. Ứng dụng Flutter

```bash
cd app_flutter
flutter pub get
flutter run
```

- Cập nhật `apiBaseUrl` (ngrok) và MQTT host trong `lib/services`.

## Kiểm thử

- Ứng dụng nhận trạng thái qua MQTT và điều khiển bơm/đèn thành công.
- ESP8266 gửi cảnh báo khi phao khay = HIGH (tràn) hoặc bể = LOW (cạn).
- ESP32-CAM gửi ảnh → Flask trả nhãn AI; ứng dụng hiển thị ảnh và nhãn từ `/last-image` và `/last-prediction`.

## Khuyến nghị bảo mật

- Sử dụng username/password cho MQTT nếu broker hỗ trợ.
- Flask sử dụng token đơn giản (header `Authorization: Bearer <TOKEN>`).
- Hạn chế public URL khi không demo.

## Lộ trình phát triển

- Thay mô hình AI mock bằng TFLite (MobileNetV2/EfficientNet-Lite), tinh chỉnh với dữ liệu từ PlantVillage/PlantDoc.
- Thêm lưu trữ lịch sử log (SQLite/Firestore).
- Tách broker riêng (Mosquitto trên VPS) và triển khai Flask lên cloud để chạy 24/7.

## Ghi chú

- Đây là dự án học thuật/demo. Tham số, thời lượng bơm, ngưỡng cảnh báo cần hiệu chỉnh theo thực tế.
- ESP và camera cần nguồn ổn định, chung mass; đặt camera tránh ẩm trực tiếp.

## Tác giả

**Đề tài**: Thiết kế mô hình aquaponics mini thông minh ứng dụng IoT và AI trong trồng thủy canh và nuôi cá cảnh.

Dự án này thuộc quyền sở hữu của

- Nguyễn Văn Đạt
- Lê Thị Kim Duyên
- Phạm Phương Thảo

## Giấy phép
