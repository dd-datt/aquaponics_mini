# Aquaponics Mini - Hệ thống Thông minh Ứng dụng IoT và AI

![Aquaponics Mini](images_demo/UI_aquaponic.png)

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

## Ghi chú

- Đây là dự án học thuật/demo. Tham số, thời lượng bơm, ngưỡng cảnh báo cần hiệu chỉnh theo thực tế.
- ESP và camera cần nguồn ổn định, chung mass; đặt camera tránh ẩm trực tiếp.

## Tác giả

**Đề tài**: Thiết kế mô hình aquaponics mini thông minh ứng dụng IoT và AI trong trồng thủy canh và nuôi cá cảnh.

- Nguyễn Văn Đạt (Thiết kế giao diện Flutter + Xử lý logic phần cứng)
- Lê Thị Kim Duyên (Thiết kế kiến trúc hệ thống, luồng sự kiện)
- Phạm Phương Thảo (Báo cáo, thiết kế sơ đồ mạch)
