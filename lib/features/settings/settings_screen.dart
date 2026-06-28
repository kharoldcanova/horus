import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _vibrationFeedback = true;
  bool _autoFeedback = false;
  double _sensitivity = 0.5;
  final double _minBpm = 30;
  final double _maxBpm = 220;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        centerTitle: true,
      ),
      body: ListView(
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
            display: '${(_sensitivity * 100).round()}%',
            onChanged: (v) => setState(() => _sensitivity = v),
          ),
          const SizedBox(height: 12),
          _buildRangeCard(
            icon: Icons.speed,
            title: 'Rango BPM',
            subtitle: '${_minBpm.round()} — ${_maxBpm.round()} BPM',
          ),
          const SizedBox(height: 24),

          _buildSection('Feedback'),
          const SizedBox(height: 8),
          _buildSwitchCard(
            icon: Icons.vibration,
            title: 'Vibración al detectar',
            value: _vibrationFeedback,
            onChanged: (v) => setState(() => _vibrationFeedback = v),
          ),
          const SizedBox(height: 12),
          _buildSwitchCard(
            icon: Icons.auto_awesome,
            title: 'Auto-confirmar detección',
            subtitle: 'Omitir pregunta de feedback si confianza > 80%',
            value: _autoFeedback,
            onChanged: (v) => setState(() => _autoFeedback = v),
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
            subtitle: '1D CNN — ${_modelReady ? "Cargado" : "Sin modelo"}',
          ),
        ],
      ),
    );
  }

  bool get _modelReady => true;

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
                child:
                    Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              )
            : null,
        value: value,
        // ignore: deprecated_member_use
        activeColor: Colors.green,
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
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeCard({
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
