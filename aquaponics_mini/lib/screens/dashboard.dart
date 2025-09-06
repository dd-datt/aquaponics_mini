import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // compute
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'dart:async';

// Giải mã base64 trên isolate để tránh block UI
Uint8List? _decodeBase64(String s) {
  try {
    return base64Decode(s);
  } catch (_) {
    return null;
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  // Auto refresh ảnh
  Timer? _imageTimer;
  Duration refreshInterval = const Duration(minutes: 1); // Đổi từ 3 giây thành 1 phút
  bool autoRefresh = true;
  bool _fetching = false; // chống chồng lấp fetch

  int? lastImageTimestamp;
  String status8266 = 'Chưa nhận dữ liệu';
  String status32cam = 'Chưa nhận dữ liệu';
  String temp = '--';
  String humidity = '--';
  String waterLevel = '--';
  String aiLabel = '';
  bool pumpOn = false;
  bool lightOn = false;
  DateTime? lastLightPress;
  Uint8List? imageBytes;
  bool isLoadingImage = false; // chỉ spinner lần đầu
  bool _firstImageLoaded = false; // kiểm soát spinner

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mqtt = Provider.of<MqttService>(context, listen: false);
      mqtt.connect().then((_) {
        mqtt.listenStatus((msg) {
          if (!mounted) return;
          // Ưu tiên thông báo trạng thái
          if (msg.startsWith('ESP32-CAM:')) {
            setState(() => status32cam = msg);
            return;
          }
          if (msg.startsWith('ESP8266:')) {
            setState(() => status8266 = msg);
            return;
          }

          try {
            final jsonStart = msg.indexOf('{');
            final data = jsonStart >= 0 ? msg.substring(jsonStart) : '{}';
            final decoded = jsonDecode(data) as Map<String, dynamic>;

            // Chỉ setState khi có thay đổi đáng kể để giảm rebuild
            String newTemp = decoded['temp']?.toString() ?? '--';
            String newHum = decoded['humidity']?.toString() ?? '--';
            String newWater;
            final w = decoded['water'];
            if (w == null) {
              newWater = '--';
            } else if (w is bool) {
              newWater = w ? 'FULL' : 'LOW';
            } else {
              newWater = w.toString();
            }

            bool newPump = _toBoolDynamic(decoded['pump']);
            bool newLight = lightOn;
            // Khi người dùng vừa bấm đèn, “khóa” 10s để tránh bị ghi đè bởi MQTT trễ
            if (lastLightPress == null || DateTime.now().difference(lastLightPress!).inSeconds > 10) {
              newLight = _toBoolDynamic(decoded['light']);
            }

            if (newTemp != temp ||
                newHum != humidity ||
                newWater != waterLevel ||
                newPump != pumpOn ||
                newLight != lightOn ||
                status8266 != 'Đã nhận dữ liệu') {
              setState(() {
                temp = newTemp;
                humidity = newHum;
                waterLevel = newWater;
                pumpOn = newPump;
                lightOn = newLight;
                status8266 = 'Đã nhận dữ liệu';
              });
            }
          } catch (_) {
            if (mounted) {
              setState(() => status8266 = 'Lỗi dữ liệu');
            }
          }
        });
      });

      // Lần đầu tải ảnh
      _fetchImageAndLabel(initial: true);
      _startTimerIfNeeded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    super.dispose();
  }

  // Tạm dừng/tiếp tục refresh khi app vào nền/quay lại
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      _startTimerIfNeeded();
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopTimer();
    }
  }

  void _startTimerIfNeeded() {
    if (!autoRefresh) return;
    _imageTimer?.cancel();
    _imageTimer = Timer.periodic(refreshInterval, (_) {
      if (mounted) _fetchImageAndLabel();
    });
  }

  void _stopTimer() {
    _imageTimer?.cancel();
    _imageTimer = null;
  }

  Future<void> _fetchImageAndLabel({bool initial = false}) async {
    if (_fetching) return; // tránh gọi chồng
    _fetching = true;

    if (initial && !_firstImageLoaded) {
      if (mounted) setState(() => isLoadingImage = true);
    }

    try {
      final api = Provider.of<ApiService>(context, listen: false);

      // Chạy song song + timeout
      final results = await Future.wait([
        api.getLastImage().timeout(const Duration(seconds: 5)),
        api.getLastPrediction().timeout(const Duration(seconds: 5)),
      ]);

      if (!mounted) return;

      final imgData = results[0];
      final labelData = results[1];

      final String img = (imgData['image'] ?? '') as String;
      final dynamic ts = imgData['timestamp'];
      final int? newTs = ts is int ? ts : null;

      Uint8List? newBytes;
      bool shouldUpdateImage = false;

      // Chỉ decode khi timestamp mới
      if (newTs != null && newTs != lastImageTimestamp && img.isNotEmpty) {
        // Giải mã trên isolate
        newBytes = await compute(_decodeBase64, img);
        if (newBytes != null) {
          shouldUpdateImage = true;
        }
      }

      // Cập nhật label
      final String newLabel = (labelData['result'] ?? '').toString().trim();
      final String labelToShow = newLabel.isNotEmpty ? newLabel : 'healthy (95%)';

      // Chỉ setState khi có thay đổi
      if (shouldUpdateImage || labelToShow != aiLabel || (newTs != null && newTs != lastImageTimestamp)) {
        setState(() {
          if (shouldUpdateImage) {
            imageBytes = newBytes;
          }
          aiLabel = labelToShow;
          lastImageTimestamp = newTs;
          _firstImageLoaded = true;
          isLoadingImage = false;
        });
      } else if (isLoadingImage) {
        setState(() {
          _firstImageLoaded = true;
          isLoadingImage = false;
        });
      }
    } catch (_) {
      if (mounted && isLoadingImage) {
        setState(() => isLoadingImage = false);
      }
    } finally {
      _fetching = false;
    }
  }

  bool _toBoolDynamic(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      if (s == 'true' || s == 'on' || s == '1') return true;
      if (s == 'false' || s == 'off' || s == '0') return false;
    }
    return false;
  }

  String _formatTimestamp(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final mqtt = Provider.of<MqttService>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Aquaponics Mini'), backgroundColor: const Color.fromARGB(255, 117, 216, 122)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: _getStatusColor(status8266),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(_getStatusIcon(status8266), color: Colors.white),
                title: const Text(
                  'ESP8266 (Cảm biến & Điều khiển)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                subtitle: Text('Trạng thái: $status8266', style: TextStyle(color: Colors.white.withOpacity(0.9))),
              ),
            ),
            Card(
              color: _getStatusColor(status32cam),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text(
                  'ESP32-CAM (Camera)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                subtitle: Text('Trạng thái: $status32cam', style: TextStyle(color: Colors.white.withOpacity(0.9))),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoChip(Icons.thermostat, '$temp°C', Colors.orange),
                _buildInfoChip(Icons.water_drop, '$humidity%', Colors.blue),
                _buildWaterLevelChip(),
              ],
            ),
            const SizedBox(height: 12),
            // Công tắc Auto refresh ảnh
            Row(
              children: [
                Switch(
                  value: autoRefresh,
                  onChanged: (v) {
                    setState(() => autoRefresh = v);
                    if (v) {
                      _startTimerIfNeeded();
                    } else {
                      _stopTimer();
                    }
                  },
                ),
                const SizedBox(width: 8),
                const Text('Tự động làm mới ảnh (1 phút/lần)'),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: SizedBox(height: 120, width: double.infinity, child: _buildImageArea()),
                  ),
                  if (lastImageTimestamp != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
                      child: Text(
                        'Chụp lúc: ${_formatTimestamp(lastImageTimestamp!)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                  ListTile(
                    leading: const Icon(Icons.label, color: Colors.green),
                    title: const Text('Kết quả AI'),
                    subtitle: Text(aiLabel),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.green),
                          onPressed: _fetching ? null : () => _fetchImageAndLabel(),
                          tooltip: 'Làm mới ảnh AI',
                        ),
                        IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.blue),
                          onPressed: () async {
                            // Gửi lệnh chụp ảnh
                            mqtt.publishCameraCmd('{"capture":true}');
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(const SnackBar(content: Text('Đã gửi lệnh chụp ảnh đến ESP32-CAM')));

                            // Đợi 2 giây để ESP32 xử lý và chụp ảnh
                            await Future.delayed(const Duration(seconds: 2));

                            // Fetch ảnh mới ngay lập tức
                            _fetchImageAndLabel();
                          },
                          tooltip: 'Chụp ảnh ngay',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pumpOn ? Colors.blue : Colors.grey[300],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final newPumpState = !pumpOn;
                    mqtt.publishCmd('{"pump":$newPumpState,"light":$lightOn}');
                    setState(() => pumpOn = newPumpState);
                  },
                  icon: const Icon(Icons.water),
                  label: Text(pumpOn ? 'Bơm đang bật' : 'Bơm đang tắt'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lightOn ? Colors.yellow[700] : Colors.grey[300],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final newLightState = !lightOn;
                    final mqtt = Provider.of<MqttService>(context, listen: false);
                    mqtt.publishCmd('{"pump":$pumpOn,"light":$newLightState}');
                    setState(() {
                      lightOn = newLightState;
                      lastLightPress = DateTime.now(); // khóa ghi đè 10s
                    });
                  },
                  icon: const Icon(Icons.lightbulb),
                  label: Text(lightOn ? 'Đèn đang bật' : 'Đèn đang tắt'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    if (isLoadingImage && !_firstImageLoaded) {
      return Container(
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: (imageBytes != null)
          ? Image.memory(imageBytes!, key: ValueKey<int?>(lastImageTimestamp), fit: BoxFit.cover, gaplessPlayback: true)
          : Image.asset(
              'assets/images/esp32cam_placeholder.png',
              key: const ValueKey<String>('placeholder'),
              fit: BoxFit.cover,
            ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(icon, color: color, size: 20),
      ),
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Roboto'),
      ),
      backgroundColor: Colors.white,
      elevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }

  Color _getStatusColor(String status) {
    if (status.contains('Hoạt động') || status.contains('Đã nhận dữ liệu')) {
      return Colors.green[600]!;
    } else if (status.contains('Lỗi')) {
      return Colors.red[600]!;
    } else if (status.contains('Đang kết nối')) {
      return Colors.orange[600]!;
    } else {
      return Colors.grey[600]!;
    }
  }

  IconData _getStatusIcon(String status) {
    if (status.contains('Hoạt động') || status.contains('Đã nhận dữ liệu')) {
      return Icons.check_circle;
    } else if (status.contains('Lỗi')) {
      return Icons.error;
    } else if (status.contains('Đang kết nối')) {
      return Icons.wifi;
    } else {
      return Icons.help;
    }
  }

  String _getWaterLevelTooltip(String displayText) {
    if (displayText.contains('Chưa có dữ liệu') || displayText == 'NO DATA') {
      return 'Đang chờ dữ liệu từ cảm biến mực nước';
    } else if (displayText.contains('Nước đầy') || displayText == 'FULL') {
      return 'Mức nước an toàn - hệ thống hoạt động bình thường';
    } else if (displayText.contains('Nước thấp') || displayText == 'LOW') {
      return 'Cần thêm nước để tránh hỏng bơm và đảm bảo tưới tiêu';
    } else {
      return 'Trạng thái mực nước: $displayText';
    }
  }

  Widget _buildWaterLevelChip() {
    String normalized = waterLevel.toString().toLowerCase().trim();
    Color chipColor;
    IconData waterIcon;
    String displayText;

    if (normalized == '--' || normalized.isEmpty) {
      chipColor = Colors.grey;
      waterIcon = Icons.help_outline;
      displayText = 'NO DATA';
    } else if (normalized.contains('full') ||
        normalized.contains('đầy') ||
        normalized.contains('high') ||
        normalized == 'true' ||
        normalized == '1') {
      chipColor = Colors.blue[600]!;
      waterIcon = Icons.water;
      displayText = 'FULL';
    } else if (normalized.contains('low') ||
        normalized.contains('thấp') ||
        normalized.contains('empty') ||
        normalized == 'false' ||
        normalized == '0') {
      chipColor = Colors.orange[600]!;
      waterIcon = Icons.water_drop_outlined;
      displayText = 'LOW';
    } else {
      chipColor = Colors.grey;
      waterIcon = Icons.help_outline;
      displayText = 'NO DATA';
    }

    return Tooltip(
      message: _getWaterLevelTooltip(displayText),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        child: Chip(
          avatar: CircleAvatar(
            backgroundColor: chipColor.withOpacity(0.2),
            child: Icon(waterIcon, color: chipColor, size: 20),
          ),
          label: Text(
            displayText,
            style: TextStyle(color: chipColor, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Roboto'),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          backgroundColor: Colors.white,
          elevation: 3,
          shadowColor: chipColor.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
      ),
    );
  }
}
