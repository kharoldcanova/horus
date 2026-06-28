import 'package:flutter/material.dart';
import '../../core/ml/model_service.dart';
import '../../core/storage/preferences_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PreferencesRepository _prefs = PreferencesRepository();
  final ModelService _modelService = ModelService();

  double _sensitivity = 0.5;
  RangeValues _bpmRange = const RangeValues(30, 220);
  bool _vibrationFeedback = true;
  bool _autoFeedback = false;
  bool _isModelLoaded = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkModel();
  }

  Future<void> _loadPreferences() async {
    try {
      final sensitivity = await _prefs.getSensitivity();
      final minBpm = await _prefs.getMinBpm();
      final maxBpm = await _prefs.getMaxBpm();
      final vibration = await _prefs.getVibrationFeedback();
      final autoFeedback = await _prefs.getAutoFeedback();

      if (mounted) {
        setState(() {
          _sensitivity = sensitivity;
          _bpmRange = RangeValues(minBpm, maxBpm);
          _vibrationFeedback = vibration;
          _autoFeedback = autoFeedback;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkModel() async {
    try {
      await _modelService.loadModel();
    } catch (_) {
      // model load is best-effort
    }
    if (mounted) {
      setState(() => _isModelLoaded = _modelService.isModelLoaded);
    }
  }

  @override
  void dispose() {
    _modelService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection('Detección'),
                const SizedBox(height: 8),
                _buildSliderCard(
                  icon: Icons.tune,
                  title: 'Sensibilidad',
                  value: _sensitivity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  display: '${(_sensitivity * 100).round()}%',
                  onChanged: (v) {
                    setState(() => _sensitivity = v);
                    _prefs.setSensitivity(v);
                  },
                ),
                const SizedBox(height: 12),
                _buildBpmRangeCard(),
                const SizedBox(height: 24),
                _buildSection('Feedback'),
                const SizedBox(height: 8),
                _buildSwitchCard(
                  icon: Icons.vibration,
                  title: 'Vibración al detectar',
                  value: _vibrationFeedback,
                  onChanged: (v) {
                    setState(() => _vibrationFeedback = v);
                    _prefs.setVibrationFeedback(v);
                  },
                ),
                const SizedBox(height: 12),
                _buildSwitchCard(
                  icon: Icons.auto_awesome,
                  title: 'Auto-confirmar detección',
                  subtitle: 'Omitir pregunta de feedback si confianza > 80%',
                  value: _autoFeedback,
                  onChanged: (v) {
                    setState(() => _autoFeedback = v);
                    _prefs.setAutoFeedback(v);
                  },
                ),
                const SizedBox(height: 24),
                _buildSection('Info'),
                const SizedBox(height: 8),
                _buildInfoCard(
                  icon: Icons.info_outline,
                  title: 'Acerca de Horus',
                  subtitle: 'Versión 0.1.0 — Detección de latidos para USAR',
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.science_outlined,
                  title: 'Modelo',
                  subtitle: _isModelLoaded ? '1D CNN — Cargado' : 'Sin modelo',
                ),
              ],
            ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white38,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSwitchCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      child: SwitchListTile(
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white54, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        subtitle: subtitle != null
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              )
            : null,
        value: value,
        activeThumbColor: Colors.green,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSliderCard({
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white54, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title)),
                Text(
                  display,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBpmRangeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.speed, color: Colors.white54, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Rango BPM',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                Text(
                  '${_bpmRange.start.round()} — ${_bpmRange.end.round()} BPM',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            RangeSlider(
              values: _bpmRange,
              min: 20,
              max: 250,
              divisions: 23,
              labels: RangeLabels(
                '${_bpmRange.start.round()} BPM',
                '${_bpmRange.end.round()} BPM',
              ),
              onChanged: (v) {
                setState(() => _bpmRange = v);
                _prefs.setMinBpm(v.start);
                _prefs.setMaxBpm(v.end);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white54, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: const TextStyle(color: Colors.white38)),
        ),
      ),
    );
  }
}
