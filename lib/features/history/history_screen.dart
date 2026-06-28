import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/storage/session_repository.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final SessionRepository _repository = SessionRepository();
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  int get _totalScans => _sessions.length;

  int get _detectedCount =>
      _sessions.where((s) => s['notes'] == 'latido_confirmado').length;

  String get _rateDisplay {
    if (_totalScans == 0) return '--';
    return '${(_detectedCount / _totalScans * 100).round()}%';
  }

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await _repository.listSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportSessions() async {
    try {
      final path = await _repository.exportSessions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exportado a $path'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al exportar'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSession(String id) async {
    try {
      await _repository.deleteSession(id);
      await _loadSessions();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al eliminar'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat("d MMM yyyy, HH:mm", 'es').format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  String _formatDuration(dynamic durationSec) {
    final sec = (durationSec as num?)?.toDouble() ?? 0.0;
    if (sec < 60) return '${sec.toStringAsFixed(1)} s';
    final min = (sec / 60).floor();
    final remainingSec = (sec % 60).round();
    return '${min}m ${remainingSec}s';
  }

  String _formatEventCount(dynamic count) {
    final n = (count as num?)?.toInt() ?? 0;
    return NumberFormat('#,###').format(n);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _sessions.isNotEmpty ? _exportSessions : null,
            tooltip: 'Exportar datos',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSessions,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatsBar(),
                  const SizedBox(height: 16),
                  if (_sessions.isEmpty) _buildEmptyState(),
                  ..._sessions.map(_buildSessionCard),
                ],
              ),
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
            _statItem('Búsquedas', '$_totalScans', Icons.search),
            _statItem('Latidos', '$_detectedCount', Icons.favorite),
            _statItem('Tasa', _rateDisplay, Icons.verified),
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
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white38),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(
            Icons.manage_search_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay sesiones guardadas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Realizá una búsqueda desde la pestaña Rescate.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final id = session['id'] as String;
    final startTime = session['startTime'] as String? ?? '';
    final notes = session['notes'] as String?;
    final eventCount = session['eventCount'];
    final duration = session['duration'];
    final isPositive = notes == 'latido_confirmado';

    final resultColor = isPositive ? Colors.green : Colors.grey;
    final resultIcon = isPositive ? '✅' : '⛔';
    final resultText = isPositive ? 'Latido detectado' : 'Sin detección';

    return Dismissible(
      key: Key('session_$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.red, size: 28),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF16213E),
            title: const Text('Eliminar sesión'),
            content: const Text(
              '¿Estás seguro de que querés eliminar esta sesión?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => _deleteSession(id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(startTime),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDuration(duration)} — ${_formatEventCount(eventCount)} muestras',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: resultColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '$resultIcon $resultText',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: resultColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
