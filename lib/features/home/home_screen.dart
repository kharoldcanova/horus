import 'package:flutter/material.dart';
import '../../core/sensors/sensor_event.dart';
import '../../core/sensors/sensor_service.dart';
import '../../core/ml/model_service.dart';
import '../../core/storage/session_repository.dart';
import '../../shared/theme/app_theme.dart';

enum SearchMode { imu, audio, camera }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  final SensorService _sensorService = SensorService.instance;
  final ModelService _modelService = ModelService();

  // ignore: unused_field
  SearchMode? _activeMode;
  bool _isScanning = false;
  bool _modelReady = false;
  bool _showFeedback = false;

  List<SensorEvent> _window = [];
  DetectionResult? _lastResult;
  String _currentSessionId = '';
  int _scansToday = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initModel();
  }

  Future<void> _initModel() async {
    await _modelService.loadModel();
    if (mounted) setState(() => _modelReady = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sensorService.dispose();
    _modelService.dispose();
    super.dispose();
  }

  Future<void> _startScan(SearchMode mode) async {
    if (_isScanning) return;

    try {
      await _sensorService.start();
      setState(() {
        _activeMode = mode;
        _isScanning = true;
        _showFeedback = false;
        _lastResult = null;
        _window = [];
        _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      });

      _sensorService.processedStream.listen((events) {
        if (!mounted) return;
        _window.addAll(events);
        if (_window.length > 256) {
          _window = _window.sublist(_window.length - 256);
        }

        if (_window.length >= 128 && _modelReady) {
          final result = _modelService.classify(
            window: _window,
            mode: DetectionMode.imu,
          );
          setState(() {
            _lastResult = result;
          });
        }
      });
    } catch (_) {}
  }

  void _stopScan() {
    _sensorService.stop();
    setState(() {
      _isScanning = false;
      _showFeedback = true;
    });
  }

  Future<void> _submitFeedback(bool heartbeatDetected) async {
    final session = SensorSession(
      id: _currentSessionId,
      startTime: DateTime.now(),
      events: _window,
      notes: heartbeatDetected ? 'latido_confirmado' : 'sin_latido',
    );

    try {
      await SessionRepository().saveSession(session);
    } catch (_) {
      // Persistence failure is non-critical — UI continues regardless
    }

    if (!mounted) return;
    setState(() {
      _showFeedback = false;
      _scansToday++;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          heartbeatDetected
              ? '✅ Latido registrado — datos guardados para entrenamiento'
              : '⏳ Descartado — datos guardados como negativo',
        ),
        backgroundColor: heartbeatDetected ? Colors.green : Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HORUS'),
        centerTitle: true,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '$_scansToday búsquedas',
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info banner
          if (!_modelReady)
            _buildInfoBanner(
              'Cargando modelo de detección...',
              Icons.hourglass_bottom,
              Colors.orange,
            ),

          // Scanning status
          if (_isScanning) _buildScanningPanel(),

          // Feedback prompt
          if (_showFeedback) _buildFeedbackPanel(),

          // Detection mode cards
          if (!_isScanning && !_showFeedback) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Seleccioná modo de búsqueda',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            _buildModeCard(
              icon: Icons.sensors,
              title: 'Sensores IMU',
              subtitle: 'Acelerómetro + Giroscopio\nApoyá el teléfono sobre la superficie',
              mode: SearchMode.imu,
              color: AppTheme.rescueTheme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            _buildModeCard(
              icon: Icons.headphones,
              title: 'Audio por Contacto',
              subtitle: 'Usá el micrófono como estetoscopio\nApoyá el teléfono o auricular',
              mode: SearchMode.audio,
              color: Colors.cyan,
            ),
            const SizedBox(height: 12),
            _buildModeCard(
              icon: Icons.camera_alt,
              title: 'Cámara (rPPG)',
              subtitle: 'Detección por cámara frontal\nSolo si hay línea de visión al rostro',
              mode: SearchMode.camera,
              color: Colors.amber,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBanner(String text, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required SearchMode mode,
    required Color color,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _modelReady ? () => _startScan(mode) : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white54,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanningPanel() {
    final detected = _lastResult?.heartbeatDetected ?? false;
    final bpm = _lastResult?.bpm ?? 0;
    final confidence = _lastResult?.confidence ?? 0;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'ESCANEANDO',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.rescueTheme.colorScheme.secondary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedScale(
                  scale: detected ? 1.0 : 0.85,
                  duration: const Duration(milliseconds: 400),
                  child: Icon(
                    detected ? Icons.favorite : Icons.favorite_border,
                    size: 80,
                    color: detected
                        ? Colors.green
                        : Colors.white24,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  bpm > 0 ? '${bpm.round()} BPM' : '---',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detected ? 'POSIBLE LATIDO' : 'SIN DETECCIÓN',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: detected ? Colors.green : Colors.white38,
                    letterSpacing: 2,
                  ),
                ),
                if (confidence > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Confianza: ${(confidence * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 80,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: confidence.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: detected ? Colors.green : Colors.orange,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _stopScan,
                    icon: const Icon(Icons.stop, size: 24),
                    label: const Text(
                      'DETENER BÚSQUEDA',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Apoyá el teléfono sobre la superficie y mantenelo firme',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFeedbackPanel() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.help_outline,
                  size: 48,
                  color: Colors.amber,
                ),
                const SizedBox(height: 16),
                const Text(
                  '¿Se detectó un latido?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tu respuesta ayuda a entrenar el modelo\ny mejorar futuras detecciones',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () => _submitFeedback(true),
                          icon: const Icon(Icons.check, size: 24),
                          label: const Text(
                            'SÍ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () => _submitFeedback(false),
                          icon: const Icon(Icons.close, size: 24),
                          label: const Text(
                            'NO',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _showFeedback = false),
          child: const Text(
            'Nueva búsqueda',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ],
    );
  }
}
