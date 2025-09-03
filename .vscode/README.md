# VS Code Debug Configuration

## Cách chạy app trong VS Code

### 1. Đảm bảo Flutter SDK được cấu hình đúng

- Mở VS Code
- Đi đến File > Preferences > Settings
- Tìm "flutter.sdkPath" và đảm bảo nó trỏ đến: `/Users/vdat319/Flutter/SDK/flutter`

### 2. Chạy app

- Mở file `lib/main.dart`
- Nhấn F5 hoặc đi đến Run > Start Debugging
- Chọn configuration phù hợp:
  - `aquaponics_mini (iOS Simulator)` - Chạy trên iOS Simulator
  - `aquaponics_mini (macOS)` - Chạy trên macOS
  - `aquaponics_mini (iOS Device)` - Chạy trên thiết bị iOS thật
  - `aquaponics_mini (auto-select)` - Tự động chọn device

### 3. Nếu vẫn bị trắng màn hình

- Kiểm tra Console (View > Debug Console) để xem lỗi
- Đảm bảo device được chọn đúng
- Thử chạy `flutter clean` và `flutter pub get` trong terminal

### 4. Troubleshooting

- Nếu không thấy device: Chạy `flutter devices` trong terminal
- Nếu có lỗi về Android: Cài đặt Android Studio và Android SDK
- Nếu có lỗi về Chrome: Cài đặt Google Chrome hoặc cấu hình CHROME_EXECUTABLE
