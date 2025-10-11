import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class MqttService with ChangeNotifier {
  Map<String, dynamic>? lastData;
  final String broker;
  final String clientId;
  late MqttServerClient client;
  String status = '';
  bool _connecting = false;
  bool _hasSetupListeners = false; // Đảm bảo chỉ setup listeners 1 lần
  void Function(String)? _onMessageCallback;

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
    // Kiểm tra trạng thái kết nối trước khi connect
    if (_connecting) {
      debugPrint('MQTT: Đang trong quá trình kết nối, bỏ qua yêu cầu connect mới');
      return;
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      debugPrint('MQTT: Đã kết nối, không cần reconnect');
      status = 'MQTT đã kết nối';
      safeNotifyListeners();
      return;
    }

    _connecting = true;
    status = 'Đang kết nối MQTT...';
    safeNotifyListeners();

    try {
      debugPrint('MQTT: Bắt đầu kết nối đến $broker');
      await client.connect();
    } catch (e) {
      status = 'MQTT lỗi: $e';
      debugPrint('MQTT connect error: $e');
      _connecting = false;
      safeNotifyListeners();

      // Auto-retry sau 3 giây
      await Future.delayed(Duration(seconds: 3));
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        connect(); // thử lại tự động
      }
      return;
    }
    _connecting = false;
  }

  void onConnected() {
    status = 'MQTT đã kết nối';
    debugPrint('MQTT connected!');
    client.subscribe('aquaponics/status', MqttQos.atMostOnce);

    // Setup message listener một lần duy nhất
    if (!_hasSetupListeners) {
      _setupMessageListener();
      _hasSetupListeners = true;
    }

    safeNotifyListeners();
  }

  void _setupMessageListener() {
    client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final recMess = c[0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      debugPrint('[MQTT DEBUG] Nhận dữ liệu: $pt');

      // Lưu lại dữ liệu JSON cuối cùng nếu parse được
      try {
        final start = pt.indexOf('{');
        final end = pt.lastIndexOf('}');
        if (start != -1 && end != -1 && end > start) {
          final jsonStr = pt.substring(start, end + 1);
          lastData = Map<String, dynamic>.from(
            (jsonStr.isNotEmpty) ? (jsonDecode(jsonStr) as Map<String, dynamic>) : {},
          );
        }
      } catch (_) {}

      // Gọi callback nếu có
      if (_onMessageCallback != null) {
        _onMessageCallback!(pt);
      }

      safeNotifyListeners();
    });
  }

  void onDisconnected() {
    status = 'MQTT đã ngắt kết nối';
    debugPrint('MQTT disconnected!');
    safeNotifyListeners();

    // Auto-reconnect sau 2 giây nếu chưa connected
    Future.delayed(Duration(seconds: 2), () {
      if (client.connectionStatus?.state != MqttConnectionState.connected && !_connecting) {
        debugPrint('MQTT: Auto-reconnecting...');
        connect();
      }
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
    // Lưu callback để sử dụng trong message listener
    _onMessageCallback = onMessage;

    // Nếu đã kết nối và có dữ liệu cũ, gửi ngay
    if (client.connectionStatus?.state == MqttConnectionState.connected && lastData != null) {
      final jsonString = jsonEncode(lastData!);
      debugPrint('[MQTT DEBUG] Gửi dữ liệu cũ khi reconnect: $jsonString');
      onMessage(jsonString);
    }
  }

  void safeNotifyListeners() {
    Future.delayed(Duration.zero, () => notifyListeners());
  }

  // Getter để kiểm tra trạng thái kết nối
  bool get isConnected => client.connectionStatus?.state == MqttConnectionState.connected;

  bool get isConnecting => _connecting;

  // Method để force reconnect nếu cần
  Future<void> forceReconnect() async {
    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      client.disconnect();
    }
    await Future.delayed(Duration(milliseconds: 500));
    await connect();
  }
}
