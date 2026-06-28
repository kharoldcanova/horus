import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () {},
            tooltip: 'Exportar datos',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatsBar(),
          const SizedBox(height: 16),
          _buildCard(
            icon: Icons.favorite,
            title: 'Últimas búsquedas',
            subtitle: 'No hay sesiones guardadas todavía',
            color: Colors.green,
            isEmpty: true,
          ),
          const SizedBox(height: 12),
          _buildCard(
            icon: Icons.download_outlined,
            title: 'Exportar datos',
            subtitle: 'Compartir sesiones para entrenar el modelo',
            color: Colors.blue,
            isEmpty: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem('Búsquedas', '0', Icons.search),
            _statItem('Latidos', '0', Icons.favorite),
            _statItem('Precisión', '--', Icons.verified),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white38, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white38)),
      ],
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    bool isEmpty = false,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isEmpty ? 0.05 : 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: isEmpty ? color.withValues(alpha: 0.3) : color),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isEmpty ? Colors.white38 : Colors.white,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(
              color: isEmpty ? Colors.white24 : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}
