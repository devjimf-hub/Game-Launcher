import 'dart:io';
import 'package:flutter/material.dart';
import 'package:arcade_launcher/models/app_info.dart';
import 'package:arcade_launcher/services/app_background_service.dart';

/// Extracted small game card widget for grid display.
/// Used in both Recently Played and Library grids.
class GameCardSmall extends StatelessWidget {
  final AppInfo app;
  final Map<String, dynamic>? stats;
  final bool isRecent;
  final bool showAppName;
  final double iconScale;
  final int index;
  final VoidCallback onTap;

  /// Maximum cache size for icons to prevent memory issues on high DPI devices
  static const int maxIconCacheSize = 512;

  const GameCardSmall({
    super.key,
    required this.app,
    this.stats,
    required this.isRecent,
    required this.showAppName,
    required this.iconScale,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      index: index,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    _buildAppBackground(context),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.5),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showAppName) ...[
                  Text(
                    app.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
                Text(
                  isRecent ? _formatLastPlayed(stats) : 'Ready to play',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBackground(BuildContext context) {
    final String? bgPath =
        AppBackgroundService.getBackgroundSync(app.packageName);

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
        child: _buildAppIcon(context, iconScale),
      ),
    );
  }

  Widget _buildAppIcon(BuildContext context, double size) {
    final double pixelRatio = MediaQuery.of(context).devicePixelRatio;
    // Cap cache size to prevent excessive memory usage on high DPI devices
    final int cacheSize =
        (size * pixelRatio).round().clamp(0, maxIconCacheSize);

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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return 'Played ${months[lastPlayed.month - 1]} ${lastPlayed.day}';
  }
}

class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final int index;

  const _PressableScale(
      {required this.child, required this.onTap, required this.index});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _entranceController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _entranceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _entranceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutBack,
      ),
    );

    // Staggered entrance based on index
    Future.delayed(Duration(milliseconds: (widget.index % 12) * 50), () {
      if (mounted) {
        _entranceController.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _entranceAnimation,
      child: FadeTransition(
        opacity: _entranceAnimation,
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) => _controller.reverse(),
          onTapCancel: () => _controller.reverse(),
          onTap: () {
            widget.onTap();
          },
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
