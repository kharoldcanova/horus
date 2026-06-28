import 'package:flutter/material.dart';

class MonitorScreen extends StatelessWidget {
  const MonitorScreen({super.key});

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
          _buildCard(
            icon: Icons.monitor_heart,
            title: 'Señal en tiempo real',
            subtitle: 'Visualización de las 6 señales del sensor',
            color: Colors.cyan,
          ),
          const SizedBox(height: 12),
          _buildCard(
            icon: Icons.analytics,
            title: 'Espectro FFT',
            subtitle: 'Análisis de frecuencia de las señales',
            color: Colors.purple,
          ),
          const SizedBox(height: 12),
          _buildCard(
            icon: Icons.timeline,
            title: 'Historial de sesión',
            subtitle: 'Gráfico de BPM durante el escaneo',
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: const TextStyle(color: Colors.white54)),
        ),
        trailing:
            const Icon(Icons.lock_outline, color: Colors.white24, size: 20),
      ),
    );
  }
}
