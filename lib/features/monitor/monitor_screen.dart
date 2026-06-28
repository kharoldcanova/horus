import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/audio/audio_service.dart';
import '../../core/processing/fft.dart';
import '../../core/sensors/sensor_constants.dart';
import '../../core/sensors/sensor_event.dart';
import '../../core/sensors/sensor_service.dart';
import 'widgets/audio_waveform_chart.dart';
import 'widgets/bpm_chart.dart';
import 'widgets/signal_chart.dart';
import 'widgets/spectrum_chart.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  // IMU state
  final List<SensorEvent> _buffer = [];
  final Set<int> _activeChannels = {0, 1, 2, 3, 4, 5};

  // Audio state
  List<double> _audioWaveform = [];

  // Shared state
  List<double> _magnitudes = [];
  List<double> _bpmHistory = [];
  List<double> _timeLabels = [];

  StreamSubscription<List<SensorEvent>>? _subscription;
  StreamSubscription<AudioFrame>? _audioSubscription;
  bool _isScanning = false;
  bool _isAudioMode = false;
  double _peakFreq = 0;
  double _currentBpm = 0;
  double _sessionStart = 0;

  @override
  void dispose() {
    _subscription?.cancel();
    _audioSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startMonitoring() async {
    if (AudioService.instance.isRunning) {
      _startAudioMonitoring();
    } else {
      _startImuMonitoring();
    }
  }

  void _startAudioMonitoring() {
    setState(() {
      _sessionStart = DateTime.now().millisecondsSinceEpoch / 1000.0;
      _isAudioMode = true;
      _audioWaveform = [];
      _magnitudes = [];
      _bpmHistory = [];
      _timeLabels = [];
      _peakFreq = 0;
      _currentBpm = 0;
      _isScanning = true;
    });

    _audioSubscription = AudioService.instance.frameStream.listen(
      _onAudioFrame,
      onError: (_) => _stopMonitoring(),
    );
  }

  void _onAudioFrame(AudioFrame frame) {
    if (!mounted) return;
    setState(() {
      _audioWaveform = frame.waveform;
      _magnitudes = frame.spectrum;
      _currentBpm = frame.bpm;
      _peakFreq = frame.bpm / 60.0; // BPM → Hz

      final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
      _timeLabels.add(now - _sessionStart);
      _bpmHistory.add(frame.bpm);

      if (_bpmHistory.length > 300) {
        _bpmHistory = _bpmHistory.sublist(_bpmHistory.length - 300);
        _timeLabels = _timeLabels.sublist(_timeLabels.length - 300);
      }
    });
  }

  Future<void> _startImuMonitoring() async {
    try {
      await SensorService.instance.start();
      setState(() {
        _sessionStart = DateTime.now().millisecondsSinceEpoch / 1000.0;
        _isAudioMode = false;
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
    _audioSubscription?.cancel();
    _audioSubscription = null;
    if (!_isAudioMode) {
      await SensorService.instance.stop();
    }
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
    // Use GCG (gyroscope magnitude) — outperforms accelerometer for
    // mechanical heartbeat detection (Centracchio 2025).
    final signal = _buffer
        .sublist(_buffer.length - 256)
        .map((e) => sqrt(e.gx * e.gx + e.gy * e.gy + e.gz * e.gz))
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
    if (_isAudioMode) {
      return _buildCard(
        icon: Icons.graphic_eq,
        title: 'Forma de onda (audio)',
        color: Colors.cyan,
        children: [
          SizedBox(
            height: 200,
            child: AudioWaveformChart(
              waveform: _audioWaveform,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '400 muestras · ${_currentBpm > 0 ? "${_currentBpm.round()} BPM" : "---"}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      );
    }

    return _buildCard(
      icon: Icons.monitor_heart,
      title: 'Señal en tiempo real',
      color: Colors.cyan,
      children: [
        _buildChannelToggle(),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
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
            onTap: _isAudioMode
                ? null
                : () {
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
      title: _isAudioMode ? 'Espectro (audio)' : 'Espectro FFT',
      color: Colors.purple,
      children: [
        SizedBox(
          height: 200,
          child: SpectrumChart(
            magnitudes: _magnitudes,
            sampleRate: _isAudioMode
                ? 4000.0
                : SensorConstants.defaultSampleRate,
            maxDisplayFreq: _isAudioMode ? 200.0 : 30.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isAudioMode && _currentBpm > 0
              ? '${_currentBpm.round()} BPM (${(_currentBpm / 60).toStringAsFixed(2)} Hz)'
              : 'Pico: ${_peakFreq.toStringAsFixed(1)} Hz',
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
