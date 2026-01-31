import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import 'constants/pref_keys.dart';
import 'models/app_info.dart';
import 'services/launcher_service.dart';
import 'services/app_background_service.dart';
import 'services/safe_prefs.dart';

class AppBackgroundsPage extends StatefulWidget {
  const AppBackgroundsPage({super.key});

  @override
  State<AppBackgroundsPage> createState() => _AppBackgroundsPageState();
}

class _AppBackgroundsPageState extends State<AppBackgroundsPage> {
  final LauncherService _launcherService = LauncherService();
  final ImagePicker _picker = ImagePicker();
  List<AppInfo> _apps = [];
  Map<String, String> _backgrounds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final hiddenApps = await SafePrefs.getStringList(PrefKeys.hiddenApps);

    final allApps = await _launcherService.getApps();
    final backgrounds = await AppBackgroundService.getAllBackgrounds();

    if (mounted) {
      setState(() {
        _apps = allApps
            .where((app) => !hiddenApps.contains(app.packageName))
            .toList();
        _backgrounds = backgrounds;
        _loading = false;
      });
    }
  }

  Future<void> _pickImage(AppInfo app) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image != null && mounted) {
        final path = await AppBackgroundService.saveBackground(
          app.packageName,
          File(image.path),
        );
        setState(() {
          _backgrounds[app.packageName] = path;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Background set for ${app.name}'),
              backgroundColor: const Color(0xFF00D4FF),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeBackground(AppInfo app) async {
    await AppBackgroundService.removeBackground(app.packageName);
    setState(() {
      _backgrounds.remove(app.packageName);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Background removed for ${app.name}'),
          backgroundColor: Colors.grey,
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
          'APP BACKGROUNDS',
          style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _apps.length,
              itemBuilder: (context, index) {
                final app = _apps[index];
                final hasBackground = _backgrounds.containsKey(app.packageName);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    border: Border.all(
                      color: hasBackground
                          ? const Color(0xFF00D4FF).withOpacity(0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Preview of background or app icon
                      Container(
                        width: 80,
                        height: 120,
                        color: const Color(0xFF16213E),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (hasBackground)
                              Image.file(
                                File(_backgrounds[app.packageName]!),
                                fit: BoxFit.cover,
                                cacheWidth:
                                    _backgrounds[app.packageName]!
                                        .toLowerCase()
                                        .endsWith('.gif')
                                    ? null
                                    : 200,
                                cacheHeight:
                                    _backgrounds[app.packageName]!
                                        .toLowerCase()
                                        .endsWith('.gif')
                                    ? null
                                    : 300,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox(),
                              ),
                            // Dark overlay
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.1),
                                    Colors.black.withOpacity(0.5),
                                  ],
                                ),
                              ),
                            ),
                            // App icon at bottom left
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                padding: const EdgeInsets.all(3),
                                child: _buildAppIcon(app),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // App info and actions
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hasBackground
                                    ? 'Custom background set'
                                    : 'No custom background',
                                style: TextStyle(
                                  color: hasBackground
                                      ? const Color(0xFF00D4FF)
                                      : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildActionButton(
                                    icon: Icons.image,
                                    label: 'SET',
                                    onTap: () => _pickImage(app),
                                    isPrimary: true,
                                  ),
                                  if (hasBackground) ...[
                                    const SizedBox(width: 8),
                                    _buildActionButton(
                                      icon: Icons.delete_outline,
                                      label: 'REMOVE',
                                      onTap: () => _removeBackground(app),
                                      isPrimary: false,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF00D4FF) : Colors.transparent,
          border: Border.all(
            color: isPrimary ? const Color(0xFF00D4FF) : Colors.grey,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isPrimary ? Colors.black : Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.black : Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppIcon(AppInfo app) {
    if (app.iconPath != null) {
      return Image.file(File(app.iconPath!), fit: BoxFit.contain);
    } else if (app.iconBytes != null) {
      return Image.memory(app.iconBytes!, fit: BoxFit.contain);
    } else {
      return const Icon(Icons.android, size: 20, color: Color(0xFF00D4FF));
    }
  }
}
