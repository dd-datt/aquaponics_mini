#!/usr/bin/env python3
"""
Test Flutter App MQTT Connection
Send test data to see if Flutter app receives it
"""

import paho.mqtt.client as mqtt
import json
import time

def send_test_status():
    """Send test status data to Flutter app"""
    test_data = {
        "temp": 25.5,
        "humidity": 65.0,
        "water": "Đầy",
        "pump": False,
        "light": False
    }

    client.publish('aquaponics/status', json.dumps(test_data))
    print(f'📤 Sent test status: {test_data}')

def send_test_commands():
    """Send test commands"""
    commands = [
        {"pump": True, "light": False},
        {"pump": False, "light": True},
        {"pump": True, "light": True},
        {"pump": False, "light": False}
    ]

    for cmd in commands:
        client.publish('aquaponics/cmd', json.dumps(cmd))
        print(f'📤 Sent command: {cmd}')
        time.sleep(2)

# MQTT setup
client = mqtt.Client(client_id='flutter_test')
client.connect('broker.hivemq.com', 1883, 60)
client.loop_start()

print('🧪 Flutter App MQTT Test')
print('=' * 30)
print('1. Mở Flutter app')
print('2. Kiểm tra Dashboard có nhận status không')
print('3. Test các nút điều khiển')
print()

while True:
    print('\nChọn test:')
    print('[1] Gửi test status data')
    print('[2] Gửi test commands')
    print('[3] Thoát')

    choice = input('Nhập lựa chọn (1-3): ').strip()

    if choice == '1':
        print('\n📊 Gửi test status...')
        for i in range(3):
            test_data = {
                "temp": 24.0 + i,
                "humidity": 60.0 + i * 5,
                "water": "Đầy" if i % 2 == 0 else "Thấp",
                "pump": i % 2 == 0,
                "light": i % 3 == 0
            }
            client.publish('aquaponics/status', json.dumps(test_data))
            print(f'📤 Status {i+1}: {test_data}')
            time.sleep(2)

    elif choice == '2':
        print('\n🎮 Gửi test commands...')
        send_test_commands()

    elif choice == '3':
        break

    else:
        print('❌ Lựa chọn không hợp lệ')

client.loop_stop()
print('👋 Test hoàn thành')
