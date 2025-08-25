import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter/foundation.dart';

class MqttService with ChangeNotifier {
  final String broker;
  final String clientId;
  late MqttServerClient client;
  String status = '';

  MqttService({required this.broker, required this.clientId}) {
    client = MqttServerClient(broker, clientId);
    client.logging(on: false);
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onSubscribed = onSubscribed;
  }

  Future<void> connect() async {
    try {
      await client.connect();
    } catch (e) {
      status = 'Error: $e';
      notifyListeners();
    }
  }

  void onConnected() {
    status = 'Connected';
    client.subscribe('aquaponics/status', MqttQos.atMostOnce);
    notifyListeners();
  }

  void onDisconnected() {
    status = 'Disconnected';
    notifyListeners();
  }

  void onSubscribed(String topic) {
    status = 'Subscribed $topic';
    notifyListeners();
  }

  void publishCmd(String payload) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    client.publishMessage('aquaponics/cmd', MqttQos.atMostOnce, builder.payload!);
  }

  void listenStatus(void Function(String) onMessage) {
    client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final recMess = c[0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      onMessage(pt);
    });
  }
}
