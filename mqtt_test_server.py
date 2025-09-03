#!/usr/bin/env python3
"""
MQTT Test Server for Aquaponics Mini
Test communication with ESP8266 without ESP32-CAM
"""

import paho.mqtt.client as mqtt
import json
import time
from datetime import datetime

def on_connect(client, userdata, flags, rc):
    print('✅ Connected to MQTT broker')
    client.subscribe('aquaponics/cmd')
    client.subscribe('aquaponics/status')
    print('📡 Subscribed to topics: aquaponics/cmd, aquaponics/status')

def on_message(client, userdata, msg):
    timestamp = datetime.now().strftime('%H:%M:%S')
    print(f'\n[{timestamp}] 📨 Message on {msg.topic}:')

    try:
        payload = msg.payload.decode('utf-8')
        print(f'   Raw: {payload}')

        if msg.topic == 'aquaponics/cmd':
            # Parse command from app
            cmd = json.loads(payload)
            print('   📝 Command received:')
            print(f'      Pump: {cmd.get("pump", "unchanged")}')
            print(f'      Light: {cmd.get("light", "unchanged")}')

        elif msg.topic == 'aquaponics/status':
            # Parse status from ESP8266
            status = json.loads(payload)
            print('   📊 Status from ESP8266:')
            print(f'      Temperature: {status.get("temp", "N/A")}°C')
            print(f'      Humidity: {status.get("humidity", "N/A")}%')
            print(f'      Water Level: {status.get("water", "N/A")}')
            print(f'      Pump: {status.get("pump", "N/A")}')
            print(f'      Light: {status.get("light", "N/A")}')

    except json.JSONDecodeError:
        print(f'   ❌ Invalid JSON: {msg.payload.decode()}')
    except Exception as e:
        print(f'   ❌ Error: {e}')

def send_test_command():
    """Send a test command to ESP8266"""
    commands = [
        '{"pump": true, "light": false}',
        '{"pump": false, "light": true}',
        '{"pump": true, "light": true}',
        '{"pump": false, "light": false}'
    ]

    for i, cmd in enumerate(commands):
        print(f'\n🔄 Sending test command {i+1}/4: {cmd}')
        client.publish('aquaponics/cmd', cmd)
        time.sleep(2)

# Create MQTT client
client = mqtt.Client(client_id='test_server')
client.on_connect = on_connect
client.on_message = on_message

print('🚀 Starting MQTT Test Server...')
print('=' * 50)

try:
    # Connect to broker
    client.connect('broker.hivemq.com', 1883, 60)
    client.loop_start()

    print('✅ MQTT Test Server running!')
    print('📋 Instructions:')
    print('   1. Upload ESP8266 code to your board')
    print('   2. Wait for ESP8266 to connect and send status')
    print('   3. Use Flutter app to send commands')
    print('   4. Or press Enter to send test commands')
    print('')
    print('⏹️  Press Ctrl+C to stop')

    # Wait for user input or run test commands
    while True:
        user_input = input('\nPress Enter to send test commands (or Ctrl+C to exit): ')
        if user_input == '':
            send_test_command()

except KeyboardInterrupt:
    print('\n⏹️  Stopping MQTT Test Server...')
    client.loop_stop()
    print('👋 Goodbye!')

except Exception as e:
    print(f'❌ Error: {e}')
    client.loop_stop()
