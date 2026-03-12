import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/pref_keys.dart';
import 'services/safe_prefs.dart';
import 'services/sales_service.dart';
import 'services/launcher_service.dart';
import 'models/app_info.dart';
import 'logic/app_data_processor.dart';
import 'widgets/glass_container.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final LauncherService _launcherService = LauncherService();
  List<Map<String, dynamic>> _appUsage = [];
  List<ChargingSession> _chargingLogs = [];
  int _minsPerPeso = PrefKeys.defaultMinsPerPeso;
  double _totalSales = 0.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      SafePrefs.getString(PrefKeys.recentAppsData),
      _launcherService.getApps(),
      SafePrefs.getInt(PrefKeys.minsPerPeso, defaultValue: PrefKeys.defaultMinsPerPeso),
      SalesService.getLogs(),
      SalesService.calculateTotalSales(),
    ]);

    final recentData = results[0] as String?;
    final apps = results[1] as List<AppInfo>;
    final mins = results[2] as int;
    final logs = results[3] as List<ChargingSession>;
    final total = results[4] as double;

    List<Map<String, dynamic>> usage = [];
    if (recentData != null && apps.isNotEmpty) {
      final recents = await AppDataProcessor.parseRecentsJsonBackground(recentData);
      
      // Map-based lookup for O(N) instead of O(N*M)
      final Map<String, AppInfo> appMap = {
        for (var app in apps) app.packageName: app
      };

      for (var r in recents) {
        final pkg = r['packageName'];
        final app = appMap[pkg];
        if (app != null) {
          usage.add({
            'app': app,
            'playtime': r['playtime'] ?? 0,
          });
        }
      }
      usage.sort((a, b) => (b['playtime'] as int).compareTo(a['playtime'] as int));
    }

    if (mounted) {
      setState(() {
        _appUsage = usage;
        _chargingLogs = logs;
        _minsPerPeso = mins;
        _totalSales = total;
        _loading = false;
      });
    }
  }

  Future<void> _updateMinsPerPeso(int val) async {
    if (val < 1) return;
    await SafePrefs.setInt(PrefKeys.minsPerPeso, val);
    final total = await SalesService.calculateTotalSales();
    setState(() {
      _minsPerPeso = val;
      _totalSales = total;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('SALES & ANALYTICS', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSalesOverview(),
                const SizedBox(height: 24),
                _buildSectionTitle('CONVERSION SETTINGS'),
                _buildMinsSelector(),
                const SizedBox(height: 24),
                _buildSectionTitle('MOST USED APPS'),
                _buildAppUsageList(),
                const SizedBox(height: 24),
                _buildSectionTitle('CHARGING HISTORY'),
                _buildChargingLogs(),
                const SizedBox(height: 40),
                _buildClearButton(),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildSalesOverview() {
    return GlassContainer(
      borderRadius: 16,
      opacity: 0.1,
      blur: 10,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'ESTIMATED TOTAL SALES',
              style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              '₱${_totalSales.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFF00FF9D),
                fontSize: 48,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Based on ${_chargingLogs.length} charging sessions',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinsSelector() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MINUTES PER PESO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text('Calculates revenue based on charging time', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _updateMinsPerPeso(_minsPerPeso - 1),
            icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF00D4FF)),
          ),
          Text('$_minsPerPeso', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(
            onPressed: () => _updateMinsPerPeso(_minsPerPeso + 1),
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00D4FF)),
          ),
        ],
      ),
    );
  }

  Widget _buildAppUsageList() {
    if (_appUsage.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No data available', style: TextStyle(color: Colors.white38))),
      );
    }

    return Column(
      children: _appUsage.take(5).map((usage) {
        final AppInfo app = usage['app'];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: app.iconPath != null 
              ? Image.file(File(app.iconPath!), fit: BoxFit.contain)
              : const Icon(Icons.android, color: Colors.white24),
          ),
          title: Text(app.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
          trailing: Text('${usage['playtime']} sessions', style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 12, fontWeight: FontWeight.bold)),
        );
      }).toList(),
    );
  }

  Widget _buildChargingLogs() {
    if (_chargingLogs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No charging records', style: TextStyle(color: Colors.white38))),
      );
    }

    return Column(
      children: _chargingLogs.take(10).map((log) {
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.electric_bolt, color: Color(0xFFFFE100), size: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(log.startTime),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_formatTime(log.startTime)} - ${_formatTime(log.endTime!)}',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                '${log.durationInMinutes} mins',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildClearButton() {
    return Center(
      child: TextButton.icon(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF0D0D0D),
              title: const Text('CLEAR LOGS?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              content: const Text('This will delete all charging session data. Total sales will reset.', style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('CLEAR', style: TextStyle(color: Colors.red))),
              ],
            ),
          );
          if (confirm == true) {
            await SalesService.clearLogs();
            _loadData();
          }
        },
        icon: const Icon(Icons.delete_forever, color: Colors.red, size: 16),
        label: const Text('CLEAR CHARGING RECORDS', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
