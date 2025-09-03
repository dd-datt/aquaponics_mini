# HƯỚNG DẪN NỐI BƠM DC 3V-5V

## 🎯 **2 CÁCH NỐI BƠM DC 3V-5V**

### **CÁCH 1: Sử dụng Transistor (Khuyến nghị)**

#### **Linh kiện cần:**

- Bơm DC 3V-5V
- Transistor NPN: 2N2222 hoặc S8050
- Điện trở: 1KΩ
- Diode: 1N4001 (bảo vệ)

#### **Sơ đồ nối:**

```
ESP8266 D5 (GPIO14) ──[1KΩ]──┬── Base (Transistor)
                              │
Buck 5V ──────────────────────┼── Collector (Transistor)
                              │
Bơm (+) ──────────────────────┼── Emitter (Transistor)
                              │
Bơm (-) ── Diode ─────────────┼── GND
                    │
                    └─────────┼── GND
```

#### **Nguyên lý:**

- Khi GPIO14 = HIGH: Transistor ON → Bơm chạy
- Khi GPIO14 = LOW: Transistor OFF → Bơm dừng
- Diode bảo vệ transistor khỏi dòng ngược

---

### **CÁCH 2: Sử dụng Relay với nguồn 5V**

#### **Linh kiện cần:**

- Bơm DC 3V-5V
- Relay module 5V (thay vì 12V)
- Dây nối

#### **Sơ đồ nối:**

```
ESP8266 D5 ── IN (Relay 5V)
Buck 5V ───── VCC (Relay)
GND ───────── GND (Relay)

Relay Output:
COM ───── Bơm (+)
NO ────── Buck 5V
Bơm (-) ─ GND
```

#### **Lưu ý:**

- Phải dùng relay 5V, không phải 12V
- Kiểm tra relay có hỗ trợ 5V không

---

## 🔧 **CODE ĐÃ ĐƯỢC CẬP NHẬT**

Code ESP8266 đã được cập nhật để:

- Sử dụng transistor thay vì relay cho bơm
- Điều khiển bơm bằng `digitalWrite(PUMP_PIN, HIGH/LOW)`
- Giữ nguyên relay cho đèn (12V)

---

## 🧪 **CÁCH TEST**

1. **Upload code mới** lên ESP8266
2. **Mở Serial Monitor** xem debug
3. **Gửi lệnh** bật bơm qua MQTT
4. **Kiểm tra:** Bơm có chạy với 3V-5V không

---

## ⚠️ **LƯU Ý QUAN TRỌNG**

1. **Điện áp bơm:** Đảm bảo bơm hoạt động ở 3V-5V
2. **Dòng điện:** Kiểm tra transistor chịu được dòng bơm
3. **Nguồn:** Buck converter phải cung cấp đủ dòng cho bơm
4. **Bảo vệ:** Thêm diode để bảo vệ transistor

Bạn muốn dùng cách nào? Tôi sẽ hướng dẫn chi tiết hơn! 🚀</content>
<parameter name="filePath">/Users/vdat319/Flutter/FlutterProjects/aquaponics_mini/PUMP_CONNECTION_GUIDE.md
