import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/processing/fft.dart';
import '../../core/sensors/sensor_constants.dart';
import '../../core/sensors/sensor_event.dart';
import '../../core/sensors/sensor_service.dart';
import 'widgets/bpm_chart.dart';
import 'widgets/signal_chart.dart';
import 'widgets/spectrum_chart.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final List<SensorEvent> _buffer = [];
  List<double> _magnitudes = [];
  List<double> _bpmHistory = [];
  List<double> _timeLabels = [];
  final Set<int> _activeChannels = {0, 1, 2, 3, 4, 5};

  StreamSubscription<List<SensorEvent>>? _subscription;
  bool _isScanning = false;
  double _peakFreq = 0;
  double _currentBpm = 0;
  double _sessionStart = 0;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _startMonitoring() async {
    try {
      await SensorService.instance.start();
      setState(() {
        _sessionStart = DateTime.now().millisecondsSinceEpoch / 1000.0;
        _buffer.clear();
        _magnitudes = [];
        _bpmHistory = [];
        _timeLabels = [];
        _peakFreq = 0;
        _currentBpm = 0;
        _isScanning = true;
      });
      _subscription =
          SensorService.instance.processedStream.listen(_onSensorData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar: $e')),
        );
      }
    }
  }

  Future<void> _stopMonitoring() async {
    _subscription?.cancel();
    _subscription = null;
    await SensorService.instance.stop();
    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  void _onSensorData(List<SensorEvent> batch) {
    if (!mounted) return;
    setState(() {
      _buffer.addAll(batch);
      while (_buffer.length > 512) {
        _buffer.removeAt(0);
      }

      if (_buffer.length >= 256) {
        _computeFftAndBpm();
      }
    });
  }

  void _computeFftAndBpm() {
    final signal = _buffer
        .sublist(_buffer.length - 256)
        .map((e) => e.magnitude)
        .toList();

    _magnitudes = FFTAnalyzer.magnitudeSpectrum(signal);
    _currentBpm = FFTAnalyzer.estimateHeartRate(
      signal,
      SensorConstants.defaultSampleRate,
    );

    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    _timeLabels.add(now - _sessionStart);
    _bpmHistory.add(_currentBpm);

    if (_bpmHistory.length > 300) {
      _bpmHistory = _bpmHistory.sublist(_bpmHistory.length - 300);
      _timeLabels = _timeLabels.sublist(_timeLabels.length - 300);
    }

    _peakFreq = _computePeakFreq(_magnitudes);
  }

  double _computePeakFreq(List<double> spectrum) {
    if (spectrum.length < 2) return 0;
    final fftSize = spectrum.length * 2;
    final sampleRate = SensorConstants.defaultSampleRate;
    final minBin =
        (0.5 * fftSize / sampleRate).round().clamp(1, spectrum.length - 1);
    final maxBin =
        (30.0 * fftSize / sampleRate).round().clamp(1, spectrum.length - 1);

    double maxMag = 0;
    int peakIdx = minBin;
    for (int i = minBin; i <= maxBin && i < spectrum.length; i++) {
      if (spectrum[i] > maxMag) {
        maxMag = spectrum[i];
        peakIdx = i;
      }
    }
    return peakIdx * sampleRate / fftSize;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSignalCard(),
          const SizedBox(height: 12),
          _buildSpectrumCard(),
          const SizedBox(height: 12),
          _buildBpmCard(),
          const SizedBox(height: 12),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      color: const Color(0xFF16213E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSignalCard() {
    return _buildCard(
      icon: Icons.monitor_heart,
      title: 'Señal en tiempo real',
      color: Colors.cyan,
      children: [
        _buildChannelToggle(),
        const SizedBox(height: 8),
        SizedBox(
          height: 250,
          child: SignalChart(
            events: _buffer,
            activeChannels: _activeChannels,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_activeChannels.length} canales activos',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildChannelToggle() {
    return Row(
      children: List.generate(6, (i) {
        final isActive = _activeChannels.contains(i);
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (isActive) {
                  _activeChannels.remove(i);
                } else {
                  _activeChannels.add(i);
                }
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? SignalChart.channelColors[i]!
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  SignalChart.channelNames[i]!,
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive
                        ? SignalChart.channelColors[i]!
                        : Colors.grey.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSpectrumCard() {
    return _buildCard(
      icon: Icons.analytics,
      title: 'Espectro FFT',
      color: Colors.purple,
      children: [
        SizedBox(
          height: 200,
          child: SpectrumChart(
            magnitudes: _magnitudes,
            sampleRate: SensorConstants.defaultSampleRate,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pico: ${_peakFreq.toStringAsFixed(1)} Hz',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildBpmCard() {
    final avgBpm = _bpmHistory.isEmpty
        ? 0.0
        : _bpmHistory.reduce((a, b) => a + b) / _bpmHistory.length;

    return _buildCard(
      icon: Icons.timeline,
      title: 'Historial de BPM',
      color: Colors.green,
      children: [
        SizedBox(
          height: 200,
          child: BpmHistoryChart(
            bpmHistory: _bpmHistory,
            timeLabels: _timeLabels,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Promedio: ${avgBpm.toStringAsFixed(0)} BPM',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: _isScanning ? _stopMonitoring : _startMonitoring,
          icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
          label: Text(
            _isScanning ? 'DETENER' : 'INICIAR MONITOREO',
            style: const TextStyle(fontSize: 16, letterSpacing: 1),
          ),
        ),
      ),
    );
  }
}
