#!/bin/bash

# Start ngrok in background
ngrok http 5001 &
NGROK_PID=$!

# Wait for ngrok to start
sleep 5

# Get the ngrok URL
URL=$(curl -s http://localhost:4040/api/tunnels | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['tunnels'][0]['public_url'])")

# Update main.dart
sed -i '' "s|baseUrl: 'https://[^']*'|baseUrl: '$URL'|g" aquaponics_mini/lib/main.dart

echo "Updated baseUrl to $URL"

# Keep ngrok running
wait $NGROK_PID
