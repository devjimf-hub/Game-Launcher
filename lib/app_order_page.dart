import 'package:flutter/material.dart';
import 'dart:io';

import 'constants/pref_keys.dart';
import 'models/app_info.dart';
import 'services/launcher_service.dart';
import 'services/safe_prefs.dart';
import 'utils/app_sorter.dart';

class AppOrderPage extends StatefulWidget {
  const AppOrderPage({super.key});

  @override
  State<AppOrderPage> createState() => _AppOrderPageState();
}

class _AppOrderPageState extends State<AppOrderPage> {
  final LauncherService _launcherService = LauncherService();
  List<AppInfo> _apps = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final hiddenApps = await SafePrefs.getStringList(PrefKeys.hiddenApps);
    final appOrder = await SafePrefs.getStringList(PrefKeys.appOrder);

    final allApps = await _launcherService.getApps();

    // Filter out hidden apps
    List<AppInfo> visibleApps = allApps
        .where((app) => !hiddenApps.contains(app.packageName))
        .toList();

    // Sort according to saved order using optimized sorter
    AppSorter.sortByOrder(visibleApps, appOrder);

    if (mounted) {
      setState(() {
        _apps = visibleApps;
        _loading = false;
      });
    }
  }

  Future<void> _saveOrder() async {
    final List<String> order = _apps.map((app) => app.packageName).toList();
    await SafePrefs.setStringList(PrefKeys.appOrder, order);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('LIBRARY SEQUENCE UPDATED'),
          backgroundColor: Color(0xFF00D4FF),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'MANAGE SEQUENCE',
          style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Color(0xFF00D4FF)),
            onPressed: _saveOrder,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
            )
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'DRAG AND DROP TO POSITION ENTRIES',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _apps.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final app = _apps.removeAt(oldIndex);
                        _apps.insert(newIndex, app);
                      });
                    },
                    itemBuilder: (context, index) {
                      final app = _apps[index];
                      return Container(
                        key: ValueKey(app.packageName),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF00D4FF).withOpacity(0.1),
                          ),
                        ),
                        child: ListTile(
                          leading: _buildAppIcon(app),
                          title: Text(
                            app.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            app.packageName,
                            style: const TextStyle(
                              color: Colors.white30,
                              fontSize: 10,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.drag_handle,
                            color: Color(0xFF00D4FF),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAppIcon(AppInfo app) {
    if (app.iconPath != null) {
      return Image.file(
        File(app.iconPath!),
        width: 32,
        height: 32,
        fit: BoxFit.contain,
      );
    } else if (app.iconBytes != null) {
      return Image.memory(
        app.iconBytes!,
        width: 32,
        height: 32,
        fit: BoxFit.contain,
      );
    } else {
      return const Icon(Icons.android, color: Color(0xFF00D4FF), size: 32);
    }
  }
}
