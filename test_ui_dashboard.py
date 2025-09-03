#!/usr/bin/env python3
"""
Test UI Dashboard - Gửi dữ liệu mẫu để kiểm tra hiển thị
"""

import paho.mqtt.client as mqtt
import json
import time

def send_test_data():
    """Gửi dữ liệu test để kiểm tra UI"""
    test_cases = [
        {
            "name": "Dữ liệu đầy đủ",
            "data": {
                "temp": 26.5,
                "humidity": 65.0,
                "water": "Đầy",
                "pump": True,
                "light": False
            }
        },
        {
            "name": "Nước thấp",
            "data": {
                "temp": 25.0,
                "humidity": 70.0,
                "water": "Thấp",
                "pump": False,
                "light": True
            }
        },
        {
            "name": "Boolean water level",
            "data": {
                "temp": 27.0,
                "humidity": 60.0,
                "water": True,  # Boolean thay vì string
                "pump": True,
                "light": True
            }
        },
        {
            "name": "Dữ liệu thiếu",
            "data": {
                "temp": 24.0,
                "humidity": 55.0,
                "pump": False,
                "light": False
                # Không có water
            }
        }
    ]

    for test_case in test_cases:
        print(f'\n🧪 Test: {test_case["name"]}')
        client.publish('aquaponics/status', json.dumps(test_case["data"]))
        print(f'📤 Sent: {test_case["data"]}')

        # Đợi 3 giây để UI cập nhật
        print('⏳ Đợi 3 giây để UI cập nhật...')
        time.sleep(3)

    print('\n✅ Hoàn thành test UI!')
    print('Kiểm tra Flutter app xem có hiển thị đúng không:')

# MQTT setup
client = mqtt.Client(client_id='ui_test')
client.connect('broker.hivemq.com', 1883, 60)
client.loop_start()

print('🎨 UI TEST - Kiểm tra hiển thị Dashboard')
print('=' * 50)
print('Hướng dẫn:')
print('1. Mở Flutter app')
print('2. Vào Dashboard')
print('3. Chờ script gửi dữ liệu test')
print('4. Kiểm tra hiển thị:')
print('   - Temperature, Humidity')
print('   - Water Level (màu sắc, icon)')
print('   - Pump/Light status')
print('')

input('Nhấn Enter để bắt đầu test...')

send_test_data()

client.loop_stop()
print('👋 Test hoàn thành!')
