#!/usr/bin/env python3
"""
Test điều khiển bơm thực tế qua ESP8266
"""

import paho.mqtt.client as mqtt
import json
import time

def on_message(client, userdata, msg):
    if msg.topic == 'aquaponics/status':
        try:
            status = json.loads(msg.payload.decode())
            print(f'📊 ESP8266 Status: Temp={status["temp"]}°C, Pump={status["pump"]}, Light={status["light"]}')
        except:
            print(f'📨 Raw: {msg.payload.decode()}')

# MQTT setup
client = mqtt.Client(client_id='pump_test')
client.on_message = on_message
client.connect('broker.hivemq.com', 1883, 60)
client.subscribe('aquaponics/status')
client.loop_start()

print('🚰 TEST ĐIỀU KHIỂN BƠM THỰC TẾ')
print('=' * 40)
print('1. Đảm bảo ESP8266 đã được upload code')
print('2. Kiểm tra relay có kết nối đúng với bơm không')
print('3. Test từng lệnh điều khiển')
print()

while True:
    print('\n🎮 Lệnh điều khiển:')
    print('[1] Bật bơm (Pump ON)')
    print('[2] Tắt bơm (Pump OFF)')
    print('[3] Bật đèn (Light ON)')
    print('[4] Tắt đèn (Light OFF)')
    print('[5] Bật cả hai')
    print('[6] Tắt cả hai')
    print('[7] Test tự động (ON/OFF 3 lần)')
    print('[0] Thoát')

    choice = input('Chọn lệnh (0-7): ').strip()

    if choice == '0':
        break
    elif choice == '1':
        cmd = {"pump": True, "light": False}
        client.publish('aquaponics/cmd', json.dumps(cmd))
        print('📤 Gửi: Bật bơm')
    elif choice == '2':
        cmd = {"pump": False, "light": False}
        client.publish('aquaponics/cmd', json.dumps(cmd))
        print('📤 Gửi: Tắt bơm')
    elif choice == '3':
        cmd = {"pump": False, "light": True}
        client.publish('aquaponics/cmd', json.dumps(cmd))
        print('📤 Gửi: Bật đèn')
    elif choice == '4':
        cmd = {"pump": False, "light": False}
        client.publish('aquaponics/cmd', json.dumps(cmd))
        print('📤 Gửi: Tắt đèn')
    elif choice == '5':
        cmd = {"pump": True, "light": True}
        client.publish('aquaponics/cmd', json.dumps(cmd))
        print('📤 Gửi: Bật cả hai')
    elif choice == '6':
        cmd = {"pump": False, "light": False}
        client.publish('aquaponics/cmd', json.dumps(cmd))
        print('📤 Gửi: Tắt cả hai')
    elif choice == '7':
        print('🔄 Test tự động...')
        for i in range(3):
            print(f'   Lần {i+1}: Bật bơm')
            client.publish('aquaponics/cmd', json.dumps({"pump": True, "light": False}))
            time.sleep(2)
            print(f'   Lần {i+1}: Tắt bơm')
            client.publish('aquaponics/cmd', json.dumps({"pump": False, "light": False}))
            time.sleep(2)
        print('✅ Test hoàn thành')
    else:
        print('❌ Lựa chọn không hợp lệ')

    time.sleep(1)  # Đợi response

client.loop_stop()
print('👋 Kết thúc test')
