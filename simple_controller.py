#!/usr/bin/env python3
"""
Simple MQTT Control Interface for Aquaponics Mini
Control ESP8266 without Flutter app or ESP32-CAM
"""

import paho.mqtt.client as mqtt
import json
import time
import os
from datetime import datetime

class AquaponicsController:
    def __init__(self):
        self.pump_state = False
        self.light_state = False
        self.last_status = {}

        # MQTT setup
        self.client = mqtt.Client(client_id='controller')
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message

    def on_connect(self, client, userdata, flags, rc):
        print('✅ Connected to MQTT broker')
        self.client.subscribe('aquaponics/status')

    def on_message(self, client, userdata, msg):
        if msg.topic == 'aquaponics/status':
            try:
                status = json.loads(msg.payload.decode())
                self.last_status = status
                self.display_status(status)
            except:
                pass

    def display_status(self, status):
        os.system('clear' if os.name == 'posix' else 'cls')
        print('🌱 AQUAPONICS MINI CONTROLLER')
        print('=' * 40)
        print(f'📊 Temperature: {status.get("temp", "N/A")}°C')
        print(f'💧 Humidity: {status.get("humidity", "N/A")}%')
        print(f'🌊 Water Level: {status.get("water", "N/A")}')
        print(f'🚰 Pump: {"ON" if status.get("pump") else "OFF"}')
        print(f'💡 Light: {"ON" if status.get("light") else "OFF"}')
        print()
        print('🎮 Control Commands:')
        print('  [1] Toggle Pump')
        print('  [2] Toggle Light')
        print('  [3] Turn ON both')
        print('  [4] Turn OFF both')
        print('  [5] Refresh Status')
        print('  [0] Exit')
        print()

    def send_command(self, pump=None, light=None):
        if pump is not None:
            self.pump_state = pump
        if light is not None:
            self.light_state = light

        command = {
            "pump": self.pump_state,
            "light": self.light_state
        }

        self.client.publish('aquaponics/cmd', json.dumps(command))
        print(f'📤 Sent command: {command}')

    def run(self):
        try:
            self.client.connect('broker.hivemq.com', 1883, 60)
            self.client.loop_start()

            print('🚀 Aquaponics Controller Started!')
            print('Waiting for ESP8266 status...')

            while True:
                if not self.last_status:
                    print('.', end='', flush=True)
                    time.sleep(1)
                    continue

                try:
                    choice = input('Enter command (0-5): ').strip()

                    if choice == '0':
                        break
                    elif choice == '1':
                        self.send_command(pump=not self.pump_state)
                    elif choice == '2':
                        self.send_command(light=not self.light_state)
                    elif choice == '3':
                        self.send_command(pump=True, light=True)
                    elif choice == '4':
                        self.send_command(pump=False, light=False)
                    elif choice == '5':
                        if self.last_status:
                            self.display_status(self.last_status)
                        else:
                            print('No status received yet')
                    else:
                        print('Invalid choice. Please enter 0-5.')

                    time.sleep(0.5)  # Small delay

                except KeyboardInterrupt:
                    break
                except Exception as e:
                    print(f'Error: {e}')

        except Exception as e:
            print(f'Connection error: {e}')
        finally:
            self.client.loop_stop()
            print('👋 Controller stopped')

def main():
    print('🌱 Aquaponics Mini - Simple Controller')
    print('This tool lets you control ESP8266 without Flutter app')
    print('=' * 50)

    controller = AquaponicsController()
    controller.run()

if __name__ == '__main__':
    main()
