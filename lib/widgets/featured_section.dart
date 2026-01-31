import 'dart:io';
import 'package:flutter/material.dart';
import 'package:arcade_launcher/models/app_info.dart';
import 'package:arcade_launcher/services/app_background_service.dart';

/// Extracted FeaturedSection widget from main.dart.
/// Displays the featured/recently played app with a large card.
class FeaturedSection extends StatelessWidget {
  final AppInfo app;
  final Map<String, dynamic>? stats;
  final double iconScale;
  final VoidCallback onTap;

  const FeaturedSection({
    super.key,
    required this.app,
    this.stats,
    required this.iconScale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Hero(
        tag: 'featured_${app.packageName}',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  _buildAppBackground(),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.9),
                          ],
                          stops: const [0.4, 0.6, 1.0],
                        ),
                      ),
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Text(
                              app.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.0,
                                height: 1.0,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${_formatLastPlayed(stats)} • ${_formatPlaytime(stats)}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBackground() {
    final String? bgPath = AppBackgroundService.getBackgroundSync(app.packageName);

    if (bgPath != null) {
      return Image.file(
        File(bgPath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: 400,
        gaplessPlayback: true,
      );
    }

    final Color appColor = _getAppColor(app.packageName);
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            appColor,
            appColor.withOpacity(0.5),
          ],
        ),
      ),
      child: Center(
        child: _buildAppIcon(iconScale),
      ),
    );
  }

  Widget _buildAppIcon(double size) {
    // Cap cache size at 512px for memory efficiency
    const maxCacheSize = 512;
    final cacheSize = size.round().clamp(0, maxCacheSize);

    if (app.iconPath != null) {
      return Image.file(
        File(app.iconPath!),
        width: size,
        height: size,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      );
    } else if (app.iconBytes != null) {
      return Image.memory(
        app.iconBytes!,
        width: size,
        height: size,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      );
    }
    return Icon(Icons.apps, color: Colors.white24, size: size);
  }

  Color _getAppColor(String packageName) {
    final int hash = packageName.hashCode;
    const colors = [
      Color(0xFF1E3A8A),
      Color(0xFF1D4ED8),
      Color(0xFF312E81),
      Color(0xFF4C1D95),
      Color(0xFF5B21B6),
      Color(0xFF701A75),
    ];
    return colors[hash.abs() % colors.length];
  }

  String _formatLastPlayed(Map<String, dynamic>? stats) {
    if (stats == null || stats['lastPlayed'] == null) return 'Never played';

    final lastPlayed = DateTime.fromMillisecondsSinceEpoch(stats['lastPlayed']);
    final diff = DateTime.now().difference(lastPlayed);

    if (diff.inMinutes < 1) return 'Played just now';
    if (diff.inMinutes < 60) return 'Played ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Played ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Played ${diff.inDays}d ago';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return 'Played ${months[lastPlayed.month - 1]} ${lastPlayed.day}';
  }

  String _formatPlaytime(Map<String, dynamic>? stats) {
    if (stats == null || stats['playtime'] == null) return 'Ready to play';
    final sessions = stats['playtime'] as int;
    if (sessions < 5) return 'New discovery';
    if (sessions < 20) return 'Regularly used';
    return 'Frequent play';
  }
}
