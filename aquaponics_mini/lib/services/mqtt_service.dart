import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter/foundation.dart';

class MqttService with ChangeNotifier {
  final String broker;
  final String clientId;
  late MqttServerClient client;
  String status = '';
  bool _connecting = false;

  MqttService({required this.broker, required this.clientId}) {
    client = MqttServerClient(broker, clientId);
    client.logging(on: true);
    client.keepAlivePeriod = 20;
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onSubscribed = onSubscribed;
    client.onUnsubscribed = (topic) => debugPrint('Unsubscribed: $topic');
    client.onSubscribeFail = (topic) => debugPrint('Subscribe failed: $topic');
    client.pongCallback = () => debugPrint('Ping response received');
  }

  Future<void> connect() async {
    if (_connecting || client.connectionStatus?.state == MqttConnectionState.connected) return;
    _connecting = true;
    status = 'Đang kết nối MQTT...';
    safeNotifyListeners();
    try {
      await client.connect();
    } catch (e) {
      status = 'MQTT lỗi: $e';
      debugPrint('MQTT connect error: $e');
      safeNotifyListeners();
      await Future.delayed(Duration(seconds: 3));
      _connecting = false;
      connect(); // thử lại tự động
      return;
    }
    _connecting = false;
  }

  void onConnected() {
    status = 'MQTT đã kết nối';
    debugPrint('MQTT connected!');
    client.subscribe('aquaponics/status', MqttQos.atMostOnce);
    // Đảm bảo luôn lắng nghe message khi kết nối lại
    if (client.updates != null && !_connecting) {
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final recMess = c[0].payload as MqttPublishMessage;
        final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        debugPrint('[MQTT DEBUG] Nhận dữ liệu: $pt');
      });
    }
    safeNotifyListeners();
  }

  void onDisconnected() {
    status = 'MQTT đã ngắt kết nối';
    debugPrint('MQTT disconnected!');
    safeNotifyListeners();
    Future.delayed(Duration(seconds: 2), () {
      connect();
    });
  }

  void onSubscribed(String topic) {
    status = 'Đã subscribe $topic';
    debugPrint('Subscribed $topic');
    safeNotifyListeners();
  }

  void publishCmd(String payload) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    client.publishMessage('aquaponics/cmd', MqttQos.atMostOnce, builder.payload!);
  }

  void publishCameraCmd(String payload) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    client.publishMessage('aquaponics/camera_cmd', MqttQos.atMostOnce, builder.payload!);
  }

  void listenStatus(void Function(String) onMessage) {
    client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final recMess = c[0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      debugPrint('[MQTT DEBUG] Nhận dữ liệu: $pt');
      onMessage(pt);
    });
  }

  void safeNotifyListeners() {
    Future.delayed(Duration.zero, () => notifyListeners());
  }
}
