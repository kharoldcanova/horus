import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/sensors/sensor_event.dart';
import '../../core/sensors/sensor_service.dart';
import '../../core/ml/model_service.dart';

class RescueScreen extends StatefulWidget {
  const RescueScreen({super.key});

  @override
  State<RescueScreen> createState() => _RescueScreenState();
}

class _RescueScreenState extends State<RescueScreen>
    with WidgetsBindingObserver {
  final SensorService _sensorService = SensorService();
  final ModelService _modelService = ModelService();
  StreamSubscription? _subscription;
  DetectionMode _currentMode = DetectionMode.imu;
  bool _isScanning = false;
  bool _modelReady = false;

  List<SensorEvent> _window = [];
  double _currentBpm = 0;
  double _confidence = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initModel();
  }

  Future<void> _initModel() async {
    await _modelService.loadModel();
    if (mounted) {
      setState(() => _modelReady = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _sensorService.dispose();
    _modelService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isScanning) {
      _stopScanning();
    }
  }

  Future<void> _toggleScanning() async {
    if (_isScanning) {
      _stopScanning();
    } else {
      await _startScanning();
    }
  }

  Future<void> _startScanning() async {
    try {
      await _sensorService.start();
      setState(() => _isScanning = true);

      _subscription = _sensorService.processedStream.listen((events) {
        _window.addAll(events);
        if (_window.length > 256) {
          _window = _window.sublist(_window.length - 256);
        }

        if (_window.length >= 128) {
          final result = _modelService.classify(
            window: _window,
            mode: _currentMode,
          );
          setState(() {
            _currentBpm = result.bpm;
            _confidence = result.confidence;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _stopScanning() {
    _subscription?.cancel();
    _subscription = null;
    _sensorService.stop();
    setState(() => _isScanning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HORUS'),
        centerTitle: true,
        actions: [
          _buildModeSelector(),
        ],
      ),
      body: Column(
        children: [
          _buildStatusPanel(),
          const Spacer(),
          _buildHeartDisplay(),
          const Spacer(),
          _buildActionButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return PopupMenuButton<DetectionMode>(
      icon: const Icon(Icons.swap_horiz),
      onSelected: (mode) {
        setState(() => _currentMode = mode);
        if (_isScanning) {
          _stopScanning();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: DetectionMode.imu,
          child: Text('IMU (GCG/SCG)'),
        ),
        const PopupMenuItem(
          value: DetectionMode.audio,
          child: Text('Audio (Contacto)'),
        ),
        const PopupMenuItem(
          value: DetectionMode.camera,
          child: Text('Cámara (rPPG)'),
        ),
      ],
    );
  }

  Widget _buildStatusPanel() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusItem(
                  'Modo',
                  _currentMode == DetectionMode.imu
                      ? 'GCG/SCG'
                      : _currentMode == DetectionMode.audio
                          ? 'Audio'
                          : 'Cámara',
                ),
                _buildStatusItem(
                  'Estado',
                  _isScanning ? 'ESCANEANDO' : 'DETENIDO',
                  color: _isScanning ? Colors.green : Colors.grey,
                ),
                _buildStatusItem(
                  'Modelo',
                  _modelReady ? 'LISTO' : 'CARGANDO',
                  color: _modelReady ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _confidence,
              backgroundColor: Colors.grey[800],
              color: _heartbeatColor,
              minHeight: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildHeartDisplay() {
    final detected = _currentBpm > 0 && _confidence > 0.3;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedScale(
          scale: detected ? 1.0 : 0.8,
          duration: const Duration(milliseconds: 500),
          child: Icon(
            detected ? Icons.favorite : Icons.favorite_border,
            size: 120,
            color: _heartbeatColor,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _currentBpm > 0
              ? '${_currentBpm.round()} BPM'
              : '---',
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          detected ? 'LATIDO DETECTADO' : 'SIN DETECCIÓN',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: detected ? Colors.green : Colors.white38,
            letterSpacing: 2,
          ),
        ),
        if (_confidence > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Confianza: ${(_confidence * 100).round()}%',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white54,
              ),
            ),
          ),
      ],
    );
  }

  Color get _heartbeatColor {
    if (_currentBpm == 0) return Colors.grey;
    if (_confidence > 0.7) return Colors.green;
    if (_confidence > 0.3) return Colors.orange;
    return Colors.red;
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: 200,
      height: 200,
      child: ElevatedButton(
        onPressed: _modelReady ? _toggleScanning : null,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: _isScanning ? Colors.red : Colors.green,
          foregroundColor: Colors.white,
          elevation: 8,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isScanning ? Icons.stop : Icons.play_arrow,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              _isScanning ? 'DETENER' : 'INICIAR',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
