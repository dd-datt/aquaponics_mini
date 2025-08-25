# Aquaponics AI Server

## Cài đặt

1. Cài Python 3.8+ và pip
2. Cài các package:
   ```sh
   pip install -r requirements.txt
   ```
3. Đặt file model TFLite vào cùng thư mục (ví dụ: `model.tflite`)

## Chạy server Flask

```sh
python server.py
```

## Mở public bằng ngrok

```sh
ngrok http 5000
```

## API

- `POST /predict` (multipart/form-data, key: image): trả về nhãn AI
- `GET /last-image`: trả về ảnh mới nhất (base64)
- `GET /last-prediction`: trả về nhãn AI cuối
